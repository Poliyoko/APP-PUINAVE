"""Prueba integral SPT-001B-P04 del lector Excel del RLB."""

from pathlib import Path

from openpyxl import Workbook

from sgoda.rlb.excel_reader import LectorExcelRLB
from sgoda.rlb.schema_loader import cargar_esquema


def test_lector_excel_perfila_mapea_y_preserva_datos(
    tmp_path: Path,
) -> None:
    """Valida el flujo principal sobre un archivo Excel real temporal."""

    excel_path = tmp_path / "RLB-prueba-integral.xlsx"

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
            "dato conservado",
        ]
    )
    worksheet.append(
        [
            "LEX-0002",
            "",
            "registro sin palabra",
            None,
            None,
        ]
    )

    workbook.save(excel_path)
    workbook.close()

    esquema = cargar_esquema("config/rlb/schema-v1.json")
    resultado = LectorExcelRLB(esquema).leer(excel_path)

    assert resultado.perfil is not None
    assert resultado.perfil.archivo == excel_path.name
    assert resultado.perfil.version_esquema == "1.0.0"
    assert resultado.perfil.total_hojas == 1
    assert resultado.perfil.total_registros == 2
    assert resultado.perfil.total_registros_validos == 1
    assert resultado.perfil.total_registros_con_errores == 1

    perfil_hoja = resultado.perfil.hojas[0]

    assert perfil_hoja.nombre == "Diccionario"
    assert perfil_hoja.fila_encabezado == 1
    assert "Puinave" in perfil_hoja.columnas_reconocidas
    assert "Campo futuro" in perfil_hoja.columnas_desconocidas

    primer_registro = resultado.registros[0]

    assert primer_registro.identificador == "LEX-0001"
    assert primer_registro.palabra_puinave == "AMDA"
    assert primer_registro.traduccion_espanol == "ejemplo"
    assert primer_registro.tema_cultural == "vida cotidiana"

    assert primer_registro.origen is not None
    assert primer_registro.origen.archivo == excel_path.name
    assert primer_registro.origen.hoja == "Diccionario"
    assert primer_registro.origen.fila == 2
    assert primer_registro.origen.version_esquema == "1.0.0"

    assert len(primer_registro.campos_desconocidos) == 1
    assert (
        primer_registro.campos_desconocidos[0].columna_original
        == "Campo futuro"
    )
    assert (
        primer_registro.campos_desconocidos[0].valor
        == "dato conservado"
    )

    assert len(resultado.errores) == 1
    assert resultado.errores[0].hoja == "Diccionario"
    assert resultado.errores[0].fila == 3
    assert (
        "La palabra Puinave es obligatoria."
        in resultado.errores[0].mensajes
    )