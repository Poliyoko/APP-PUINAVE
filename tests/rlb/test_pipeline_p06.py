"""Pruebas integrales SPT-001B-P06."""

import json
import subprocess
import sys
from pathlib import Path

from openpyxl import Workbook

from sgoda.rlb.pipeline import ejecutar_pipeline


def _crear_excel(tmp_path: Path) -> Path:
    path = tmp_path / "RLB-P06.xlsx"
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Diccionario"
    sheet.append(
        ["ID", "Puinave", "Español", "Campo futuro"]
    )
    sheet.append(
        ["LEX-0001", "AMDA", "ejemplo", "conservar"]
    )
    sheet.append(
        ["LEX-0002", "", "sin palabra", None]
    )
    workbook.save(path)
    workbook.close()
    return path


def test_pipeline_genera_artefactos_evento_y_resumen(
    tmp_path: Path,
) -> None:
    result = ejecutar_pipeline(
        excel=_crear_excel(tmp_path),
        esquema="config/rlb/schema-v1.json",
        salida=tmp_path / "salida",
        historial_eventos=tmp_path / "eventos.jsonl",
    )

    assert result.evento.event_type == "RepositoryImported"
    assert result.evento.total_registros == 2
    assert result.evento.registros_validos == 1
    assert result.evento.registros_con_errores == 1

    assert result.historial_eventos.is_file()
    assert result.resumen_ejecucion.is_file()

    for path in result.archivos_generados.values():
        assert path.is_file()
        assert path.stat().st_size > 0

    summary = json.loads(
        result.resumen_ejecucion.read_text(encoding="utf-8")
    )

    assert summary["incremento"] == "SPT-001B-P06"
    assert len(summary["archivo_origen"]["sha256"]) == 64
    assert summary["resultado"]["total_registros"] == 2
    assert "canonico" in summary["artefactos"]


def test_cli_ejecuta_sin_advertencias(
    tmp_path: Path,
) -> None:
    excel = _crear_excel(tmp_path)
    output = tmp_path / "cli-output"
    events = tmp_path / "cli-events.jsonl"

    process = subprocess.run(
        [
            sys.executable,
            "-m",
            "sgoda.rlb.cli",
            "--excel",
            str(excel),
            "--schema",
            "config/rlb/schema-v1.json",
            "--output",
            str(output),
            "--events",
            str(events),
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    assert process.returncode == 0
    assert "RuntimeWarning" not in process.stderr
    assert "SPT-001B-P06 ejecutado correctamente." in process.stdout
    assert (output / "palabras-canonicas.json").is_file()
    assert (output / "perfil-rlb.json").is_file()
    assert (output / "errores-importacion.json").is_file()
    assert (output / "resumen-ejecucion.json").is_file()
    assert events.is_file()


def test_pipeline_rechaza_excel_inexistente(
    tmp_path: Path,
) -> None:
    try:
        ejecutar_pipeline(
            excel=tmp_path / "inexistente.xlsx",
            esquema="config/rlb/schema-v1.json",
            salida=tmp_path / "salida",
            historial_eventos=tmp_path / "eventos.jsonl",
        )
    except FileNotFoundError as error:
        assert "Excel institucional" in str(error)
    else:
        raise AssertionError(
            "Debía rechazarse un Excel inexistente."
        )