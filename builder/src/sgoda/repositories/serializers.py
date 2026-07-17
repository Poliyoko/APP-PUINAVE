"""Serialización estable del registro de repositorios."""

from __future__ import annotations

import json
from typing import Any

from .models import Repository, RepositoryRegistry


class RepositorySerializationError(ValueError):
    """Documento de repositorios inválido."""


def dumps_registry(registry: RepositoryRegistry) -> str:
    return json.dumps(registry.to_dict(), ensure_ascii=False, indent=2) + "\n"


def loads_registry(content: str) -> RepositoryRegistry:
    try:
        payload: Any = json.loads(content)
        if not isinstance(payload, dict):
            raise TypeError("la raíz debe ser un objeto")
        repositories = payload.get("repositories", [])
        if not isinstance(repositories, list):
            raise TypeError("'repositories' debe ser una lista")
        return RepositoryRegistry(
            schema_version=str(payload.get("schema_version", "1.0")),
            repositories=tuple(Repository(**item) for item in repositories),
        )
    except (json.JSONDecodeError, TypeError, KeyError) as exc:
        raise RepositorySerializationError(
            f"Registro de repositorios inválido: {exc}"
        ) from exc
