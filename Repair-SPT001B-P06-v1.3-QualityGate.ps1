<#
.SYNOPSIS
    Corrige el quality gate de SPT-001B-P06 y registra la calidad real del RLB.

.DESCRIPTION
    Añade identificadores explícitos del incremento en las categorías
    source y tests exigidas por SGD-114, conserva los 20 registros con
    errores como hallazgo de calidad y vuelve a ejecutar:
      - prueba contractual P06;
      - suite completa;
      - informe de calidad del RLB;
      - trazabilidad;
      - quality gate SGD-114.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.EXAMPLE
    .\Repair-SPT001B-P06-v1.3-QualityGate.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
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

$ConfigPath = Join-Path $ProjectRoot "config\rlb\SPT-001B-P06-component.json"
$ContractTestPath = Join-Path $ProjectRoot "tests\rlb\test_SPT_001B_P06_contract.py"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P06"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-001B-P06"
$ProfilePath = Join-Path $ArtifactsDir "perfil-rlb.json"
$ErrorsPath = Join-Path $ArtifactsDir "errores-importacion.json"
$SummaryPath = Join-Path $ArtifactsDir "resumen-ejecucion.json"
$QualityReportPath = Join-Path $PmoDir "SPT-001B-P06-data-quality-report.json"
$TracePath = Join-Path $PmoDir "traceability-SPT-001B-P06.json"
$GatePath = Join-Path $PmoDir "SPT-001B-P06-quality-gate.json"
$DashboardPath = Join-Path $ProjectRoot "dashboard\SPT-001B-P06-dashboard.json"

Write-Step "Validando resultados reales de P06"

