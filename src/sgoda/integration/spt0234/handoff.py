from __future__ import annotations

from typing import Any


def build_fld_oda_handoff(
    *,
    lexical_id: str,
    puinave: str,
    category_id: str | None,
    manifest: dict[str, Any],
    approved_resources: list[dict[str, Any]],
) -> dict[str, Any]:
    lexical_id = str(lexical_id or "").strip()
    puinave = str(puinave or "").strip()

    if not lexical_id:
        raise ValueError("lexical_id is required.")
    if not puinave:
        raise ValueError("Puinave text is required.")
    if not bool(manifest.get("complete")):
        raise ValueError("Multimedia manifest must be complete before FLD/ODA handoff.")

    if len(approved_resources) != 5:
        raise ValueError("Exactly five approved multimedia resources are required.")

    return {
        "component": "SPT-023.4",
        "layer": "3",
        "status": "READY_FOR_FLD_ODA",
        "lexical_id": lexical_id,
        "puinave": puinave,
        "category_id": category_id,
        "multimedia_manifest_sha256": manifest["manifest_sha256"],
        "resources": list(approved_resources),
        "requires_human_validation": False,
        "paid_api_used": False,
        "next_component": "SPT-023.5",
    }
