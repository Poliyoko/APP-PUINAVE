"""Construcción de paquetes multimedia para ODA."""

from __future__ import annotations

from typing import Any

from .manifest import media_to_dict
from .models import MediaResource


_REQUIRED_TYPES = {
    "image",
    "audio_puinave",
    "audio_spanish",
    "audio_english_us",
}


def build_multimedia_oda(
    entry_id: str,
    resources: tuple[MediaResource, ...],
) -> dict[str, Any]:
    validated = tuple(
        item
        for item in resources
        if item.validated
    )
    available_types = {
        item.media_type
        for item in validated
    }
    missing = sorted(
        _REQUIRED_TYPES - available_types
    )

    return {
        "oda_id": f"ODA-MEDIA-{entry_id}",
        "entry_id": entry_id,
        "resources": [
            media_to_dict(item)
            for item in validated
        ],
        "required_types": sorted(_REQUIRED_TYPES),
        "missing_types": missing,
        "complete": len(missing) == 0,
        "validated_only": True,
        "no_invention": True,
    }