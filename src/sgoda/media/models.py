"""Modelos dinámicos del Repositorio Multimedia Relacional (RMR)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class RecursoMultimediaRMR:
    """Recurso multimedia extensible y versionado."""

    resource_id: str
    oda_id: str
    canonical_id: str
    resource_type: str
    subtype: str = "principal"
    language: str | None = None
    variant: str | None = None
    provider: str | None = None
    version: str = "1.0.0"
    media_format: str | None = None
    uri: str | None = None
    checksum_sha256: str | None = None
    status: str = "pendiente"
    metadata: dict[str, Any] = field(default_factory=dict)
    created_at_utc: str | None = None
    updated_at_utc: str | None = None


@dataclass(slots=True)
class ConsultaRecursosRMR:
    """Filtros y paginación para consultar recursos."""

    oda_id: str | None = None
    canonical_id: str | None = None
    resource_type: str | None = None
    language: str | None = None
    status: str | None = None
    limit: int = 100
    offset: int = 0


@dataclass(slots=True)
class ResultadoMigracionRMR:
    """Resultado de migrar slots ODA al RMR."""

    total_oda: int
    total_resources: int
    inserted: int
    updated: int
    errors: list[dict[str, Any]]