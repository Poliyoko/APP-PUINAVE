"""Serialización de índices y metadatos de sincronización."""

from __future__ import annotations

import json
from typing import Any

from .index_models import IndexPackage, RepositoryIndex, SyncMetadata


class IndexSerializationError(ValueError):
    """Documento de índice o metadatos inválido."""


def dumps_index(index: RepositoryIndex) -> str:
    return json.dumps(index.to_dict(), ensure_ascii=False, indent=2) + "\n"


def loads_index(content: str) -> RepositoryIndex:
    try:
        payload: Any = json.loads(content)
        if not isinstance(payload, dict):
            raise TypeError("la raíz debe ser un objeto")
        packages = payload.get("packages")
        if not isinstance(packages, list):
            raise TypeError("'packages' debe ser una lista")
        return RepositoryIndex(
            schema_version=str(payload["schema_version"]),
            repository=str(payload["repository"]),
            generated_at=str(payload["generated_at"]),
            packages=tuple(IndexPackage(**item) for item in packages),
        )
    except (json.JSONDecodeError, TypeError, KeyError) as exc:
        raise IndexSerializationError(f"Índice remoto inválido: {exc}") from exc


def dumps_metadata(metadata: SyncMetadata) -> str:
    return json.dumps(metadata.to_dict(), ensure_ascii=False, indent=2) + "\n"


def loads_metadata(content: str) -> SyncMetadata:
    try:
        payload: Any = json.loads(content)
        if not isinstance(payload, dict):
            raise TypeError("la raíz debe ser un objeto")
        return SyncMetadata(**payload)
    except (json.JSONDecodeError, TypeError, KeyError) as exc:
        raise IndexSerializationError(f"Metadatos de sincronización inválidos: {exc}") from exc
