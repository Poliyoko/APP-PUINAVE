"""Normalización de identificadores PMO."""

from __future__ import annotations


def normalize_identifier(value: str) -> str:
    clean = value.strip().replace(" ", "-")
    if not clean:
        raise ValueError("El identificador no puede estar vacío")
    return clean.upper()
