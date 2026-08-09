"""Validacion de contrato SPT-023.1 -> SPT-023.2."""

from __future__ import annotations

from typing import Any

from sgoda.dictionary_manager.validation import normalize_text


def validate_detector_word(
    word: dict[str, Any],
) -> tuple[str, ...]:
    """Valida solamente el contrato requerido por SPT-023.2.

    No modifica SPT-023.1 y no inventa informacion ausente.
    """
    errors: list[str] = []

    puinave = normalize_text(word.get("puinave"))
    normalized = normalize_text(word.get("normalized_puinave"))
    lexical_hash = normalize_text(word.get("lexical_hash"))
    status = normalize_text(word.get("status")).upper()

    if not puinave:
        errors.append("PUINAVE_REQUIRED")

    if not normalized:
        errors.append("NORMALIZED_PUINAVE_REQUIRED")

    if not lexical_hash:
        errors.append("LEXICAL_HASH_REQUIRED")

    if not status:
        errors.append("DETECTOR_STATUS_REQUIRED")

    return tuple(errors)


def detector_metadata(
    word: dict[str, Any],
) -> dict[str, Any]:
    raw = word.get("metadata")

    if isinstance(raw, dict):
        return dict(raw)

    return {}