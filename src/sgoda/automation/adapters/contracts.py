"""Contratos de adaptadores multimedia SPT-003B."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass(slots=True)
class SolicitudProveedor:
    job_id: str
    job_type: str
    resource_id: str
    oda_id: str
    language: str | None
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class ResultadoProveedor:
    success: bool
    provider: str
    external_id: str | None = None
    media_bytes: bytes | None = None
    media_type: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)
    error: str | None = None


@dataclass(slots=True)
class ResultadoPersistencia:
    resource_id: str
    uri: str
    sha256: str
    size_bytes: int
    media_type: str
    metadata: dict[str, Any] = field(default_factory=dict)


class ProveedorMultimedia(Protocol):
    name: str

    def supports(self, job_type: str) -> bool:
        ...

    def execute(
        self,
        request: SolicitudProveedor,
    ) -> ResultadoProveedor:
        ...


class AlmacenamientoMultimedia(Protocol):
    def store(
        self,
        *,
        resource_id: str,
        media_bytes: bytes,
        media_type: str,
        metadata: dict[str, Any],
    ) -> ResultadoPersistencia:
        ...


class PublicadorEventos(Protocol):
    def publish(
        self,
        *,
        event_type: str,
        payload: dict[str, Any],
    ) -> None:
        ...