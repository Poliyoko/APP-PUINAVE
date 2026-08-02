"""Adaptador de recursos multimedia."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ALLOWED_MEDIA_TYPES = {
    "audio_puinave",
    "audio_spanish",
    "audio_english_us",
    "audio_italian",
    "image",
    "video",
}


def load_media_manifest(
    path: str | Path,
) -> tuple[dict[str, Any], ...]:
    payload = json.loads(
        Path(path).read_text(encoding="utf-8-sig")
    )

    resources = (
        payload.get("resources", [])
        if isinstance(payload, dict)
        else payload
    )

    if not isinstance(resources, list):
        raise ValueError(
            "El manifiesto multimedia debe ser una lista."
        )

    result = []

    for item in resources:
        if not isinstance(item, dict):
            continue

        media_type = str(
            item.get("media_type") or ""
        ).strip()

        if media_type not in ALLOWED_MEDIA_TYPES:
            continue

        entry_id = str(
            item.get("entry_id") or ""
        ).strip()
        uri = str(item.get("uri") or "").strip()

        if not entry_id or not uri:
            continue

        result.append(
            {
                "entry_id": entry_id,
                "media_type": media_type,
                "uri": uri,
                "validated": bool(
                    item.get("validated", False)
                ),
                "autoplay": bool(
                    item.get("autoplay", False)
                ),
            }
        )

    return tuple(result)