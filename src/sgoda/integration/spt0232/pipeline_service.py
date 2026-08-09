"""SPT-023.2 - fachada de integracion productiva."""

from __future__ import annotations

from copy import deepcopy
from typing import Any

from .production_contract import (
    to_detector_batch,
    validate_production_request,
)


class Spt0232ProductionPipeline:
    """Orquesta Capa 2 + Capa 3 sin acoplarse a FastAPI/n8n.

    FastAPI, n8n, SPT-022 y buses institucionales consumiran esta
    fachada en una capa de wiring posterior. Este servicio no inicia,
    detiene ni reemplaza servicios externos.
    """

    def __init__(
        self,
        intelligence_service: Any,
        evidence_store: Any,
    ) -> None:
        self.intelligence_service = (
            intelligence_service
        )
        self.evidence_store = evidence_store

    def process(
        self,
        payload: dict[str, Any],
        *,
        run_id: str | None = None,
        generated_at: str | None = None,
    ) -> dict[str, Any]:
        original = deepcopy(payload)

        request = validate_production_request(
            payload
        )

        detector_batch = to_detector_batch(
            request
        )

        analysis = (
            self.intelligence_service.analyze_batch(
                detector_batch
            )
        )

        evidence = self.evidence_store.persist(
            analysis,
            run_id=run_id,
            generated_at=generated_at,
        )

        if payload != original:
            raise RuntimeError(
                "SPT-023.2 input mutation detected."
            )

        return {
            "component": "SPT-023.2",
            "layer": "CAPA_4",
            "status": "PROCESSED",
            "source": request.source,
            "source_batch_hash": request.batch_hash,
            "records_received": len(
                request.words
            ),
            "records_processed": analysis.get(
                "records_processed",
                len(
                    analysis.get(
                        "results",
                        [],
                    )
                ),
            ),
            "ready_for_category": analysis.get(
                "ready_for_category",
                0,
            ),
            "duplicate_blocked": analysis.get(
                "duplicate_blocked",
                0,
            ),
            "human_review_required": analysis.get(
                "human_review_required",
                0,
            ),
            "no_invention": bool(
                analysis.get(
                    "policy",
                    {},
                ).get(
                    "no_invention",
                    analysis.get(
                        "no_invention",
                        True,
                    ),
                )
            ),
            "next_component": (
                "CATEGORY_ENGINE_PENDING_RECONCILIATION"
            ),
            "evidence": {
                "run_id": evidence["run_id"],
                "generated_at": evidence[
                    "generated_at"
                ],
                "run_dir": evidence["run_dir"],
                "analysis_sha256": evidence[
                    "analysis"
                ]["sha256"],
                "traceability_sha256": evidence[
                    "traceability"
                ]["sha256"],
                "manifest_sha256": evidence[
                    "manifest"
                ]["sha256"],
            },
            "analysis": analysis,
        }