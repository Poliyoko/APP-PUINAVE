"""Pruebas SPT-001B-P05 del exportador institucional RLB."""

import json
from pathlib import Path

from openpyxl import Workbook

from sgoda.rlb.excel_reader import (
    LectorExcelRLB,
    ResultadoLecturaRLB,
)
from sgoda.rlb.exporter import exportar_resultado
from sgoda.rlb.schema_loader import cargar_esquema


def _crear_excel(tmp_path: Path) -> Path:
    ruta = tmp_path / "RLB-exportacion.xlsx"

    workbook = Workbook()
    worksheet = workbook.active
    worksheet.title = "Diccionario"

    worksheet.append(
        [
            "ID",
            "Puinave",
            "Español",
            "Tema cultural",
            "Campo futuro",
        ]
    )
    worksheet.append(
        [
            "LEX-0001",
            "AMDA",
            "ejemplo",
            "vida cotidiana",
            "dato adicional",
        ]
    )
    worksheet.append(
        [
            "LEX-0002",
            "",
            "registro inválido",
            None,
            None,
        ]
    )

    workbook.save(ruta)
    workbook.close()

    return ruta


def test_exporta_tres_artefactos_json(
    tmp_path: Path,
) -> None:
    """Verifica la generación de los tres artefactos institucionales."""

    esquema = cargar_esquema("config/rlb/schema-v1.json")
    lectura = LectorExcelRLB(esquema).leer(
        _crear_excel(tmp_path)
    )

    archivos = exportar_resultado(
        lectura,
        tmp_path / "salida",
    )

    assert set(archivos) == {
        "canonico",
        "perfil",
        "errores",
    }

    for ruta in archivos.values():
        assert ruta.is_file()
        assert ruta.stat().st_size > 0

    canonico = json.loads(
        archivos["canonico"].read_text(encoding="utf-8")
    )
    perfil = json.loads(
        archivos["perfil"].read_text(encoding="utf-8")
    )
    errores = json.loads(
        archivos["errores"].read_text(encoding="utf-8")
    )

    assert canonico["metadata"]["sistema"] == "SGODA-PUINAVE"
    assert canonico["metadata"]["entregable"] == "SPT-001B-P05"
    assert canonico["metadata"]["version_esquema"] == "1.0.0"
    assert canonico["metadata"]["total_registros"] == 2
    assert len(canonico["registros"]) == 2

    assert perfil["archivo"] == "RLB-exportacion.xlsx"
    assert perfil["total_registros_validos"] == 1
    assert perfil["total_registros_con_errores"] == 1

    assert errores["metadata"]["total"] == 1
    assert errores["errores"][0]["fila"] == 3


def test_rechaza_resultado_sin_perfil(
    tmp_path: Path,
) -> None:
    """Evita exportar resultados incompletos o no perfilados."""

    resultado = ResultadoLecturaRLB()

    try:
        exportar_resultado(
            resultado,
            tmp_path / "salida",
        )
    except ValueError as error:
        assert "no contiene perfil institucional" in str(error)
    else:
        raise AssertionError(
            "Debía rechazarse un resultado sin perfil."
        )