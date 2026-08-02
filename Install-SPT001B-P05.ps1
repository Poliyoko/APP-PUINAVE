<#
.SYNOPSIS
    Instala y valida SPT-001B-P05 para SGODA-PUINAVE.

.DESCRIPTION
    Implementa la exportación institucional del resultado del lector RLB:
      - palabras-canonicas.json
      - perfil-rlb.json
      - errores-importacion.json

    Incorpora pruebas automatizadas y documentación técnica.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.
    Por defecto usa la carpeta actual.

.PARAMETER Force
    Sobrescribe los archivos de P05 si ya existen.

.PARAMETER SkipFullSuite
    Ejecuta solo las pruebas específicas de P05.

.EXAMPLE
    .\Install-SPT001B-P05.ps1

.EXAMPLE
    .\Install-SPT001B-P05.ps1 -Force
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

$ExporterPath = Join-Path $RlbDir "exporter.py"
$TestPath = Join-Path $TestsDir "test_exporter.py"
$DocPath = Join-Path $DocsDir "SPT-001B-P05-Exportacion-JSON-Perfil.md"

Write-Step "Validando línea base P01-P04"

Assert-Path -Path (Join-Path $RlbDir "schema.py") -Description "schema.py"
Assert-Path -Path (Join-Path $RlbDir "models.py") -Description "models.py"
Assert-Path -Path (Join-Path $RlbDir "schema_loader.py") -Description "schema_loader.py"
Assert-Path -Path (Join-Path $RlbDir "profile_models.py") -Description "profile_models.py"
Assert-Path -Path (Join-Path $RlbDir "excel_reader.py") -Description "excel_reader.py"
Assert-Path -Path (Join-Path $TestsDir "test_excel_reader.py") -Description "la prueba P04"
Assert-Path -Path (Join-Path $ProjectRoot "config\rlb\schema-v1.json") -Description "schema-v1.json"
Assert-Path -Path (Join-Path $ProjectRoot "pytest.ini") -Description "pytest.ini"

$env:PYTHONPATH = $SrcRoot

& python --version
if ($LASTEXITCODE -ne 0) {
    throw "Python no está disponible."
}

$ExporterContent = @'
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
'@

$TestContent = @'
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
'@

$DocContent = @'
# SPT-001B-P05 — Exportación JSON canónica y perfil técnico

## Estado

Implementado y pendiente de cierre institucional.

## Objetivo

Transformar el resultado del lector del Repositorio Léxico Base en tres
artefactos JSON estructurados, trazables y reutilizables por los demás
componentes del ecosistema SGODA-PUINAVE.

## Artefactos generados

1. `palabras-canonicas.json`
   - metadatos institucionales;
   - versión del esquema;
   - archivo de origen;
   - cantidad de hojas y registros;
   - registros léxicos completos;
   - campos desconocidos preservados;
   - trazabilidad por archivo, hoja y fila.

2. `perfil-rlb.json`
   - perfil completo del archivo;
   - hojas;
   - encabezados;
   - columnas reconocidas;
   - columnas desconocidas;
   - columnas vacías;
   - registros válidos y con errores.

3. `errores-importacion.json`
   - errores de validación;
   - hoja y fila;
   - mensajes de incumplimiento;
   - total de incidencias.

## Principios de gobierno aplicados

- Los registros con errores no son descartados.
- Los campos nuevos no son eliminados.
- Todos los archivos se generan en UTF-8.
- El exportador rechaza resultados sin perfil institucional.
- Los artefactos son aptos para consumo posterior por FastAPI,
  PostgreSQL, n8n, AI Hub, portal web, Flutter y PMO Digital.

## Evidencias automatizadas

`tests/rlb/test_exporter.py`

## Ejecución

```powershell
$env:PYTHONPATH = (Join-Path (Get-Location).Path "src")
python -m pytest tests/rlb/test_exporter.py -q
python -m pytest
```

## Relación institucional

- Sprint: SPT-001B
- Paquete: SPT-001B-P05
- Componente: Repositorio Léxico Base
- ADR relacionado: ADR-009
- Política relacionada: SGD-110
- Norma documental relacionada: SGD-111
- Norma de evidencias relacionada: SGD-113
'@

Write-Step "Instalando exportador P05"
Write-Utf8NoBom `
    -Path $ExporterPath `
    -Content $ExporterContent `
    -Overwrite:$Force

Write-Step "Instalando pruebas P05"
Write-Utf8NoBom `
    -Path $TestPath `
    -Content $TestContent `
    -Overwrite:$Force

Write-Step "Instalando documentación P05"
Write-Utf8NoBom `
    -Path $DocPath `
    -Content $DocContent `
    -Overwrite:$Force

Write-Step "Validando importación del exportador"

& python -c "from sgoda.rlb.exporter import exportar_resultado; print(exportar_resultado.__name__)"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación del exportador P05."
}

Write-Step "Ejecutando pruebas específicas P05"

& python -m pytest "tests/rlb/test_exporter.py" -q
if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPT-001B-P05 terminaron con errores."
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

Write-Host "SPT-001B-P05 instalado y validado correctamente." -ForegroundColor Green
Write-Host "Exportador: $ExporterPath" -ForegroundColor Green
Write-Host "Pruebas: $TestPath" -ForegroundColor Green
Write-Host "Documento: $DocPath" -ForegroundColor Green
Write-Host "Siguiente incremento: SPT-001B-P06 (pipeline y CLI sobre el Excel oficial)." -ForegroundColor Cyan
