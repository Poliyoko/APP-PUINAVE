"""Carga del esquema versionado del Repositorio Léxico Base."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .schema import CampoEsquema, EsquemaRLB


class ErrorEsquemaRLB(ValueError):
    """Error de configuración del esquema institucional del RLB."""


def cargar_esquema(ruta: str | Path) -> EsquemaRLB:
    """Carga un esquema JSON y crea el contrato de mapeo."""

    ruta_esquema = Path(ruta)

    if not ruta_esquema.is_file():
        raise FileNotFoundError(
            f"No se encontró el esquema RLB: {ruta_esquema}"
        )

    try:
        contenido: dict[str, Any] = json.loads(
            ruta_esquema.read_text(encoding="utf-8")
        )
    except json.JSONDecodeError as error:
        raise ErrorEsquemaRLB(
            f"El esquema RLB no contiene JSON válido: {error}"
        ) from error

    version = str(contenido.get("version") or "").strip()
    campos_json = contenido.get("fields")

    if not version:
        raise ErrorEsquemaRLB(
            "El esquema RLB debe declarar una versión."
        )

    if not isinstance(campos_json, list) or not campos_json:
        raise ErrorEsquemaRLB(
            "El esquema RLB debe declarar una lista de campos."
        )

    campos: list[CampoEsquema] = []

    for posicion, campo_json in enumerate(campos_json, start=1):
        if not isinstance(campo_json, dict):
            raise ErrorEsquemaRLB(
                f"El campo {posicion} no es un objeto."
            )

        nombre = str(campo_json.get("name") or "").strip()

        if not nombre:
            raise ErrorEsquemaRLB(
                f"El campo {posicion} no tiene nombre."
            )

        aliases = campo_json.get("aliases", [])

        if not isinstance(aliases, list):
            raise ErrorEsquemaRLB(
                f"Los aliases de {nombre!r} deben ser una lista."
            )

        campos.append(
            CampoEsquema(
                nombre_canonico=nombre,
                aliases=tuple(str(alias) for alias in aliases),
                obligatorio=bool(campo_json.get("required", False)),
            )
        )

    return EsquemaRLB(version=version, campos=campos)