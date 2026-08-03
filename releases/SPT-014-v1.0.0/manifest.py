"""Importación y exportación de manifiestos multimedia."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import MediaResource
from .validation import normalize_text


def media_from_dict(payload: dict[str, Any]) -> MediaResource:
    duration = payload.get("duration_seconds")

    return MediaResource(
        resource_id=normalize_text(payload.get("resource_id")),
        entry_id=normalize_text(payload.get("entry_id")),
        media_type=normalize_text(payload.get("media_type")),
        language=normalize_text(payload.get("language")),
        uri=normalize_text(payload.get("uri")).replace("\\", "/"),
        format=normalize_text(payload.get("format")).casefold(),
        validated=bool(payload.get("validated", False)),
        autoplay=bool(payload.get("autoplay", False)),
        duration_seconds=(
            float(duration)
            if duration is not None
            else None
        ),
        checksum=normalize_text(payload.get("checksum")),
        metadata=dict(payload.get("metadata") or {}),
    )


def media_to_dict(resource: MediaResource) -> dict[str, Any]:
    return {
        "resource_id": resource.resource_id,
        "entry_id": resource.entry_id,
        "media_type": resource.media_type,
        "language": resource.language,
        "uri": resource.uri,
        "format": resource.format,
        "validated": resource.validated,
        "autoplay": resource.autoplay,
        "duration_seconds": resource.duration_seconds,
        "checksum": resource.checksum,
        "metadata": dict(resource.metadata),
    }


def load_manifest(path: str | Path) -> tuple[MediaResource, ...]:
    payload = json.loads(
        Path(path).read_text(encoding="utf-8-sig")
    )
    records = (
        payload.get("resources", [])
        if isinstance(payload, dict)
        else payload
    )

    if not isinstance(records, list):
        raise ValueError(
            "El manifiesto debe contener una lista de recursos."
        )

    return tuple(
        media_from_dict(item)
        for item in records
        if isinstance(item, dict)
    )


def export_manifest(
    path: str | Path,
    resources: tuple[MediaResource, ...],
) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            {
                "schema": "SPT-014",
                "version": "1.0.0",
                "resources": [
                    media_to_dict(item)
                    for item in resources
                ],
            },
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )