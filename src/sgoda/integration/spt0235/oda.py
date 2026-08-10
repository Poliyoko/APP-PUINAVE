from __future__ import annotations

import hashlib
import json
from typing import Any


def _sha256(value: object) -> str:
    data = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(data).hexdigest().upper()


def build_oda(fld: dict[str, Any]) -> dict[str, Any]:
    if fld.get("object_type") != "FLD":
        raise ValueError("ODA construction requires FLD input.")

    lexical_id = str(fld.get("lexical_id") or "").strip()
    puinave = str(fld.get("puinave") or "").strip()
    resources = dict(fld.get("resources") or {})

    if not lexical_id or not puinave:
        raise ValueError("FLD lexical identity is incomplete.")
    if len(resources) != 5:
        raise ValueError("FLD must reference exactly five multimedia resources.")

    payload: dict[str, Any] = {
        "schema_version": "1.0.0",
        "object_type": "ODA",
        "component": "SPT-023.5",
        "lexical_id": lexical_id,
        "title": puinave,
        "learning_object": {
            "term": puinave,
            "category_id": fld.get("category_id"),
            "translations": dict(fld.get("translations") or {}),
            "multimedia": resources,
        },
        "source_fld_sha256": fld["fld_sha256"],
        "multimedia_manifest_sha256": fld["multimedia_manifest_sha256"],
        "institutional_metadata": {
            "source_component": "SPT-023.5-FLD",
            "target_component": "SPT-023.5-ODA",
            "ready_for_registry": True,
        },
    }
    payload["oda_sha256"] = _sha256(payload)
    return payload
