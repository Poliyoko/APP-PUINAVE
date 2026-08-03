"""Validación institucional de recursos multimedia."""

from __future__ import annotations

from pathlib import PurePosixPath
from typing import Any


_ALLOWED_TYPES = {
    "image",
    "audio_puinave",
    "audio_spanish",
    "audio_english_us",
    "audio_italian",
    "video",
}

_ALLOWED_FORMATS = {
    "image": {"png", "jpg", "jpeg", "webp"},
    "audio_puinave": {"wav", "mp3", "ogg", "flac"},
    "audio_spanish": {"wav", "mp3", "ogg", "flac"},
    "audio_english_us": {"wav", "mp3", "ogg", "flac"},
    "audio_italian": {"wav", "mp3", "ogg", "flac"},
    "video": {"mp4", "webm"},
}


def normalize_text(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def validate_media_payload(
    payload: dict[str, Any],
) -> tuple[str, ...]:
    errors = []

    resource_id = normalize_text(payload.get("resource_id"))
    entry_id = normalize_text(payload.get("entry_id"))
    media_type = normalize_text(payload.get("media_type"))
    uri = normalize_text(payload.get("uri"))
    media_format = normalize_text(payload.get("format")).casefold()

    if not resource_id.startswith("MED-"):
        errors.append("resource_id debe iniciar con MED-.")

    if not entry_id.startswith("LEX-"):
        errors.append("entry_id debe iniciar con LEX-.")

    if media_type not in _ALLOWED_TYPES:
        errors.append("media_type no está permitido.")

    if not uri:
        errors.append("La URI del recurso es obligatoria.")
    elif PurePosixPath(uri.replace("\\", "/")).is_absolute():
        errors.append("La URI debe ser relativa al repositorio.")

    allowed = _ALLOWED_FORMATS.get(media_type, set())
    if media_format not in allowed:
        errors.append(
            f"Formato no permitido para {media_type}: {media_format}"
        )

    duration = payload.get("duration_seconds")
    if duration is not None:
        try:
            if float(duration) < 0:
                errors.append("duration_seconds no puede ser negativo.")
        except (TypeError, ValueError):
            errors.append("duration_seconds debe ser numérico.")

    return tuple(errors)