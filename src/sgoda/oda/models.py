"""Modelos institucionales de Objetos Digitales de Aprendizaje."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class RecursoMultimediaODA:
    """Referencia extensible a un recurso multimedia."""

    tipo: str
    estado: str = "pendiente"
    uri: str | None = None
    proveedor: str | None = None
    checksum_sha256: str | None = None
    metadatos: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class TrazabilidadODA:
    """Origen y versionado de un ODA."""

    canonical_id: str
    source_release: str
    source_schema: str
    source_repository_sha256: str
    generator: str
    generator_version: str


@dataclass(slots=True)
class ObjetoDigitalAprendizaje:
    """Unidad funcional de aprendizaje derivada del repositorio canónico."""

    oda_id: str
    canonical_id: str
    version: str
    estado: str
    palabra_puinave: str
    traduccion_espanol: str | None = None
    traduccion_ingles: str | None = None
    categoria_gramatical: str | None = None
    tema_cultural: str | None = None
    contexto_etnografico: str | None = None
    definicion: str | None = None
    ejemplo_uso: str | None = None
    recursos: list[RecursoMultimediaODA] = field(default_factory=list)
    campos_extensibles: dict[str, Any] = field(default_factory=dict)
    trazabilidad: TrazabilidadODA | None = None
    validaciones: list[str] = field(default_factory=list)


@dataclass(slots=True)
class ResultadoGeneracionODA:
    """Resultado integral de una generación del repositorio ODA."""

    objetos: list[ObjetoDigitalAprendizaje]
    errores: list[dict[str, Any]]
    advertencias: list[dict[str, Any]]
    estadisticas: dict[str, Any]