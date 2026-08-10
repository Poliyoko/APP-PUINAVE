from __future__ import annotations

from typing import Any, Iterable

from .planner import build_multimedia_plan


class Spt0234Layer1Service:
    """Planificador multimedia institucional.

    Esta capa no llama proveedores externos. Integra y reutiliza los contratos
    existentes para dejar cada recurso en una ruta institucional explÃ­cita.
    """

    def plan_one(
        self,
        record: dict[str, Any],
        *,
        existing_resources: Iterable[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        return build_multimedia_plan(
            record,
            existing_resources=existing_resources,
        ).to_dict()

    def plan_batch(
        self,
        records: Iterable[dict[str, Any]],
        *,
        existing_by_lexical_id: dict[str, list[dict[str, Any]]] | None = None,
    ) -> dict[str, Any]:
        existing_by_lexical_id = existing_by_lexical_id or {}
        results: list[dict[str, Any]] = []

        for record in records:
            lexical_id = str(
                record.get("canonical_id")
                or record.get("lexical_id")
                or record.get("lexical_hash")
                or ""
            ).strip()

            results.append(
                self.plan_one(
                    record,
                    existing_resources=existing_by_lexical_id.get(lexical_id, []),
                )
            )

        status_counts: dict[str, int] = {}
        for result in results:
            for plan in result["plans"]:
                status = plan["status"]
                status_counts[status] = status_counts.get(status, 0) + 1

        return {
            "component": "SPT-023.4",
            "layer": "1",
            "records_processed": len(results),
            "resource_plans": sum(len(item["plans"]) for item in results),
            "status_counts": status_counts,
            "automatic_external_calls": False,
            "paid_api_allowed": False,
            "results": results,
            "next_component": "SPT-023.4-CAPA-2",
        }
