"""Exportación institucional de datos y evidencias del RLB."""

from __future__ import annotations

import json
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .excel_reader import ResultadoLecturaRLB


def _escribir_json(
    ruta: Path,
    contenido: Any,
) -> Path:
    """Escribe JSON UTF-8 legible y devuelve su ruta."""

    ruta.parent.mkdir(parents=True, exist_ok=True)

    ruta.write_text(
        json.dumps(
            contenido,
            ensure_ascii=False,
            indent=2,
            default=str,
        )
        + "\n",
        encoding="utf-8",
    )

    if not ruta.is_file() or ruta.stat().st_size <= 0:
        raise RuntimeError(
            f"No se pudo generar el artefacto JSON: {ruta}"
        )

    return ruta


def exportar_resultado(
    resultado: ResultadoLecturaRLB,
    directorio: str | Path,
) -> dict[str, Path]:
    """Genera JSON canónico, perfil técnico y reporte de errores."""

    if resultado.perfil is None:
        raise ValueError(
            "El resultado de lectura no contiene perfil institucional."
        )

    destino = Path(directorio)
    destino.mkdir(parents=True, exist_ok=True)

    generado_en = datetime.now(timezone.utc).isoformat()

    registros = [
        asdict(registro)
        for registro in resultado.registros
    ]

    errores = [
        asdict(error)
        for error in resultado.errores
    ]

    perfil = asdict(resultado.perfil)

    canonico = {
        "metadata": {
            "sistema": "SGODA-PUINAVE",
            "entregable": "SPT-001B-P05",
            "generado_en_utc": generado_en,
            "archivo_origen": resultado.perfil.archivo,
            "version_esquema": resultado.perfil.version_esquema,
            "total_hojas": resultado.perfil.total_hojas,
            "total_registros": len(registros),
            "total_registros_validos": (
                resultado.perfil.total_registros_validos
            ),
            "total_registros_con_errores": (
                resultado.perfil.total_registros_con_errores
            ),
        },
        "registros": registros,
    }

    reporte_errores = {
        "metadata": {
            "sistema": "SGODA-PUINAVE",
            "entregable": "SPT-001B-P05",
            "generado_en_utc": generado_en,
            "archivo_origen": resultado.perfil.archivo,
            "total": len(errores),
        },
        "errores": errores,
    }

    return {
        "canonico": _escribir_json(
            destino / "palabras-canonicas.json",
            canonico,
        ),
        "perfil": _escribir_json(
            destino / "perfil-rlb.json",
            perfil,
        ),
        "errores": _escribir_json(
            destino / "errores-importacion.json",
            reporte_errores,
        ),
    }