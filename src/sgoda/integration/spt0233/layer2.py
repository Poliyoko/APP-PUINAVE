from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable

from .catalog import CategoryCatalog
from .hierarchy import CategoryHierarchy
from .proposal import CategoryProposal, build_category_proposal
from .traceability import CategoryDecisionTrace, build_trace


_EVIDENCE_KEYS = (
    "category",
    "categories",
    "semantic_category",
    "semantic_categories",
    "domain",
    "domains",
    "label",
    "labels",
    "part_of_speech",
    "pos",
)


def _flatten(value: object) -> list[str]:
    out: list[str] = []

    if value is None:
        return out
    if isinstance(value, str):
        text = value.strip()
        if text:
            out.append(text)
        return out
    if isinstance(value, dict):
        for key, item in value.items():
            if str(key).casefold() in _EVIDENCE_KEYS:
                out.extend(_flatten(item))
        return out
    if isinstance(value, (list, tuple, set)):
        for item in value:
            out.extend(_flatten(item))
        return out

    return out


@dataclass(frozen=True)
class Layer2Classification:
    source_index: int
    puinave: str
    lexical_hash: str
    status: str
    principal_category_id: str | None
    principal_category_name: str | None
    selected_category_id: str | None
    selected_category_name: str | None
    subcategory_ids: tuple[str, ...]
    confidence: float
    reasons: tuple[str, ...]
    proposal: CategoryProposal | None
    trace: CategoryDecisionTrace
    automatic_category_creation: bool = False
    requires_human_validation: bool = True

    def to_dict(self) -> dict[str, Any]:
        return {
            "source_index": self.source_index,
            "puinave": self.puinave,
            "lexical_hash": self.lexical_hash,
            "status": self.status,
            "principal_category_id": self.principal_category_id,
            "principal_category_name": self.principal_category_name,
            "selected_category_id": self.selected_category_id,
            "selected_category_name": self.selected_category_name,
            "subcategory_ids": list(self.subcategory_ids),
            "confidence": self.confidence,
            "reasons": list(self.reasons),
            "proposal": None if self.proposal is None else self.proposal.to_dict(),
            "trace": self.trace.to_dict(),
            "automatic_category_creation": self.automatic_category_creation,
            "requires_human_validation": self.requires_human_validation,
        }