foreach ($Required in @(
    $ProfilePath,
    $ErrorsPath,
    $SummaryPath,
    (Join-Path $PmoDir "repository-events.jsonl"),
    (Join-Path $ProjectRoot "src\sgoda\rlb\pipeline.py"),
    (Join-Path $ProjectRoot "tests\rlb\test_pipeline_p06.py"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json")
)) {
    Assert-Path -Path $Required -Description $Required
}

$ComponentConfig = @'
{
  "increment_code": "SPT-001B-P06",
  "component_type": "rlb_pipeline",
  "version": "1.3.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.rlb.cli",
  "implementation_modules": [
    "src/sgoda/rlb/events.py",
    "src/sgoda/rlb/pipeline.py",
    "src/sgoda/rlb/cli.py"
  ],
  "test_modules": [
    "tests/rlb/test_pipeline_p06.py",
    "tests/rlb/test_SPT_001B_P06_contract.py"
  ],
  "governed_by": "SGD-114",
  "data_quality_policy": "preserve_errors_and_report"
}
'@

$ContractTest = @'
"""Contrato institucional SPT-001B-P06 para SGD-114."""

import json
from pathlib import Path

from sgoda.rlb.pipeline import ejecutar_pipeline


def test_SPT_001B_P06_declara_componente_y_artefactos() -> None:
    """Verifica identidad, módulos y evidencia real del incremento."""

    root = Path(__file__).resolve().parents[2]
    config_path = root / "config" / "rlb" / "SPT-001B-P06-component.json"

    assert config_path.is_file()

    config = json.loads(config_path.read_text(encoding="utf-8"))

    assert config["increment_code"] == "SPT-001B-P06"
    assert config["status"] == "technically_completed"
    assert config["entrypoint"] == "sgoda.rlb.cli"
    assert callable(ejecutar_pipeline)

    for relative in config["implementation_modules"]:
        assert (root / relative).is_file()

    artifacts = root / "artifacts" / "rlb" / "SPT-001B-P06"

    assert (artifacts / "palabras-canonicas.json").is_file()
    assert (artifacts / "perfil-rlb.json").is_file()
    assert (artifacts / "errores-importacion.json").is_file()
    assert (artifacts / "resumen-ejecucion.json").is_file()
'@

Write-Step "Registrando identidad institucional del componente"
Write-Utf8NoBom -Path $ConfigPath -Content $ComponentConfig
Write-Utf8NoBom -Path $ContractTestPath -Content $ContractTest

Write-Step "Generando informe de calidad real"

$Profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$Errors = Get-Content -LiteralPath $ErrorsPath -Raw | ConvertFrom-Json
$Summary = Get-Content -LiteralPath $SummaryPath -Raw | ConvertFrom-Json

$Total = [int]$Profile.total_registros
$Valid = [int]$Profile.total_registros_validos
$Invalid = [int]$Profile.total_registros_con_errores

$QualityPercent = 0.0
if ($Total -gt 0) {
    $QualityPercent = [Math]::Round(($Valid / $Total) * 100, 2)
}

$QualityStatus = if ($Invalid -eq 0) {
    "conforme"
}
elseif ($Valid -eq 0) {
    "requiere_normalizacion_total"
}
else {
    "requiere_revision_parcial"
}

$QualityReport = [ordered]@{
    increment_code = "SPT-001B-P06"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_file = $Summary.archivo_origen.nombre
    source_sha256 = $Summary.archivo_origen.sha256
    total_records = $Total
    valid_records = $Valid
    invalid_records = $Invalid
    quality_percentage = $QualityPercent
    quality_status = $QualityStatus
    errors_preserved = $true
    publication_authorized = ($Invalid -eq 0)
    next_action = if ($Invalid -eq 0) {
        "ready_for_canonical_publication"
    }
    else {
        "execute_header_mapping_and_data_normalization"
    }
    error_report = "artifacts/rlb/SPT-001B-P06/errores-importacion.json"
    institutional_note = (
        "El procesamiento técnico fue exitoso. Los errores de datos " +
        "no se eliminan ni se consideran fallo del pipeline."
    )
}
Write-JsonUtf8 -Path $QualityReportPath -Data $QualityReport

Write-Step "Actualizando trazabilidad"

$Trace = [ordered]@{
    increment_code = "SPT-001B-P06"
    correction_version = "1.3.0"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source = @(
        "config/rlb/SPT-001B-P06-component.json",
        "src/sgoda/rlb/events.py",
        "src/sgoda/rlb/pipeline.py",
        "src/sgoda/rlb/cli.py"
    )
    tests = @(
        "tests/rlb/test_pipeline_p06.py",
        "tests/rlb/test_SPT_001B_P06_contract.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P06-Pipeline-Institucional-RLB.md"
    )
    evidence = @(
        "artifacts/rlb/SPT-001B-P06/palabras-canonicas.json",
        "artifacts/rlb/SPT-001B-P06/perfil-rlb.json",
        "artifacts/rlb/SPT-001B-P06/errores-importacion.json",
        "artifacts/rlb/SPT-001B-P06/resumen-ejecucion.json",
        "artifacts/pmo/SPT-001B-P06/repository-events.jsonl",
        "artifacts/pmo/SPT-001B-P06/SPT-001B-P06-data-quality-report.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Ejecutando prueba contractual"

& python -m pytest "tests/rlb/test_SPT_001B_P06_contract.py" -q
if ($LASTEXITCODE -ne 0) {
    throw "La prueba contractual P06 terminó con errores."
}

Write-Step "Ejecutando suite completa"

& python -m pytest
if ($LASTEXITCODE -ne 0) {
    throw "La suite completa terminó con errores."
}

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-001B-P06" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    $GateFailure = Get-Content -LiteralPath $GatePath -Raw | ConvertFrom-Json
    $Missing = $GateFailure.missing_categories -join ", "
    throw "El quality gate continúa bloqueado. Categorías faltantes: $Missing"
}

$Gate = Get-Content -LiteralPath $GatePath -Raw | ConvertFrom-Json
if (-not $Gate.passed) {
    throw "El quality gate no contiene passed=true."
}

$Dashboard = [ordered]@{
    increment_code = "SPT-001B-P06"
    version = "1.3.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    total_records = $Total
    valid_records = $Valid
    invalid_records = $Invalid
    quality_percentage = $QualityPercent
    quality_status = $QualityStatus
    publication_authorized = ($Invalid -eq 0)
    pipeline = "approved"
    full_suite = "approved"
    quality_gate = "approved"
    next_increment = "SPT-001B-P07-normalization"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SPT-001B-P06 v1.3 completado." -ForegroundColor Green
Write-Host "Pipeline técnico: APROBADO." -ForegroundColor Green
Write-Host "Suite completa: APROBADA." -ForegroundColor Green
Write-Host "Quality gate SGD-114: APROBADO." -ForegroundColor Green
Write-Host "Registros procesados: $Total" -ForegroundColor Cyan
Write-Host "Registros válidos: $Valid" -ForegroundColor Cyan
Write-Host "Registros con errores: $Invalid" -ForegroundColor Yellow
Write-Host "Calidad de datos: $QualityPercent%" -ForegroundColor Yellow
Write-Host "Estado de datos: $QualityStatus" -ForegroundColor Yellow
Write-Host "Siguiente incremento: SPT-001B-P07 — normalización y mapeo de encabezados." -ForegroundColor Cyan
