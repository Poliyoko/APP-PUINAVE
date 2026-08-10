from __future__ import annotations

import hashlib
import json
from typing import Any

from .models import LexicalInput


def _sha256(value: object) -> str:
    data = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(data).hexdigest().upper()


def build_fld(source: LexicalInput) -> dict[str, Any]:
    resources = {
        item.resource_type: item.to_dict()
        for item in source.resources
    }

    payload: dict[str, Any] = {
        "schema_version": "1.0.0",
        "object_type": "FLD",
        "component": "SPT-023.5",
        "lexical_id": source.lexical_id,
        "puinave": source.puinave,
        "category_id": source.category_id,
        "translations": {
            "es": str(source.translations.get("es") or ""),
            "en": str(source.translations.get("en") or ""),
            "it": str(source.translations.get("it") or ""),
        },
        "multimedia_manifest_sha256": source.multimedia_manifest_sha256,
        "resources": resources,
        "institutional_metadata": {
            "source_component": "SPT-023.4",
            "builder_component": "SPT-023.5",
            "traceability_required": True,
        },
    }
    payload["fld_sha256"] = _sha256(payload)
    return payload
