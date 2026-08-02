<#
.SYNOPSIS
    Implementa SPT-001B-P07 — Normalización y mapeo de encabezados.

.DESCRIPTION
    Analiza encabezados reales del Excel oficial, genera equivalencias,
    normaliza nombres sin modificar el archivo original, reprocesa el RLB
    y deja pruebas, evidencias, trazabilidad, dashboard y quality gate.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER OfficialExcelPath
    Ruta absoluta o relativa al Excel oficial. Si se omite, busca el
    primer archivo .xlsx en la raíz del repositorio.

.EXAMPLE
    .\Install-SPT001B-P07-Institutional.ps1 `
        -OfficialExcelPath ".\Repositorio LExico Base (Excel)-1.xlsx"
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$OfficialExcelPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param([string]$Path, [string]$Description)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Resolve-ProjectPath {
    param([string]$Root, [string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath(
        (Join-Path $Root $PathValue)
    )
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear: $Path"
    }

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 30

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$env:PYTHONPATH = $SrcRoot

$RlbDir = Join-Path $SrcRoot "sgoda\rlb"
$TestsDir = Join-Path $ProjectRoot "tests\rlb"
$ConfigDir = Join-Path $ProjectRoot "config\rlb"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-001"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P07"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-001B-P07"
$DashboardDir = Join-Path $ProjectRoot "dashboard"

$NormalizerPath = Join-Path $RlbDir "header_normalizer.py"
$TestPath = Join-Path $TestsDir "test_SPT_001B_P07_header_normalizer.py"
$ConfigPath = Join-Path $ConfigDir "SPT-001B-P07-header-mapping.json"
$ComponentPath = Join-Path $ConfigDir "SPT-001B-P07-component.json"
$DocPath = Join-Path $DocsDir "SPT-001B-P07-Normalizacion-Encabezados.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT001B-P07.ps1"
$TracePath = Join-Path $PmoDir "traceability-SPT-001B-P07.json"
$ManifestPath = Join-Path $PmoDir "implementation-evidence.json"
$DashboardPath = Join-Path $DashboardDir "SPT-001B-P07-dashboard.json"
$GatePath = Join-Path $PmoDir "SPT-001B-P07-quality-gate.json"

Write-Step "Validando línea base P06"

foreach ($Required in @(
    "src\sgoda\rlb\schema.py",
    "src\sgoda\rlb\schema_loader.py",
    "src\sgoda\rlb\excel_reader.py",
    "src\sgoda\rlb\exporter.py",
    "src\sgoda\rlb\pipeline.py",
    "tests\rlb\test_pipeline_p06.py",
    "config\rlb\schema-v1.json",
    "config\governance\sgd-114-policy.json",
    "artifacts\rlb\SPT-001B-P06\perfil-rlb.json",
    "artifacts\rlb\SPT-001B-P06\errores-importacion.json"
)) {
    Assert-Path `
        -Path (Join-Path $ProjectRoot $Required) `
        -Description $Required
}

& python --version
if ($LASTEXITCODE -ne 0) {
    throw "Python no está disponible."
}

Write-Step "Resolviendo Excel oficial"

if (-not [string]::IsNullOrWhiteSpace($OfficialExcelPath)) {
    $OfficialExcelPath = Resolve-ProjectPath `
        -Root $ProjectRoot `
        -PathValue $OfficialExcelPath
}
else {
    $Candidates = @(
        Get-ChildItem `
            -LiteralPath $ProjectRoot `
            -File `
            -Filter "*.xlsx" |
        Where-Object { $_.Name -notlike "~`$*" } |
        Sort-Object Name
    )

    if ($Candidates.Count -eq 0) {
        throw "No se encontró ningún archivo .xlsx en la raíz."
    }

    $OfficialExcelPath = $Candidates[0].FullName
}

Assert-Path -Path $OfficialExcelPath -Description "el Excel oficial"

Write-Host "Excel seleccionado: $OfficialExcelPath" -ForegroundColor Green

$NormalizerContent = @'
"""SPT-001B-P07: normalización auditable de encabezados del RLB."""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from dataclasses import asdict, dataclass
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

from openpyxl import load_workbook

