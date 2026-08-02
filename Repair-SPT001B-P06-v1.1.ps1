<#
.SYNOPSIS
    Corrige SPT-001B-P06 y restaura la API pública de sgoda.rlb.

.DESCRIPTION
    Soluciona el ImportError:
      cannot import name 'CampoEsquema' from 'sgoda.rlb'

    Restaura las exportaciones públicas de SPT-001A/P01-P06 sin
    importar anticipadamente el módulo CLI. Luego ejecuta:
      - validación de importaciones;
      - pruebas específicas P06;
      - suite completa;
      - procesamiento del Excel oficial;
      - quality gate SGD-114;
      - actualización de evidencia y dashboard.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER OfficialExcelPath
    Ruta del Excel oficial. Si se omite, busca el primer .xlsx en la raíz.

.PARAMETER SkipOfficialRun
    Omite el procesamiento del Excel oficial.

.EXAMPLE
    .\Repair-SPT001B-P06-v1.1.ps1 `
        -OfficialExcelPath ".\Repositorio LExico Base (Excel)-1.xlsx"
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$OfficialExcelPath = "",
    [switch]$SkipOfficialRun
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

    Write-Host "Corregido: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 20

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$RlbDir = Join-Path $SrcRoot "sgoda\rlb"
$InitPath = Join-Path $RlbDir "__init__.py"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-001B-P06"
$DashboardPath = Join-Path $ProjectRoot "dashboard\SPT-001B-P06-dashboard.json"
$GatePath = Join-Path $PmoDir "SPT-001B-P06-quality-gate.json"
$RepairEvidencePath = Join-Path $PmoDir "SPT-001B-P06-v1.1-repair-evidence.json"

Write-Step "Validando componentes P06"

foreach ($Required in @(
    "schema.py",
    "models.py",
    "schema_loader.py",
    "profile_models.py",
    "excel_reader.py",
    "exporter.py",
    "events.py",
    "pipeline.py",
    "cli.py"
)) {
    Assert-Path `
        -Path (Join-Path $RlbDir $Required) `
        -Description $Required
}

Assert-Path `
    -Path (Join-Path $ProjectRoot "tests\rlb\test_pipeline_p06.py") `
    -Description "test_pipeline_p06.py"

Assert-Path `
    -Path (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json") `
    -Description "SGD-114"

$env:PYTHONPATH = $SrcRoot

$InitContent = @'
"""Repositorio Léxico Base del ecosistema SGODA-PUINAVE.

Este módulo conserva la API pública histórica del RLB. El módulo CLI
no se importa aquí para evitar cargas anticipadas al ejecutar
``python -m sgoda.rlb.cli``.
"""

from .events import (
    EventoRepositorioImportado,
    publicar_evento_jsonl,
)
from .excel_reader import (
    ErrorFilaRLB,
    LectorExcelRLB,
    ResultadoLecturaRLB,
)
from .exporter import exportar_resultado
from .models import (
    CampoDesconocido,
    OrigenRLB,
    RegistroLexico,
)
from .pipeline import (
    ResultadoPipelineRLB,
    ejecutar_pipeline,
)
from .profile_models import (
    PerfilHojaRLB,
    PerfilRepositorioRLB,
)
from .schema import (
    CampoEsquema,
    EsquemaRLB,
    ResultadoMapeo,
)
from .schema_loader import (
    ErrorEsquemaRLB,
    cargar_esquema,
)

__all__ = [
    "CampoDesconocido",
    "CampoEsquema",
    "ErrorEsquemaRLB",
    "ErrorFilaRLB",
    "EsquemaRLB",
    "EventoRepositorioImportado",
    "LectorExcelRLB",
    "OrigenRLB",
    "PerfilHojaRLB",
    "PerfilRepositorioRLB",
    "RegistroLexico",
    "ResultadoLecturaRLB",
    "ResultadoMapeo",
    "ResultadoPipelineRLB",
    "cargar_esquema",
    "ejecutar_pipeline",
    "exportar_resultado",
    "publicar_evento_jsonl",
]
'@

Write-Step "Restaurando API pública sgoda.rlb"
Write-Utf8NoBom -Path $InitPath -Content $InitContent

Write-Step "Validando símbolos públicos"

& python -c "from sgoda.rlb import CampoEsquema, EsquemaRLB, LectorExcelRLB, ejecutar_pipeline; print(CampoEsquema.__name__, EsquemaRLB.__name__, LectorExcelRLB.__name__, ejecutar_pipeline.__name__)"
if ($LASTEXITCODE -ne 0) {
    throw "No se restauró correctamente la API pública de sgoda.rlb."
}

Write-Step "Ejecutando pruebas de esquema"

& python -m pytest "tests/rlb/test_schema.py" -q
if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas de esquema continúan con errores."
}

