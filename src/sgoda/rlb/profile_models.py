"""Modelos del perfil técnico del Repositorio Léxico Base."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(slots=True)
class PerfilHojaRLB:
    """Resultado del análisis estructural de una hoja Excel."""

    nombre: str
    fila_encabezado: int | None
    total_filas_fisicas: int
    total_columnas_fisicas: int
    total_registros: int = 0
    total_registros_validos: int = 0
    total_registros_con_errores: int = 0
    columnas: list[str] = field(default_factory=list)
    columnas_reconocidas: list[str] = field(default_factory=list)
    columnas_desconocidas: list[str] = field(default_factory=list)
    columnas_vacias: list[str] = field(default_factory=list)
    errores: list[str] = field(default_factory=list)


@dataclass(slots=True)
class PerfilRepositorioRLB:
    """Perfil integral del archivo Excel institucional."""

    archivo: str
    version_esquema: str
    total_hojas: int
    total_registros: int = 0
    total_registros_validos: int = 0
    total_registros_con_errores: int = 0
    hojas: list[PerfilHojaRLB] = field(default_factory=list)
    advertencias: list[str] = field(default_factory=list)