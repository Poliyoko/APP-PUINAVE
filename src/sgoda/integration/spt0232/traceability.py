"""SPT-023.2 - trazabilidad institucional de procesamiento."""

from __future__ import annotations

from typing import Any


def build_traceability(
    analysis: dict[str, Any],
) -> dict[str, Any]:
    results = analysis.get("results") or []

    lexical_hashes: list[str] = []

    for item in results:
        if not isinstance(item, dict):
            continue

        value = item.get("lexical_hash")

        if value:
            lexical_hashes.append(str(value))

    return {
        "component": "SPT-023.2",
        "source_component": analysis.get(
            "source_component",
            "SPT-023.1",
        ),
        "source_batch_hash": analysis.get(
            "source_batch_hash"
        ),
        "layer": "CAPA_3",
        "records": len(results),
        "lexical_hashes": sorted(
            set(lexical_hashes)
        ),
        "engines": [
            "SPT-007A",
            "SPT-007B",
            "SPT-023.1",
            "SPT-023.2",
        ],
        "next_component": (
            "CATEGORY_ENGINE_PENDING_RECONCILIATION"
        ),
        "no_invention": True,
    }