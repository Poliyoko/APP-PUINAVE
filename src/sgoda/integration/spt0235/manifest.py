from __future__ import annotations

import hashlib
import json
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def build_publication_manifest(
    *,
    decision: dict[str, Any],
    registry_validation: dict[str, Any],
) -> dict[str, Any]:
    if not bool(decision.get("approved")):
        raise ValueError("Publication manifest requires an approved decision.")
    if str(decision.get("status")) != "APPROVED_FOR_PUBLICATION":
        raise ValueError("Publication decision status is invalid.")
    if not bool(registry_validation.get("references_valid")):
        raise ValueError("Registry references must be valid.")

    payload = {
        "schema_version": "1.0.0",
        "component": "SPT-023.5",
        "layer": "3",
        "lexical_id": str(decision["lexical_id"]),
        "version": int(decision["version"]),
        "fld_sha256": str(decision["fld_sha256"]),
        "oda_sha256": str(decision["oda_sha256"]),
        "version_sha256": str(decision["version_sha256"]),
        "reviewer": str(decision["reviewer"]),
        "reason": str(decision["reason"]),
        "publication_status": "READY_FOR_INSTITUTIONAL_REGISTRY",
        "references_valid": True,
        "paid_api_used": False,
    }
    payload["publication_manifest_sha256"] = hashlib.sha256(
        _canonical(payload)
    ).hexdigest().upper()
    return payload
