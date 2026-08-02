"""Modelos canónicos del Repositorio Léxico Base."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class OrigenRLB:
    """Trazabilidad del registro con respecto al Excel original."""

    archivo: str
    hoja: str
    fila: int
    version_esquema: str = "1.0.0"


@dataclass(frozen=True, slots=True)
class CampoDesconocido:
    """Campo aún no incorporado formalmente al esquema institucional."""

    columna_original: str
    valor: Any


@dataclass(slots=True)
class RegistroLexico:
    """Representación canónica y extensible de una fila del RLB."""

    identificador: str | None
    palabra_puinave: str
    traduccion_espanol: str | None = None
    traduccion_ingles: str | None = None
    categoria_gramatical: str | None = None
    categoria_tematica: str | None = None

    tema_cultural: str | None = None
    descripcion_cultural: str | None = None
    contexto_uso: str | None = None
    comunidad: str | None = None
    territorio: str | None = None

    imagen: str | None = None
    audio_puinave: str | None = None
    audio_espanol: str | None = None
    audio_ingles: str | None = None
    video: str | None = None

    nivel_acceso: str = "pendiente_clasificacion"
    autorizacion_publicacion: bool = False
    estado_validacion: str = "pendiente"

    origen: OrigenRLB | None = None
    extensiones: dict[str, Any] = field(default_factory=dict)
    campos_desconocidos: list[CampoDesconocido] = field(default_factory=list)

    def validar_minimo(self) -> list[str]:
        """Devuelve errores del contrato mínimo sin perder el registro."""

        errores: list[str] = []

        if not self.palabra_puinave.strip():
            errores.append("La palabra Puinave es obligatoria.")

        if self.origen is not None and self.origen.fila < 1:
            errores.append("La fila de origen debe ser mayor o igual a 1.")

        return errores