"""Pruebas SPT-001B-P07 de normalización de encabezados."""

import json
from pathlib import Path

from openpyxl import Workbook

from sgoda.rlb.header_normalizer import (
    construir_aliases_aprobados,
    ejecutar_normalizacion,
    normalizar_texto,
    similitud,
    sugerir_mapeo,
)


def test_SPT_001B_P07_normaliza_tildes_y_signos() -> None:
    assert normalizar_texto("  Traducción—Español  ") == (
        "traduccion espanol"
    )
    assert normalizar_texto("PALABRA_PUINAVE") == (
        "palabra puinave"
    )


def test_SPT_001B_P07_detecta_equivalencia_puinave() -> None:
    suggestions = sugerir_mapeo(
        ["Palabra en Puinave", "Traducción al español"],
        "config/rlb/schema-v1.json",
        threshold=0.40,
    )

    assert suggestions[0].campo_canonico == "palabra_puinave"
    assert suggestions[0].confianza >= 0.40


def test_SPT_001B_P07_solo_aprueba_alta_confianza() -> None:
    suggestions = sugerir_mapeo(
        ["Puinave", "Columna desconocida"],
        "config/rlb/schema-v1.json",
    )

    approved = construir_aliases_aprobados(suggestions)

    assert "Puinave" in approved
    assert "Columna desconocida" not in approved


def test_SPT_001B_P07_reprocesa_excel_sin_modificar_original(
    tmp_path: Path,
) -> None:
    excel = tmp_path / "RLB-P07.xlsx"

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Diccionario"
    sheet.append(
        ["ID", "Palabra en Puinave", "Español"]
    )
    sheet.append(
        ["LEX-0001", "AMDA", "ejemplo"]
    )
    workbook.save(excel)
    workbook.close()

    before = excel.read_bytes()

    result = ejecutar_normalizacion(
        excel=excel,
        schema="config/rlb/schema-v1.json",
        output_dir=tmp_path / "salida",
    )

    assert excel.read_bytes() == before
    assert result["summary"].is_file()
    assert result["normalized_schema"].is_file()
    assert result["mapping_analysis"].is_file()

    summary = json.loads(
        result["summary"].read_text(encoding="utf-8")
    )

    assert summary["total_records"] == 1
    assert summary["valid_records"] == 1