from .excel_reader import LectorExcelRLB
from .exporter import exportar_resultado
from .schema_loader import cargar_esquema


@dataclass(frozen=True, slots=True)
class SugerenciaEncabezado:
    original: str
    normalizado: str
    campo_canonico: str | None
    alias_recomendado: str | None
    confianza: float
    decision: str


def normalizar_texto(value: str) -> str:
    """Normaliza tildes, espacios, signos y mayúsculas."""

    decomposed = unicodedata.normalize("NFKD", value)
    without_accents = "".join(
        char for char in decomposed
        if not unicodedata.combining(char)
    )
    lowered = without_accents.casefold()
    cleaned = re.sub(r"[^a-z0-9]+", " ", lowered)
    return " ".join(cleaned.split())


def _tokens(value: str) -> set[str]:
    return set(normalizar_texto(value).split())


def similitud(a: str, b: str) -> float:
    """Combina similitud secuencial y coincidencia de tokens."""

    na = normalizar_texto(a)
    nb = normalizar_texto(b)

    if not na or not nb:
        return 0.0

    sequence = SequenceMatcher(None, na, nb).ratio()

    ta = _tokens(na)
    tb = _tokens(nb)

    token_score = 0.0
    if ta or tb:
        token_score = len(ta & tb) / len(ta | tb)

    contains = 1.0 if na in nb or nb in na else 0.0

    return round(
        max(
            sequence,
            (sequence * 0.65) + (token_score * 0.35),
            contains * 0.92,
        ),
        4,
    )


def leer_encabezados_excel(
    excel: str | Path,
    max_rows: int = 20,
) -> dict[str, Any]:
    """Detecta la mejor fila de encabezados por hoja."""

    path = Path(excel)

    if not path.is_file():
        raise FileNotFoundError(
            f"No se encontró el Excel: {path}"
        )

    workbook = load_workbook(
        path,
        read_only=True,
        data_only=True,
    )

    try:
        result: dict[str, Any] = {}

        for sheet_name in workbook.sheetnames:
            sheet = workbook[sheet_name]
            best_row = None
            best_values: list[str] = []
            best_score = -1

            limit = min(sheet.max_row, max_rows)

            for row_number, values in enumerate(
                sheet.iter_rows(
                    min_row=1,
                    max_row=limit,
                    values_only=True,
                ),
                start=1,
            ):
                headers = [
                    str(value).strip()
                    for value in values
                    if value is not None
                    and str(value).strip()
                ]

                if not headers:
                    continue

                score = len(headers)

                terms = " ".join(
                    normalizar_texto(value)
                    for value in headers
                )

                for keyword in (
                    "puinave",
                    "espanol",
                    "ingles",
                    "palabra",
                    "traduccion",
                    "significado",
                    "id",
                ):
                    if keyword in terms:
                        score += 5

                if score > best_score:
                    best_score = score
                    best_row = row_number
                    best_values = headers

            result[sheet_name] = {
                "header_row": best_row,
                "headers": best_values,
            }

        return result
    finally:
        workbook.close()


def sugerir_mapeo(
    headers: list[str],
    schema_path: str | Path,
    threshold: float = 0.55,
) -> list[SugerenciaEncabezado]:
    """Genera sugerencias contra nombres canónicos y aliases."""

    schema = cargar_esquema(schema_path)
    suggestions: list[SugerenciaEncabezado] = []

    candidates: list[tuple[str, str]] = []

    for field in schema.campos:
        candidates.append(
            (field.nombre_canonico, field.nombre_canonico)
        )
        for alias in field.aliases:
            candidates.append(
                (field.nombre_canonico, alias)
            )

    for header in headers:
        best_field = None
        best_alias = None
        best_score = 0.0

        for field_name, alias in candidates:
            score = similitud(header, alias)

            if score > best_score:
                best_field = field_name
                best_alias = alias
                best_score = score

        if best_score >= 0.90:
            decision = "automatico_alta_confianza"
        elif best_score >= threshold:
            decision = "propuesto_para_revision"
        else:
            decision = "sin_correspondencia"

        suggestions.append(
            SugerenciaEncabezado(
                original=header,
                normalizado=normalizar_texto(header),
                campo_canonico=(
                    best_field
                    if best_score >= threshold
                    else None
                ),
                alias_recomendado=(
                    best_alias
                    if best_score >= threshold
                    else None
                ),
                confianza=best_score,
                decision=decision,
            )
        )

    return suggestions


