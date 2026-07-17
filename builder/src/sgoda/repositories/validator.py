"""Validación de repositorios remotos."""

from __future__ import annotations

import re
from urllib.parse import urlparse


class RepositoryValidationError(ValueError):
    """Configuración de repositorio inválida."""


_NAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")


def normalize_name(name: str) -> str:
    normalized = name.strip().lower()
    if not _NAME_PATTERN.fullmatch(normalized):
        raise RepositoryValidationError(
            "El nombre debe tener 1-64 caracteres: minúsculas, números, '.', '_' o '-'."
        )
    return normalized


def normalize_url(url: str) -> str:
    normalized = url.strip().rstrip("/")
    parsed = urlparse(normalized)
    if parsed.scheme not in {"http", "https"}:
        raise RepositoryValidationError("La URL debe usar http o https.")
    if not parsed.netloc:
        raise RepositoryValidationError("La URL debe incluir un host.")
    if parsed.username or parsed.password:
        raise RepositoryValidationError("La URL no debe incluir credenciales.")
    return normalized


def validate_priority(priority: int) -> int:
    if isinstance(priority, bool) or not isinstance(priority, int):
        raise RepositoryValidationError("La prioridad debe ser un entero.")
    if not 0 <= priority <= 1000:
        raise RepositoryValidationError("La prioridad debe estar entre 0 y 1000.")
    return priority
