"""SPT-023.2 - orquestacion de inteligencia semantica Capa 2."""

from __future__ import annotations

from typing import Any

from .confidence import assess_confidence
from .context import assess_context
from .duplicates import (
    assess_duplicate,
    build_batch_counts,
)


class Spt0232IntelligenceService:
    """Enriquece la salida de Capa 1 sin modificarla."""

    def __init__(
        self,
        semantic_validation_service: Any,
        confidence_threshold: float = 0.70,
    ) -> None:
        self.semantic_validation_service = (
            semantic_validation_service
        )
        self.confidence_threshold = max(
            0.0,
            min(1.0, float(confidence_threshold)),
        )

    def analyze_batch(
        self,
        detector_batch: dict[str, Any],
    ) -> dict[str, Any]:
        semantic_batch = (
            self.semantic_validation_service.analyze_batch(
                detector_batch
            )
        )

        base_results = [
            dict(item)
            for item in semantic_batch.get("results", [])
            if isinstance(item, dict)
        ]

        counts = build_batch_counts(base_results)

        enriched: list[dict[str, Any]] = []

        ready_for_category = 0
        duplicate_blocked = 0
        human_review = 0

        for item in base_results:
            duplicate = assess_duplicate(
                item,
                counts,
            )
            context = assess_context(item)
            confidence = assess_confidence(
                item,
                duplicate,
                context,
                threshold=self.confidence_threshold,
            )

            semantic_status = str(
                item.get("semantic_status") or ""
            )

            validation_status = str(
                item.get("validation_status") or ""
            )

            ready = (
                validation_status == "VALIDATED"
                and semantic_status == "MATCHED"
                and not duplicate.blocked
                and confidence.score
                >= self.confidence_threshold
            )

            if duplicate.blocked:
                decision = "DUPLICATE_BLOCKED"
                duplicate_blocked += 1
            elif ready:
                decision = "READY_FOR_CATEGORY"
                ready_for_category += 1
            elif validation_status in {
                "INVALID",
                "SKIPPED",
            }:
                decision = "NOT_ELIGIBLE"
            else:
                decision = "HUMAN_REVIEW_REQUIRED"
                human_review += 1

            enriched_item = dict(item)

            enriched_item["duplicate_assessment"] = (
                duplicate.to_dict()
            )
            enriched_item["context_assessment"] = (
                context.to_dict()
            )
            enriched_item["confidence_assessment"] = (
                confidence.to_dict()
            )
            enriched_item["institutional_decision"] = (
                decision
            )
            enriched_item["downstream_allowed"] = ready
            enriched_item["requires_human_validation"] = (
                decision
                in {
                    "HUMAN_REVIEW_REQUIRED",
                    "DUPLICATE_BLOCKED",
                }
            )

            enriched.append(enriched_item)

        return {
            **{
                key: value
                for key, value in semantic_batch.items()
                if key != "results"
            },
            "component": "SPT-023.2",
            "layer": "CAPA_2",
            "policy": {
                "no_invention": True,
                "duplicate_blocking": True,
                "confidence_threshold": (
                    self.confidence_threshold
                ),
            },
            "ready_for_category": ready_for_category,
            "duplicate_blocked": duplicate_blocked,
            "human_review_required": human_review,
            "next_component": "CATEGORY_ENGINE_PENDING_RECONCILIATION",
            "results": enriched,
        }