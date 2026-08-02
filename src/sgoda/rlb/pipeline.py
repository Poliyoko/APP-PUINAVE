"""Pipeline institucional SPT-001B-P06."""

from __future__ import annotations

import hashlib
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path

from .events import (
    EventoRepositorioImportado,
    publicar_evento_jsonl,
)
from .excel_reader import LectorExcelRLB, ResultadoLecturaRLB
from .exporter import exportar_resultado
from .schema_loader import cargar_esquema


@dataclass(slots=True)
class ResultadoPipelineRLB:
    """Resultado integral y auditable del pipeline."""

    lectura: ResultadoLecturaRLB
    archivos_generados: dict[str, Path]
    evento: EventoRepositorioImportado
    historial_eventos: Path
    resumen_ejecucion: Path


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()


def _escribir_resumen(
    *,
    excel: Path,
    lectura: ResultadoLecturaRLB,
    archivos: dict[str, Path],
    evento: EventoRepositorioImportado,
    destino: Path,
) -> Path:
    if lectura.perfil is None:
        raise RuntimeError(
            "No existe perfil para generar el resumen."
        )

    contenido = {
        "sistema": "SGODA-PUINAVE",
        "incremento": "SPT-001B-P06",
        "generado_en_utc": datetime.now(timezone.utc).isoformat(),
        "archivo_origen": {
            "nombre": excel.name,
            "ruta": str(excel.resolve()),
            "sha256": _sha256(excel),
            "tamano_bytes": excel.stat().st_size,
        },
        "resultado": {
            "total_hojas": lectura.perfil.total_hojas,
            "total_registros": lectura.perfil.total_registros,
            "registros_validos": (
                lectura.perfil.total_registros_validos
            ),
            "registros_con_errores": (
                lectura.perfil.total_registros_con_errores
            ),
        },
        "artefactos": {
            name: {
                "ruta": str(path),
                "sha256": _sha256(path),
                "tamano_bytes": path.stat().st_size,
            }
            for name, path in archivos.items()
        },
        "evento": asdict(evento),
    }

    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(
        json.dumps(
            contenido,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    return destino


def ejecutar_pipeline(
    *,
    excel: str | Path,
    esquema: str | Path,
    salida: str | Path,
    historial_eventos: str | Path,
) -> ResultadoPipelineRLB:
    """Ejecuta lectura, perfilado, exportación, evento y resumen."""

    excel_path = Path(excel)

    if not excel_path.is_file():
        raise FileNotFoundError(
            f"No se encontró el Excel institucional: {excel_path}"
        )

    contrato = cargar_esquema(esquema)
    lectura = LectorExcelRLB(contrato).leer(excel_path)

    if lectura.perfil is None:
        raise RuntimeError(
            "La lectura no generó perfil institucional."
        )

    archivos = exportar_resultado(
        lectura,
        salida,
    )

    evento = EventoRepositorioImportado.crear(
        archivo=lectura.perfil.archivo,
        version_esquema=lectura.perfil.version_esquema,
        total_hojas=lectura.perfil.total_hojas,
        total_registros=lectura.perfil.total_registros,
        registros_validos=(
            lectura.perfil.total_registros_validos
        ),
        registros_con_errores=(
            lectura.perfil.total_registros_con_errores
        ),
        artefactos_generados=tuple(
            sorted(path.name for path in archivos.values())
        ),
    )

    historial = publicar_evento_jsonl(
        evento,
        historial_eventos,
    )

    resumen = _escribir_resumen(
        excel=excel_path,
        lectura=lectura,
        archivos=archivos,
        evento=evento,
        destino=Path(salida) / "resumen-ejecucion.json",
    )

    return ResultadoPipelineRLB(
        lectura=lectura,
        archivos_generados=archivos,
        evento=evento,
        historial_eventos=historial,
        resumen_ejecucion=resumen,
    )