"""Validación y normalización de identificadores del DMP."""

from __future__ import annotations

import re

_IDENTIFIER_PATTERN = re.compile(r"^[A-Z][A-Z0-9]*(?:-[A-Z0-9]+(?:\.[A-Z0-9]+)*)+$")


def normalize_identifier(value: str) -> str:
    """Normaliza y valida un identificador trazable del proyecto."""
    normalized = value.strip().upper()
    if not normalized:
        raise ValueError("El identificador no puede estar vacío")
    if not _IDENTIFIER_PATTERN.fullmatch(normalized):
        raise ValueError(f"Identificador DMP inválido: {value!r}")
    return normalized