class Spt0233Layer2Classifier:
    """Capa 2: reutilizaciÃ³n, jerarquÃ­a, confianza, propuestas y trazabilidad."""

    def __init__(
        self,
        catalog: CategoryCatalog,
        minimum_confidence: float = 0.85,
    ) -> None:
        self.catalog = catalog
        self.hierarchy = CategoryHierarchy(catalog)
        self.minimum_confidence = max(0.0, min(1.0, float(minimum_confidence)))

    @staticmethod
    def _eligible(item: dict[str, Any]) -> bool:
        decision = str(
            item.get("institutional_decision")
            or item.get("decision")
            or ""
        ).strip().upper()

        if decision == "READY_FOR_CATEGORY":
            return True

        return (
            bool(item.get("downstream_allowed"))
            and str(item.get("semantic_status") or "").strip().upper() == "MATCHED"
        )

    @staticmethod
    def _evidence(item: dict[str, Any]) -> list[str]:
        evidence: list[str] = []
        evidence.extend(_flatten(item.get("semantic_candidates")))
        evidence.extend(_flatten(item.get("metadata")))
        evidence.extend(_flatten(item.get("context")))
        return evidence

    def classify(self, item: dict[str, Any]) -> Layer2Classification:
        source_index = int(item.get("source_index") or 0)
        puinave = str(item.get("puinave") or "").strip()
        lexical_hash = str(item.get("lexical_hash") or "").strip()

        if not self._eligible(item):
            trace = build_trace(
                source_index=source_index,
                lexical_hash=lexical_hash,
                status="NOT_ELIGIBLE",
                principal_category_id=None,
                selected_category_id=None,
                confidence=0.0,
                proposal_id=None,
            )
            return Layer2Classification(
                source_index=source_index,
                puinave=puinave,
                lexical_hash=lexical_hash,
                status="NOT_ELIGIBLE",
                principal_category_id=None,
                principal_category_name=None,
                selected_category_id=None,
                selected_category_name=None,
                subcategory_ids=(),
                confidence=0.0,
                reasons=("input_not_ready_for_category",),
                proposal=None,
                trace=trace,
            )

        evidence = self._evidence(item)
        ranked = self.catalog.rank(evidence)

        if not ranked:
            proposal = build_category_proposal(evidence)
            status = "PROPOSAL_REQUIRED" if proposal is not None else "REVIEW_REQUIRED"
            reason = (
                "no_existing_category_match"
                if proposal is not None
                else "insufficient_category_evidence"
            )
            trace = build_trace(
                source_index=source_index,
                lexical_hash=lexical_hash,
                status=status,
                principal_category_id=None,
                selected_category_id=None,
                confidence=0.0,
                proposal_id=None if proposal is None else proposal.proposal_id,
            )
            return Layer2Classification(
                source_index=source_index,
                puinave=puinave,
                lexical_hash=lexical_hash,
                status=status,
                principal_category_id=None,
                principal_category_name=None,
                selected_category_id=None,
                selected_category_name=None,
                subcategory_ids=(),
                confidence=0.0,
                reasons=(reason,),
                proposal=proposal,
                trace=trace,
            )

        best_score = ranked[0][0]
        best = [entry for entry in ranked if entry[0] == best_score]

        if len(best) != 1:
            trace = build_trace(
                source_index=source_index,
                lexical_hash=lexical_hash,
                status="AMBIGUOUS",
                principal_category_id=None,
                selected_category_id=None,
                confidence=best_score,
                proposal_id=None,
            )
            return Layer2Classification(
                source_index=source_index,
                puinave=puinave,
                lexical_hash=lexical_hash,
                status="AMBIGUOUS",
                principal_category_id=None,
                principal_category_name=None,
                selected_category_id=None,
                selected_category_name=None,
                subcategory_ids=(),
                confidence=best_score,
                reasons=("multiple_existing_categories_match",),
                proposal=None,
                trace=trace,
            )

        score, selected, reason = best[0]

        if score < self.minimum_confidence:
            trace = build_trace(
                source_index=source_index,
                lexical_hash=lexical_hash,
                status="REVIEW_REQUIRED",
                principal_category_id=None,
                selected_category_id=selected.category_id,
                confidence=score,
                proposal_id=None,
            )
            return Layer2Classification(
                source_index=source_index,
                puinave=puinave,
                lexical_hash=lexical_hash,
                status="REVIEW_REQUIRED",
                principal_category_id=None,
                principal_category_name=None,
                selected_category_id=selected.category_id,
                selected_category_name=selected.name,
                subcategory_ids=(),
                confidence=score,
                reasons=("confidence_below_threshold", reason),
                proposal=None,
                trace=trace,
            )

        lineage = self.hierarchy.lineage(selected.category_id)
        principal = lineage[0]
        subcategories = tuple(node.category_id for node in lineage[1:])

        trace = build_trace(
            source_index=source_index,
            lexical_hash=lexical_hash,
            status="ASSIGNED",
            principal_category_id=principal.category_id,
            selected_category_id=selected.category_id,
            confidence=score,
            proposal_id=None,
        )

        return Layer2Classification(
            source_index=source_index,
            puinave=puinave,
            lexical_hash=lexical_hash,
            status="ASSIGNED",
            principal_category_id=principal.category_id,
            principal_category_name=principal.name,
            selected_category_id=selected.category_id,
            selected_category_name=selected.name,
            subcategory_ids=subcategories,
            confidence=score,
            reasons=(reason, "existing_category_reused"),
            proposal=None,
            trace=trace,
        )

    def classify_batch(
        self,
        payload: dict[str, Any] | Iterable[dict[str, Any]],
    ) -> dict[str, Any]:
        if isinstance(payload, dict):
            records = payload.get("results", [])
            source_batch_hash = payload.get("source_batch_hash")
        else:
            records = payload
            source_batch_hash = None

        results = [
            self.classify(item)
            for item in records
            if isinstance(item, dict)
        ]

        counts: dict[str, int] = {}
        for result in results:
            counts[result.status] = counts.get(result.status, 0) + 1

        return {
            "component": "SPT-023.3",
            "layer": "2",
            "source_component": "SPT-023.2",
            "source_batch_hash": source_batch_hash,
            "records_processed": len(results),
            "status_counts": counts,
            "automatic_category_creation": False,
            "requires_human_validation": True,
            "next_component": "SPT-023.3-CAPA-3",
            "results": [result.to_dict() for result in results],
        }