Write-Step "Ejecutando pruebas específicas P06"

& python -m pytest "tests/rlb/test_pipeline_p06.py" -q
if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas P06 terminaron con errores."
}

Write-Step "Ejecutando suite completa"

& python -m pytest
if ($LASTEXITCODE -ne 0) {
    throw "La suite completa terminó con errores."
}

$OfficialProcessed = $false

if (-not $SkipOfficialRun) {
    Write-Step "Procesando Excel oficial"

    if ([string]::IsNullOrWhiteSpace($OfficialExcelPath)) {
        $Candidate = Get-ChildItem `
            -LiteralPath $ProjectRoot `
            -File `
            -Filter "*.xlsx" |
            Where-Object { $_.Name -notlike "~`$*" } |
            Sort-Object Name |
            Select-Object -First 1

        if ($null -ne $Candidate) {
            $OfficialExcelPath = $Candidate.FullName
        }
    }

    if ([string]::IsNullOrWhiteSpace($OfficialExcelPath)) {
        Write-Host "No se encontró Excel oficial; se omite esta etapa." -ForegroundColor Yellow
    }
    else {
        $OfficialExcelPath = [System.IO.Path]::GetFullPath($OfficialExcelPath)
        Assert-Path -Path $OfficialExcelPath -Description "el Excel oficial"

        & python -m sgoda.rlb.cli `
            --excel "$OfficialExcelPath" `
            --schema "config/rlb/schema-v1.json" `
            --output "artifacts/rlb/SPT-001B-P06" `
            --events "artifacts/pmo/SPT-001B-P06/repository-events.jsonl"

        if ($LASTEXITCODE -ne 0) {
            throw "Falló el procesamiento del Excel oficial."
        }

        $OfficialProcessed = $true
    }
}

Write-Step "Generando evidencia del correctivo"

$Evidence = [ordered]@{
    increment_code = "SPT-001B-P06"
    correction_version = "1.1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    corrected_file = "src/sgoda/rlb/__init__.py"
    restored_symbols = @(
        "CampoEsquema",
        "EsquemaRLB",
        "ResultadoMapeo",
        "RegistroLexico",
        "LectorExcelRLB",
        "ejecutar_pipeline"
    )
    schema_tests = "approved"
    p06_tests = "approved"
    full_suite = "approved"
    official_repository_processed = $OfficialProcessed
    official_excel = $OfficialExcelPath
}
Write-JsonUtf8 -Path $RepairEvidencePath -Data $Evidence

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-001B-P06" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SGD-114 no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El quality gate no contiene passed=true."
}

$Dashboard = [ordered]@{
    increment_code = "SPT-001B-P06"
    correction_version = "1.1"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    schema_tests = "approved"
    specific_tests = "approved"
    full_suite = "approved"
    quality_gate = "approved"
    official_repository_processed = $OfficialProcessed
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SPT-001B-P06 v1.1 corregido y validado." -ForegroundColor Green
Write-Host "API pública sgoda.rlb: RESTAURADA." -ForegroundColor Green
Write-Host "Pruebas de esquema: APROBADAS." -ForegroundColor Green
Write-Host "Pruebas específicas P06: APROBADAS." -ForegroundColor Green
Write-Host "Suite completa: APROBADA." -ForegroundColor Green
Write-Host "Quality gate SGD-114: APROBADO." -ForegroundColor Green
Write-Host "Evidencia: $RepairEvidencePath" -ForegroundColor Green
