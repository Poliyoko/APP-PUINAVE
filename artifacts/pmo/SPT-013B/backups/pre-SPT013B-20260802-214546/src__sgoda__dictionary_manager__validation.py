"""Validación institucional de entradas léxicas."""

from __future__ import annotations

import re
from typing import Any


_ENTRY_ID = re.compile(r"^LEX-\d{3,}$")


def normalize_text(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def normalize_list(value: Any) -> tuple[str, ...]:
    if value is None:
        return ()

    if isinstance(value, str):
        values = [value]
    elif isinstance(value, (list, tuple, set)):
        values = list(value)
    else:
        values = [value]

    normalized = []

    for item in values:
        text = normalize_text(item)

        if text and text not in normalized:
            normalized.append(text)

    return tuple(normalized)


def validate_entry_payload(
    payload: dict[str, Any],
) -> tuple[str, ...]:
    errors = []

    entry_id = normalize_text(payload.get("entry_id"))
    puinave = normalize_text(payload.get("puinave"))
    spanish = normalize_text(payload.get("spanish"))

    if not _ENTRY_ID.fullmatch(entry_id):
        errors.append(
            "entry_id debe cumplir el formato LEX-000."
        )

    if not puinave:
        errors.append("La forma Puinave es obligatoria.")

    if not spanish:
        errors.append("La traducción al español es obligatoria.")

    return tuple(errors)