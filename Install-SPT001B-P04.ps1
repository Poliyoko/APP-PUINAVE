<#
.SYNOPSIS
    Instala y valida SPT-001B-P04 para SGODA-PUINAVE.

.DESCRIPTION
    Incorpora una prueba automatizada integral del lector Excel del
    Repositorio Léxico Base. La prueba crea un Excel temporal real,
    verifica detección de encabezados, mapeo de campos, preservación
    de columnas desconocidas, trazabilidad y registro de errores.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.
    Por defecto usa la carpeta actual.

.PARAMETER Force
    Sobrescribe los archivos de P04 si ya existen.

.PARAMETER SkipFullSuite
    Ejecuta solo la prueba específica de P04 y omite la suite completa.

.EXAMPLE
    .\Install-SPT001B-P04.ps1

.EXAMPLE
    .\Install-SPT001B-P04.ps1 -Force
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Force,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content,
        [switch]$Overwrite
    )

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    if ((Test-Path -LiteralPath $Path) -and -not $Overwrite) {
        Write-Host "Se conserva archivo existente: $Path" -ForegroundColor Yellow
        return
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear el archivo: $Path"
    }

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado correctamente: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$RlbDir = Join-Path $SrcRoot "sgoda\rlb"
$TestsDir = Join-Path $ProjectRoot "tests\rlb"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-001"
$TestPath = Join-Path $TestsDir "test_excel_reader.py"
$DocPath = Join-Path $DocsDir "SPT-001B-P04-Prueba-Lector-Excel.md"

Write-Step "Validando línea base P01-P03"

Assert-Path -Path (Join-Path $RlbDir "schema.py") -Description "schema.py"
Assert-Path -Path (Join-Path $RlbDir "models.py") -Description "models.py"
Assert-Path -Path (Join-Path $RlbDir "schema_loader.py") -Description "schema_loader.py"
Assert-Path -Path (Join-Path $RlbDir "profile_models.py") -Description "profile_models.py"
Assert-Path -Path (Join-Path $RlbDir "excel_reader.py") -Description "excel_reader.py"
Assert-Path -Path (Join-Path $ProjectRoot "config\rlb\schema-v1.json") -Description "schema-v1.json"
Assert-Path -Path (Join-Path $ProjectRoot "pytest.ini") -Description "pytest.ini"

$env:PYTHONPATH = $SrcRoot

& python --version
if ($LASTEXITCODE -ne 0) {
    throw "Python no está disponible."
}

& python -c "import openpyxl; print('openpyxl', openpyxl.__version__)"
if ($LASTEXITCODE -ne 0) {
    throw "openpyxl no está disponible en el entorno virtual."
}

$TestContent = @'
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
'@

$DocContent = @'
# SPT-001B-P04 — Prueba integral del lector Excel

## Estado

Implementado y pendiente de cierre institucional.

## Objetivo

Demostrar mediante una prueba automatizada que el lector del Repositorio
Léxico Base procesa un archivo Excel real y conserva la integridad y la
trazabilidad de sus datos.

## Capacidades verificadas

- creación y lectura de un archivo `.xlsx`;
- detección de la hoja `Diccionario`;
- identificación de la fila de encabezados;
- mapeo de columnas mediante el esquema RLB v1.0.0;
- clasificación de columnas conocidas y desconocidas;
- preservación de campos futuros;
- conservación de archivo, hoja y fila de origen;
- validación de la palabra Puinave obligatoria;
- conservación de registros con errores para revisión;
- ausencia de regresiones en la suite general.

## Evidencia automatizada

`tests/rlb/test_excel_reader.py`

## Ejecución

```powershell
$env:PYTHONPATH = (Join-Path (Get-Location).Path "src")
python -m pytest tests/rlb/test_excel_reader.py -q
python -m pytest
```

## Resultado esperado

La prueba específica debe aprobarse y la suite completa debe aumentar
en una prueba respecto de la línea base de 56 pruebas.

## Relación institucional

- Sprint: SPT-001B
- Paquete: SPT-001B-P04
- Componente: Repositorio Léxico Base
- ADR relacionado: ADR-009
- Política relacionada: SGD-110
- Norma documental relacionada: SGD-111
'@

Write-Step "Instalando prueba automatizada P04"
Write-Utf8NoBom `
    -Path $TestPath `
    -Content $TestContent `
    -Overwrite:$Force

Write-Step "Instalando documentación P04"
Write-Utf8NoBom `
    -Path $DocPath `
    -Content $DocContent `
    -Overwrite:$Force

Write-Step "Ejecutando prueba específica P04"

& python -m pytest "tests/rlb/test_excel_reader.py" -q
if ($LASTEXITCODE -ne 0) {
    throw "La prueba específica SPT-001B-P04 terminó con errores."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest
    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}
else {
    Write-Host "Suite completa omitida por parámetro." -ForegroundColor Yellow
}

Write-Step "Resultado"

Write-Host "SPT-001B-P04 instalado y validado correctamente." -ForegroundColor Green
Write-Host "Prueba: $TestPath" -ForegroundColor Green
Write-Host "Documento: $DocPath" -ForegroundColor Green
Write-Host "Siguiente incremento: SPT-001B-P05 (exportación JSON y perfil)." -ForegroundColor Cyan