def construir_aliases_aprobados(
    suggestions: list[SugerenciaEncabezado],
    minimum_confidence: float = 0.90,
) -> dict[str, str]:
    """Acepta únicamente equivalencias de alta confianza."""

    return {
        item.original: item.alias_recomendado
        for item in suggestions
        if item.confianza >= minimum_confidence
        and item.alias_recomendado
    }


def extender_esquema_temporal(
    schema_path: str | Path,
    output_path: str | Path,
    approved_aliases: dict[str, str],
) -> Path:
    """Añade encabezados reales como aliases sin modificar el original."""

    source = Path(schema_path)
    target = Path(output_path)

    data = json.loads(
        source.read_text(encoding="utf-8")
    )

    fields = data.get("fields", [])

    canonical_by_alias: dict[str, str] = {}

    for field in fields:
        canonical = str(field["name"])
        canonical_by_alias[normalizar_texto(canonical)] = canonical

        for alias in field.get("aliases", []):
            canonical_by_alias[
                normalizar_texto(str(alias))
            ] = canonical

    for original, recommended_alias in approved_aliases.items():
        canonical = canonical_by_alias.get(
            normalizar_texto(recommended_alias)
        )

        if canonical is None:
            continue

        for field in fields:
            if field["name"] != canonical:
                continue

            aliases = field.setdefault("aliases", [])

            if original not in aliases:
                aliases.append(original)

            break

    data["version"] = (
        str(data.get("version", "1.0.0"))
        + "-p07-normalized"
    )
    data["generated_by"] = "SPT-001B-P07"

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            data,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    return target


