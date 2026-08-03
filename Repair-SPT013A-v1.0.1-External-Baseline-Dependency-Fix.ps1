<#
SPT-013A v1.0.1 — External Baseline Dependency Fix
Corrige la validación de SPT-012 como dependencia externa ya implementada.
Compatible con Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Publish -and $SkipFullSuite) {
    throw "No se permite publicar con -SkipFullSuite."
}

function Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8([string]$Path, [string]$Content) {
    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )

    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }
}

function Write-Json([string]$Path, [object]$Value) {
    Write-Utf8 `
        -Path $Path `
        -Content (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
}

function Run([string]$Description, [scriptblock]$Action) {
    Step $Description
    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$RegistryPath = Join-Path $ProjectRoot "src\sgoda\learning_foundation\registry.py"
$TestPath = Join-Path $ProjectRoot "tests\learning_foundation\test_SPT_013A_learning_ecosystem_foundation.py"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-013A"
$ArtifactDir = Join-Path $ProjectRoot "artifacts\learning_foundation\SPT-013A"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-013A-v1.0.1"
$BackupDir = Join-Path $PmoDir ("backups\pre-SPT013A-v1.0.1-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$DemoPath = Join-Path $ArtifactDir "foundation-demo-v1.0.1.json"
$EvidencePath = Join-Path $PmoDir "SPT-013A-v1.0.1-implementation-evidence.json"
$PolicyJson = Join-Path $PmoDir "SPT-013A-v1.0.1-policy-result.json"
$PolicyMd = Join-Path $PmoDir "SPT-013A-v1.0.1-policy-result.md"
$NativeJson = Join-Path $PmoDir "SPT-013A-v1.0.1-native-result.json"
$NativeMd = Join-Path $PmoDir "SPT-013A-v1.0.1-native-result.md"

Step "Validando línea base"

foreach ($Required in @(
    $RegistryPath,
    $TestPath,
    (Join-Path $ProjectRoot "src\sgoda\learning_foundation\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\adaptive_policy_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File $Required
}

Step "Creando respaldo"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item -LiteralPath $RegistryPath -Destination $BackupDir -Force

$Registry = @'
"""Registro institucional de capacidades de la Fase IV.

SPT-012 es una dependencia externa de línea base ya implementada.
Las brechas internas se calculan únicamente entre SPT-013 y SPT-018.
"""

from __future__ import annotations

from .models import PhaseCapability


_PHASE_BASELINE_DEPENDENCIES = {
    "SPT-012",
}

_CAPABILITIES = (
    PhaseCapability(
        "SPT-013",
        "Gestor Institucional del Diccionario Digital",
        "dictionary",
        dependencies=("SPT-012",),
    ),
    PhaseCapability(
        "SPT-014",
        "Motor Multimedia Inteligente",
        "multimedia",
        dependencies=("SPT-013",),
    ),
    PhaseCapability(
        "SPT-015",
        "Motor de Evaluación Adaptativa",
        "assessment",
        dependencies=("SPT-013", "SPT-014"),
    ),
    PhaseCapability(
        "SPT-016",
        "Motor de Analítica del Aprendizaje",
        "analytics",
        dependencies=("SPT-015",),
    ),
    PhaseCapability(
        "SPT-017",
        "Centro de Conocimiento Puinave",
        "knowledge",
        dependencies=("SPT-013", "SPT-014"),
    ),
    PhaseCapability(
        "SPT-018",
        "IA Pedagógica SGODA",
        "pedagogical_ai",
        dependencies=(
            "SPT-013",
            "SPT-014",
            "SPT-015",
            "SPT-016",
            "SPT-017",
        ),
    ),
)


def phase_capabilities() -> tuple[PhaseCapability, ...]:
    return _CAPABILITIES


def baseline_dependencies() -> tuple[str, ...]:
    return tuple(sorted(_PHASE_BASELINE_DEPENDENCIES))


def dependency_gaps() -> tuple[dict[str, str], ...]:
    internal_codes = {item.code for item in _CAPABILITIES}
    accepted_codes = internal_codes | _PHASE_BASELINE_DEPENDENCIES
    gaps = []

    for item in _CAPABILITIES:
        for dependency in item.dependencies:
            if dependency not in accepted_codes:
                gaps.append(
                    {
                        "source": item.code,
                        "target": dependency,
                    }
                )

    return tuple(gaps)
'@

Step "Aplicando corrección"

Write-Utf8 -Path $RegistryPath -Content $Registry

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/learning_foundation/registry.py" `
        "tests/learning_foundation/test_SPT_013A_learning_ecosystem_foundation.py"
}

Run "Ejecutando 14 pruebas específicas SPT-013A" {
    python -m pytest `
        "tests/learning_foundation/test_SPT_013A_learning_ecosystem_foundation.py" `
        -q
}

if (-not $SkipFullSuite) {
    Run "Ejecutando suite completa" {
        python -m pytest
    }
}

Run "Ejecutando demostración" {
    python -m sgoda.learning_foundation.cli `
        --operation "validate" `
        --output "$DemoPath"
}

$Demo = Get-Content -LiteralPath $DemoPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración SPT-013A v1.0.1 no fue aprobada."
}

if (-not [bool]$Demo.data.approved) {
    throw "La fundación continúa con brechas de dependencia."
}

Step "Generando evidencia y release"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json `
    -Path $EvidencePath `
    -Value ([ordered]@{
        increment_code = "SPT-013A"
        version = "1.0.1"
        status = "implemented_and_tested"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        corrected_issue = "SPT-012 external baseline dependency"
        baseline_dependencies = @("SPT-012")
        specific_tests = 14
        full_suite_executed = (-not $SkipFullSuite)
        demo_approved = [bool]$Demo.data.approved
        dependency_gaps = @($Demo.data.dependencyGaps)
        backup = $BackupDir
    })

foreach ($File in @(
    $RegistryPath,
    $TestPath,
    $DemoPath,
    $EvidencePath
)) {
    Require-File $File
    Copy-Item -LiteralPath $File -Destination $ReleaseDir -Force
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SPT-013A"
        version = "1.0.1"
        status = "implemented_and_tested"
        files = @(
            Get-ChildItem -LiteralPath $ReleaseDir -File |
                Select-Object -ExpandProperty Name
        )
    })

Step "Evaluando SGD-114D"

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$ProjectRoot" `
    --increment "SPT-013A" `
    --output-json "$PolicyJson" `
    --output-md "$PolicyMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114D no aprobó SPT-013A."
}

Step "Evaluando SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$NativeJson" `
    --output-md "$NativeMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SPT-013A."
}

Run "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Run "Regenerando SGD-116" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

if ($Publish) {
    Step "Publicando mediante SPB-007"

    & (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1") `
        -Publish `
        -CommitMessage "fix(learning): resolve SPT-013A external baseline dependency" `
        -EvidenceCommitMessage "chore(learning): publish SPT-013A v1.0.1 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SPT-013A v1.0.1 implementado." -ForegroundColor Green
Write-Host "Dependencia externa SPT-012: RECONOCIDA." -ForegroundColor Green
Write-Host "Brechas internas de la Fase IV: 0." -ForegroundColor Green
Write-Host "Pruebas específicas: 14 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Demostración: APROBADA." -ForegroundColor Green
Write-Host "SGD-114D: APROBADO." -ForegroundColor Green
Write-Host "SGD-114E: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-013A-v1.0.1" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
