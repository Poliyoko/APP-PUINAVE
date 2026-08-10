from __future__ import annotations

from typing import Any

from .handoff import build_fld_oda_handoff
from .manifest import build_completeness_manifest
from .quality import review_resource


class Spt0234Layer3GovernanceService:
    """Gobernanza de calidad, completitud y salida a SPT-023.5."""

    def review_bundle(
        self,
        *,
        lexical_id: str,
        puinave: str,
        category_id: str | None,
        resources: list[dict[str, Any]],
        decisions: dict[str, dict[str, Any]],
    ) -> dict[str, Any]:
        reviewed: list[dict[str, Any]] = []

        for resource in resources:
            resource_type = str(resource.get("resource_type") or "")
            decision_input = decisions.get(resource_type)
            if decision_input is None:
                continue

            reviewed.append(
                review_resource(
                    resource,
                    approve=bool(decision_input.get("approve")),
                    reviewer=str(decision_input.get("reviewer") or ""),
                    reason=str(decision_input.get("reason") or ""),
                ).to_dict()
            )

        manifest = build_completeness_manifest(
            lexical_id,
            reviewed,
        ).to_dict()

        result: dict[str, Any] = {
            "component": "SPT-023.4",
            "layer": "3",
            "lexical_id": lexical_id,
            "quality_decisions": reviewed,
            "manifest": manifest,
            "status": "READY_FOR_FLD_ODA" if manifest["complete"] else "MULTIMEDIA_REVIEW_REQUIRED",
            "paid_api_used": False,
            "next_component": "SPT-023.5" if manifest["complete"] else "SPT-023.4-CAPA-3",
        }

        if manifest["complete"]:
            approved_resources = [
                item for item in reviewed if item["approved"]
            ]
            result["handoff"] = build_fld_oda_handoff(
                lexical_id=lexical_id,
                puinave=puinave,
                category_id=category_id,
                manifest=manifest,
                approved_resources=approved_resources,
            )
        else:
            result["handoff"] = None

        return result