def ejecutar_normalizacion(
    *,
    excel: str | Path,
    schema: str | Path,
    output_dir: str | Path,
) -> dict[str, Any]:
    """Ejecuta diagnóstico, esquema temporal y reprocesamiento."""

    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    detected = leer_encabezados_excel(excel)

    all_headers: list[str] = []
    for sheet_data in detected.values():
        all_headers.extend(sheet_data["headers"])

    suggestions = sugerir_mapeo(
        all_headers,
        schema,
    )

    approved = construir_aliases_aprobados(suggestions)

    mapping_path = output / "header-mapping-analysis.json"
    mapping_path.write_text(
        json.dumps(
            {
                "increment": "SPT-001B-P07",
                "detected": detected,
                "suggestions": [
                    asdict(item)
                    for item in suggestions
                ],
                "approved_aliases": approved,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    normalized_schema = extender_esquema_temporal(
        schema,
        output / "schema-p07-normalized.json",
        approved,
    )

    contract = cargar_esquema(normalized_schema)
    reading = LectorExcelRLB(contract).leer(excel)

    artifacts = exportar_resultado(
        reading,
        output / "reprocessed",
    )

    if reading.perfil is None:
        raise RuntimeError(
            "No se generó perfil después de normalizar."
        )

    result = {
        "mapping_analysis": mapping_path,
        "normalized_schema": normalized_schema,
        "artifacts": artifacts,
        "profile": reading.perfil,
    }

    summary_path = output / "normalization-summary.json"
    summary_path.write_text(
        json.dumps(
            {
                "increment": "SPT-001B-P07",
                "total_headers": len(all_headers),
                "approved_aliases": len(approved),
                "total_records": reading.perfil.total_registros,
                "valid_records": (
                    reading.perfil.total_registros_validos
                ),
                "invalid_records": (
                    reading.perfil.total_registros_con_errores
                ),
                "mapping_analysis": str(mapping_path),
                "normalized_schema": str(normalized_schema),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    result["summary"] = summary_path
    return result


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Analiza y normaliza encabezados del RLB oficial."
        )
    )
    parser.add_argument("--excel", required=True)
    parser.add_argument(
        "--schema",
        default="config/rlb/schema-v1.json",
    )
    parser.add_argument(
        "--output",
        default="artifacts/rlb/SPT-001B-P07",
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()

    result = ejecutar_normalizacion(
        excel=args.excel,
        schema=args.schema,
        output_dir=args.output,
    )

    profile = result["profile"]

    print("SPT-001B-P07 ejecutado correctamente.")
    print(f"Registros: {profile.total_registros}")
    print(f"Válidos: {profile.total_registros_validos}")
    print(
        "Con errores: "
        f"{profile.total_registros_con_errores}"
    )
    print(f"Resumen: {result['summary']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$TestContent = @'
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
'@

$MappingConfig = @'
{
  "increment_code": "SPT-001B-P07",
  "version": "1.0.0",
  "strategy": "normalized_similarity_with_high_confidence_auto_approval",
  "automatic_threshold": 0.90,
  "review_threshold": 0.55,
  "preserve_original_excel": true,
  "modify_original_schema": false,
  "output_schema": "artifacts/rlb/SPT-001B-P07/schema-p07-normalized.json",
  "manual_review_required_below": 0.90
}
'@

$ComponentConfig = @'
{
  "increment_code": "SPT-001B-P07",
  "component_type": "rlb_header_normalization",
  "version": "1.0.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.rlb.header_normalizer",
  "source": [
    "src/sgoda/rlb/header_normalizer.py"
  ],
  "tests": [
    "tests/rlb/test_SPT_001B_P07_header_normalizer.py"
  ],
  "governed_by": "SGD-114"
}
'@

$DocContent = @'
# SPT-001B-P07 — Normalización y mapeo de encabezados

## Objetivo

Analizar los encabezados reales del Excel oficial, compararlos con los
19 campos del esquema institucional y generar equivalencias auditables
sin modificar el archivo original.

## Principios

- El Excel original permanece intacto.
- El esquema oficial no se modifica directamente.
- Solo se aplican automáticamente equivalencias con confianza igual o
  superior a 0,90.
- Las sugerencias inferiores quedan pendientes de revisión.
- Los errores residuales se conservan.
- Cada reprocesamiento genera perfil y reporte independientes.

## Artefactos

- `header-mapping-analysis.json`
- `schema-p07-normalized.json`
- `normalization-summary.json`
- `reprocessed/palabras-canonicas.json`
- `reprocessed/perfil-rlb.json`
- `reprocessed/errores-importacion.json`

## Resultado esperado

El incremento debe demostrar cuántos de los 20 registros pasan a estado
válido mediante normalización automática y cuáles requieren revisión
manual o ajustes adicionales del esquema.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [string]$ExcelPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

if ([string]::IsNullOrWhiteSpace($ExcelPath)) {
    $Excel = Get-ChildItem `
        -LiteralPath $Root `
        -File `
        -Filter "*.xlsx" |
        Where-Object { $_.Name -notlike "~`$*" } |
        Sort-Object Name |
        Select-Object -First 1

    if ($null -eq $Excel) {
        throw "No se encontró ningún Excel en la raíz."
    }

    $ExcelPath = $Excel.FullName
}
elseif (-not [System.IO.Path]::IsPathRooted($ExcelPath)) {
    $ExcelPath = [System.IO.Path]::GetFullPath(
        (Join-Path $Root $ExcelPath)
    )
}

python -m sgoda.rlb.header_normalizer `
    --excel "$ExcelPath" `
    --schema "config/rlb/schema-v1.json" `
    --output "artifacts/rlb/SPT-001B-P07"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-001B-P07 terminó con errores."
}
'@

Write-Step "Instalando componentes P07"

Write-Utf8NoBom -Path $NormalizerPath -Content $NormalizerContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $ConfigPath -Content $MappingConfig
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentConfig
Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencias iniciales"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Manifest = [ordered]@{
    increment_code = "SPT-001B-P07"
    version = "1.0.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    components = @(
        "src/sgoda/rlb/header_normalizer.py",
        "tests/rlb/test_SPT_001B_P07_header_normalizer.py",
        "config/rlb/SPT-001B-P07-header-mapping.json",
        "config/rlb/SPT-001B-P07-component.json",
        "docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P07-Normalizacion-Encabezados.md",
        "scripts/Invoke-SPT001B-P07.ps1"
    )
}
Write-JsonUtf8 -Path $ManifestPath -Data $Manifest

$Trace = [ordered]@{
    increment_code = "SPT-001B-P07"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/rlb/header_normalizer.py",
        "config/rlb/SPT-001B-P07-component.json"
    )
    tests = @(
        "tests/rlb/test_SPT_001B_P07_header_normalizer.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P07-Normalizacion-Encabezados.md"
    )
    evidence = @(
        "artifacts/pmo/SPT-001B-P07/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando importación"

& python -c "from sgoda.rlb.header_normalizer import ejecutar_normalizacion, normalizar_texto; print(ejecutar_normalizacion.__name__, normalizar_texto('Traducción Español'))"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de P07."
}

Write-Step "Ejecutando pruebas específicas P07"

& python -m pytest `
    "tests/rlb/test_SPT_001B_P07_header_normalizer.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas P07 terminaron con errores."
}

Write-Step "Ejecutando suite completa"

& python -m pytest

if ($LASTEXITCODE -ne 0) {
    throw "La suite completa terminó con errores."
}

Write-Step "Procesando Excel oficial con P07"

& python -m sgoda.rlb.header_normalizer `
    --excel "$OfficialExcelPath" `
    --schema "config/rlb/schema-v1.json" `
    --output "artifacts/rlb/SPT-001B-P07"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la normalización del Excel oficial."
}

foreach ($Artifact in @(
    "header-mapping-analysis.json",
    "schema-p07-normalized.json",
    "normalization-summary.json",
    "reprocessed\palabras-canonicas.json",
    "reprocessed\perfil-rlb.json",
    "reprocessed\errores-importacion.json"
)) {
    Assert-Path `
        -Path (Join-Path $ArtifactsDir $Artifact) `
        -Description $Artifact
}

$Summary = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "normalization-summary.json") `
    -Raw |
    ConvertFrom-Json

$OriginalProfile = Get-Content `
    -LiteralPath (Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P06\perfil-rlb.json") `
    -Raw |
    ConvertFrom-Json

$Dashboard = [ordered]@{
    increment_code = "SPT-001B-P07"
    version = "1.0.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    official_excel = $OfficialExcelPath
    baseline_valid_records = $OriginalProfile.total_registros_validos
    baseline_invalid_records = $OriginalProfile.total_registros_con_errores
    approved_aliases = $Summary.approved_aliases
    reprocessed_records = $Summary.total_records
    valid_records_after_normalization = $Summary.valid_records
    invalid_records_after_normalization = $Summary.invalid_records
    improvement = (
        [int]$Summary.valid_records -
        [int]$OriginalProfile.total_registros_validos
    )
    tests = "approved"
    quality_gate = "pending"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

$Trace.evidence = @(
    "artifacts/pmo/SPT-001B-P07/implementation-evidence.json",
    "artifacts/rlb/SPT-001B-P07/header-mapping-analysis.json",
    "artifacts/rlb/SPT-001B-P07/schema-p07-normalized.json",
    "artifacts/rlb/SPT-001B-P07/normalization-summary.json",
    "dashboard/SPT-001B-P07-dashboard.json"
)
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-001B-P07" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    $Failure = Get-Content -LiteralPath $GatePath -Raw |
        ConvertFrom-Json
    $Missing = $Failure.missing_categories -join ", "
    throw "Quality gate P07 no aprobado. Faltan: $Missing"
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El quality gate P07 no contiene passed=true."
}

$Dashboard.quality_gate = "approved"
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SPT-001B-P07 implementado y validado." -ForegroundColor Green
Write-Host "Pruebas específicas esperadas: 4 aprobadas." -ForegroundColor Cyan
Write-Host "Suite total esperada desde 69: 73 pruebas." -ForegroundColor Cyan
Write-Host "Quality gate SGD-114: APROBADO." -ForegroundColor Green
Write-Host "Registros válidos antes: $($OriginalProfile.total_registros_validos)" -ForegroundColor Yellow
Write-Host "Registros válidos después: $($Summary.valid_records)" -ForegroundColor Cyan
Write-Host "Registros con errores después: $($Summary.invalid_records)" -ForegroundColor Yellow
Write-Host "Aliases aprobados: $($Summary.approved_aliases)" -ForegroundColor Cyan
Write-Host "Análisis: $ArtifactsDir\header-mapping-analysis.json" -ForegroundColor Cyan
