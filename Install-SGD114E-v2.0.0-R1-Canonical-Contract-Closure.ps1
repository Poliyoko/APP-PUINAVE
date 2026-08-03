<#
.SYNOPSIS
    Instala SGD-114E v2.0.0-R1 — Canonical Contract Closure.

.DESCRIPTION
    Cierre definitivo del contrato de SGD-114E.

    Resuelve el conflicto entre:
      - la implementación vigente 2.0.0;
      - una prueba transitoria v1.0.7 que exigía implementation_version 1.0.7.

    Política:
      - la prueba transitoria se conserva como evidencia histórica;
      - se retira de la suite activa;
      - implementation_version queda canónicamente en 2.0.0;
      - los contratos históricos de acceso permanecen operativos;
      - la publicación solo ocurre si toda la suite queda aprobada.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8 {
    param(
        [string]$Path,
        [string]$Content
    )

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

    Write-Host "Creado/actualizado: $Path" -ForegroundColor Green
}

function Write-Json {
    param(
        [string]$Path,
        [object]$Value
    )

    Write-Utf8 `
        -Path $Path `
        -Content (
            ($Value | ConvertTo-Json -Depth 100) +
            [Environment]::NewLine
        )
}

function Run {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

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

$ValidatorPath = Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_validator.py"
$ModelsPath = Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_models.py"
$CliPath = Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_cli.py"
$RunnerPath = Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"

$LegacyActiveTest = Join-Path `
    $ProjectRoot `
    "tests\governance\test_SGD_114E_v1_0_7_definitive_prevalidated_contract_closure.py"

$LegacyArchiveDir = Join-Path `
    $ProjectRoot `
    "artifacts\governance\SGD-114E\legacy-tests"

$LegacyArchiveTest = Join-Path `
    $LegacyArchiveDir `
    "test_SGD_114E_v1_0_7_definitive_prevalidated_contract_closure.py"

$LegacyRetirementRecord = Join-Path `
    $LegacyArchiveDir `
    "SGD-114E-v1.0.7-test-retirement.json"

$CanonicalTest = Join-Path `
    $ProjectRoot `
    "tests\governance\test_SGD_114E_v2_0_0_canonical_contract.py"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E-v2.0.0-R1"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114E-v2.0.0-R1"
$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-R1-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"
$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"
$SelfJson = Join-Path $PmoDir "self-validation.json"
$SelfMd = Join-Path $PmoDir "self-validation.md"
$Evidence = Join-Path $PmoDir "implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "implementation-evidence.md"

$ComponentPath = Join-Path `
    $ProjectRoot `
    "config\governance\SGD-114E-v2.0.0-R1-component.json"

$DocPath = Join-Path `
    $ProjectRoot `
    "docs\01_Gobierno\SGD-114E-v2.0.0-R1-Canonical-Contract-Closure.md"

Step "Validando línea base"

foreach ($Required in @(
    $ValidatorPath,
    $ModelsPath,
    $CliPath,
    $RunnerPath,
    $LegacyActiveTest,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File $Required
}

Step "Creando respaldo"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
New-Item -ItemType Directory -Path $LegacyArchiveDir -Force | Out-Null

foreach ($File in @(
    $ValidatorPath,
    $ModelsPath,
    $CliPath,
    $LegacyActiveTest,
    $CanonicalTest
)) {
    if (Test-Path -LiteralPath $File -PathType Leaf) {
        Copy-Item `
            -LiteralPath $File `
            -Destination $BackupDir `
            -Force
    }
}

Step "Archivando prueba transitoria v1.0.7"

Copy-Item `
    -LiteralPath $LegacyActiveTest `
    -Destination $LegacyArchiveTest `
    -Force

$LegacyHash = (
    Get-FileHash `
        -LiteralPath $LegacyActiveTest `
        -Algorithm SHA256
).Hash

Write-Json `
    -Path $LegacyRetirementRecord `
    -Value ([ordered]@{
        test_id = "SGD-114E-v1.0.7"
        original_path = $LegacyActiveTest
        archived_path = $LegacyArchiveTest
        sha256 = $LegacyHash
        retired_from_active_suite = $true
        retirement_reason = (
            "La prueba transitoria exigía implementation_version 1.0.7 " +
            "dentro de la implementación canónica 2.0.0."
        )
        historical_evidence_preserved = $true
        retired_at_utc = [DateTime]::UtcNow.ToString("o")
    })

Remove-Item `
    -LiteralPath $LegacyActiveTest `
    -Force

$CanonicalTests = @'
from __future__ import annotations

from pathlib import Path

from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def test_canonical_implementation_version(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.implementation_version == "2.0.0"


def test_historical_mapping_contract(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result["version"] == "1.0.3"


def test_historical_attribute_contract(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.version == "1.0.5"


def test_empty_repository_policy_and_state(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result["criteria"]["empty_repository_allowed"] is True
    assert result.repository_is_empty is True


def test_exit_code_matches_approval(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0


def test_native_components_attribute_is_tuple(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert isinstance(result.native_components, tuple)


def test_to_dict_is_json_ready(
    tmp_path: Path,
) -> None:
    payload = evaluate_native_ecosystem(
        tmp_path
    ).to_dict()

    assert isinstance(payload, dict)
    assert payload["implementation_version"] == "2.0.0"
'@

$Component = @'
{
  "increment_code": "SGD-114E-v2.0.0-R1",
  "name": "Canonical Contract Closure",
  "version": "2.0.0-R1",
  "status": "implemented",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "canonical_implementation_version": "2.0.0",
  "legacy_test_preserved": true,
  "legacy_test_retired_from_active_suite": true
}
'@

$Documentation = @'
# SGD-114E v2.0.0-R1 — Canonical Contract Closure

## Decisión definitiva

La implementación canónica es `2.0.0`.

La prueba transitoria v1.0.7 que exigía
`implementation_version == "1.0.7"` se conserva íntegramente como evidencia,
pero se retira de la suite activa porque contradice la versión canónica.

## Contratos conservados

- `result["version"] == "1.0.3"`
- `result.version == "1.0.5"`
- `result.implementation_version == "2.0.0"`
- `result.approved`
- `result.exit_code`
- `result.component_count`
- `result.findings`
- `result.native_components`
- `result.to_dict()`

## Política de pruebas

Las pruebas históricas válidas permanecen activas.
Las pruebas transitorias contradictorias se archivan con SHA-256 y acta de
retiro, sin borrarse ni perder trazabilidad.
'@

Write-Utf8 -Path $CanonicalTest -Content $CanonicalTests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $DocPath -Content $Documentation

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/native_ecosystem_models.py" `
        "src/sgoda/governance/native_ecosystem_validator.py" `
        "src/sgoda/governance/native_ecosystem_cli.py" `
        "tests/governance/test_SGD_114E_v2_0_0_canonical_contract.py"
}

Run "Ejecutando pruebas contractuales activas SGD-114E" {
    $ActiveTests = @(
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py",
        "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py",
        "tests/governance/test_SGD_114E_v1_0_5_backward_compatibility_result_model.py",
        "tests/governance/test_SGD_114E_v1_0_6_definitive_contract_restoration.py",
        "tests/governance/test_SGD_114E_v2_0_0_definitive_native_ecosystem_validator.py",
        "tests/governance/test_SGD_114E_v2_0_0_canonical_contract.py"
    )

    & $RunnerPath `
        -Component "SGD-114E-v2.0.0-R1" `
        -TestPath $ActiveTests `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific"
}

$Specific = Get-Content `
    -LiteralPath $SpecificJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Specific.approved) {
    throw "Las pruebas contractuales activas no fueron aprobadas."
}

Run "Ejecutando suite completa" {
    python -m pytest `
        --junitxml="$FullXml"
}

Run "Sincronizando suite completa mediante SGD-114F" {
    python -m sgoda.governance.test_evidence.cli `
        --junit "$FullXml" `
        --component "SGODA-PUINAVE" `
        --scope "full_suite" `
        --output-json "$FullJson" `
        --output-md "$FullMd"
}

$Full = Get-Content `
    -LiteralPath $FullJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Full.approved) {
    throw "La suite completa no fue aprobada."
}

Step "Autoevaluando SGD-114E"

python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$SelfJson" `
    --output-md "$SelfMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó su autoevaluación."
}

$Self = Get-Content `
    -LiteralPath $SelfJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$EvidenceObject = [ordered]@{
    increment_code = "SGD-114E-v2.0.0-R1"
    status = "implemented_tested_and_approved"
    canonical_implementation_version = "2.0.0"
    legacy_test = [ordered]@{
        archived = $true
        retired_from_active_suite = $true
        archived_path = $LegacyArchiveTest
        sha256 = $LegacyHash
    }
    specific_tests = [ordered]@{
        executed = [int]$Specific.executed
        passed = [int]$Specific.passed
        failures = [int]$Specific.failures
        errors = [int]$Specific.errors
        skipped = [int]$Specific.skipped
        approved = [bool]$Specific.approved
    }
    full_suite = [ordered]@{
        executed = [int]$Full.executed
        passed = [int]$Full.passed
        failures = [int]$Full.failures
        errors = [int]$Full.errors
        skipped = [int]$Full.skipped
        approved = [bool]$Full.approved
    }
    self_validation = $Self
    backup = $BackupDir
}

Write-Json -Path $Evidence -Value $EvidenceObject

Write-Utf8 -Path $EvidenceMd -Content @"
# SGD-114E v2.0.0-R1 — Evidencia

- Implementación canónica: 2.0.0
- Prueba transitoria v1.0.7: archivada
- SHA-256 prueba archivada: $LegacyHash
- Pruebas contractuales: $($Specific.passed)/$($Specific.executed)
- Suite completa: $($Full.passed)/$($Full.executed)
- Autoevaluación: $($Self.result)
"@

foreach ($File in @(
    $ModelsPath,
    $ValidatorPath,
    $CliPath,
    $CanonicalTest,
    $ComponentPath,
    $DocPath,
    $LegacyArchiveTest,
    $LegacyRetirementRecord,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $FullXml,
    $FullJson,
    $FullMd,
    $SelfJson,
    $SelfMd,
    $Evidence,
    $EvidenceMd
)) {
    Require-File $File

    Copy-Item `
        -LiteralPath $File `
        -Destination $ReleaseDir `
        -Force
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SGD-114E-v2.0.0-R1"
        status = "implemented_tested_and_approved"
        canonical_implementation_version = "2.0.0"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
                Select-Object -ExpandProperty Name
        )
    })

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
        -CommitMessage "fix(governance): close canonical SGD-114E contract" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114E v2.0.0-R1 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SGD-114E v2.0.0-R1 implementado." -ForegroundColor Green
Write-Host "Canonical Contract Closure: APROBADO." -ForegroundColor Green
Write-Host "Implementación canónica: 2.0.0." -ForegroundColor Green
Write-Host "Prueba transitoria v1.0.7: ARCHIVADA." -ForegroundColor Green
Write-Host (
    "Pruebas contractuales: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Suite completa: " +
    "$($Full.passed)/$($Full.executed) APROBADA."
) -ForegroundColor Green
Write-Host "Autoevaluación SGD-114E: APROBADA." -ForegroundColor Green
Write-Host "Release: releases\SGD-114E-v2.0.0-R1" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
