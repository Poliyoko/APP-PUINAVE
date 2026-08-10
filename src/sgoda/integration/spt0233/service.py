"""Servicio deterministico de asignacion de categorias SPT-023.3."""

from __future__ import annotations

from typing import Any, Iterable

from .catalog import CategoryCatalog
from .models import CategoryAssignmentResult


_ALLOWED_EVIDENCE_KEYS = {
    "category",
    "categories",
    "semantic_category",
    "semantic_categories",
    "domain",
    "domains",
    "part_of_speech",
    "pos",
    "gloss",
    "meaning",
    "meanings",
    "translation_es",
    "spanish",
    "label",
    "labels",
}


def _flatten_evidence(value: object) -> list[str]:
    out: list[str] = []

    if value is None:
        return out

    if isinstance(value, str):
        text = value.strip()
        if text:
            out.append(text)
        return out

    if isinstance(value, (list, tuple, set)):
        for item in value:
            out.extend(_flatten_evidence(item))
        return out

    if isinstance(value, dict):
        for key, item in value.items():
            if str(key).casefold() in _ALLOWED_EVIDENCE_KEYS:
                out.extend(_flatten_evidence(item))
        return out

    return out


class Spt0233CategoryService:
    """Asigna exclusivamente categorias preexistentes.

    No crea categorias, no inventa significado y no habilita SPT-023.4
    cuando la evidencia es insuficiente o ambigua.
    """

    def __init__(
        self,
        catalog: CategoryCatalog,
        minimum_confidence: float = 0.85,
    ) -> None:
        self.catalog = catalog
        self.minimum_confidence = max(
            0.0,
            min(1.0, float(minimum_confidence)),
        )

    @staticmethod
    def _input_decision(item: dict[str, Any]) -> str:
        explicit = str(
            item.get("institutional_decision")
            or item.get("decision")
            or ""
        ).strip().upper()

        if explicit:
            return explicit

        if (
            bool(item.get("downstream_allowed"))
            and str(item.get("semantic_status") or "").upper() == "MATCHED"
        ):
            return "READY_FOR_CATEGORY"

        return "NOT_ELIGIBLE"

    def assign(self, item: dict[str, Any]) -> CategoryAssignmentResult:
        decision = self._input_decision(item)
        source_index = int(item.get("source_index") or 0)
        puinave = str(item.get("puinave") or "").strip()
        lexical_hash = str(item.get("lexical_hash") or "").strip()

        base = {
            "source_index": source_index,
            "puinave": puinave,
            "lexical_hash": lexical_hash,
            "input_decision": decision,
            "no_invention": True,
            "metadata": {
                "source_component": "SPT-023.2",
                "target_component": "SPT-023.3",
            },
        }

        if decision != "READY_FOR_CATEGORY":
            return CategoryAssignmentResult(
                **base,
                assignment_status="NOT_ELIGIBLE",
                confidence=0.0,
                reasons=("input_not_ready_for_category",),
                requires_human_validation=True,
            )

        evidence: list[str] = []
        evidence.extend(_flatten_evidence(item.get("semantic_candidates")))
        evidence.extend(_flatten_evidence(item.get("metadata")))
        evidence.extend(_flatten_evidence(item.get("context")))

        ranked = self.catalog.rank(evidence)

        if not ranked:
            return CategoryAssignmentResult(
                **base,
                assignment_status="REVIEW_REQUIRED",
                confidence=0.0,
                reasons=("no_existing_category_match",),
                requires_human_validation=True,
            )

        best_score = ranked[0][0]
        best = [entry for entry in ranked if entry[0] == best_score]

        if len(best) != 1:
            return CategoryAssignmentResult(
                **base,
                assignment_status="AMBIGUOUS",
                confidence=best_score,
                reasons=("multiple_existing_categories_match",),
                requires_human_validation=True,
            )

        score, category, reason = best[0]

        if score < self.minimum_confidence:
            return CategoryAssignmentResult(
                **base,
                assignment_status="REVIEW_REQUIRED",
                confidence=score,
                reasons=("confidence_below_threshold", reason),
                requires_human_validation=True,
            )

        return CategoryAssignmentResult(
            **base,
            assignment_status="ASSIGNED",
            category_id=category.category_id,
            category_name=category.name,
            confidence=score,
            reasons=(reason,),
            requires_human_validation=True,
        )

    def assign_batch(
        self,
        payload: dict[str, Any] | Iterable[dict[str, Any]],
    ) -> dict[str, Any]:
        if isinstance(payload, dict):
            raw_results = payload.get("results", [])
            source_hash = payload.get("source_batch_hash")
        else:
            raw_results = payload
            source_hash = None

        if not isinstance(raw_results, Iterable):
            raise ValueError("SPT-023.2 payload debe contener results.")

        results = [
            self.assign(item)
            for item in raw_results
            if isinstance(item, dict)
        ]

        assigned = sum(
            item.assignment_status == "ASSIGNED"
            for item in results
        )
        review = sum(
            item.assignment_status in {"REVIEW_REQUIRED", "AMBIGUOUS"}
            for item in results
        )
        not_eligible = sum(
            item.assignment_status == "NOT_ELIGIBLE"
            for item in results
        )

        return {
            "component": "SPT-023.3",
            "source_component": "SPT-023.2",
            "source_batch_hash": source_hash,
            "records_processed": len(results),
            "assigned": assigned,
            "review_required": review,
            "not_eligible": not_eligible,
            "no_invention": all(item.no_invention for item in results),
            "automatic_category_creation": False,
            "requires_human_validation": True,
            "next_component": "SPT-023.4",
            "results": [item.to_dict() for item in results],
        }
