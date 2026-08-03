<#
.SYNOPSIS
    Aplica SPT-016A v1.0.1 — Evidence Compatibility Patch.

.DESCRIPTION
    Corrige exclusivamente la generación de evidencia institucional de
    SPT-016 sin modificar su código funcional.

    El correctivo:
      - mantiene intactos los módulos de SPT-016;
      - reejecuta pruebas específicas mediante SGD-114F;
      - reejecuta la suite completa con JUnit XML;
      - reconstruye la evidencia desde cero con estructura estable;
      - valida la demostración AMDA existente;
      - regenera el release SPT-016A-v1.0.1;
      - ejecuta SGD-114D, SGD-114E, SGD-115 y SGD-116;
      - publica mediante SPB-007 solo si todo queda aprobado.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. Impide publicar.

.PARAMETER Publish
    Publica mediante SPB-007 si todos los gates quedan aprobados.
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
}

function Write-Json {
    param(
        [string]$Path,
        [object]$Value
    )

    Write-Utf8 `
        -Path $Path `
        -Content (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\learning_analytics"
$TestsDir = Join-Path $ProjectRoot "tests\learning_analytics"
$DocsDir = Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-016"
$ArtifactDir = Join-Path $ProjectRoot "artifacts\learning_analytics\SPT-016"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-016"
$PatchPmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-016A"
$ReportsDir = Join-Path $PatchPmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-016A-v1.0.1"
$BackupDir = Join-Path `
    $PatchPmoDir `
    ("backups\pre-SPT016A-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$TestPath = Join-Path $TestsDir "test_SPT_016_learning_analytics_engine.py"
$DemoRequest = Join-Path $ArtifactDir "demo-request.json"
$DemoOutput = Join-Path $ArtifactDir "demo-output.json"
$OriginalEvidence = Join-Path $PmoDir "SPT-016-implementation-evidence.json"
$PatchEvidence = Join-Path $PatchPmoDir "SPT-016A-implementation-evidence.json"
$PatchEvidenceMd = Join-Path $PatchPmoDir "SPT-016A-implementation-evidence.md"

$SpecificXml = Join-Path $ReportsDir "SPT-016-specific.xml"
$SpecificJson = Join-Path $ReportsDir "SPT-016-specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "SPT-016-specific-summary.md"
$FullXml = Join-Path $ReportsDir "SPT-016-full-suite.xml"
$FullJson = Join-Path $ReportsDir "SPT-016-full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "SPT-016-full-suite-summary.md"

$PolicyJson = Join-Path $PatchPmoDir "SPT-016A-policy-result.json"
$PolicyMd = Join-Path $PatchPmoDir "SPT-016A-policy-result.md"
$NativeJson = Join-Path $PatchPmoDir "SPT-016A-native-result.json"
$NativeMd = Join-Path $PatchPmoDir "SPT-016A-native-result.md"

$PatchDoc = Join-Path $DocsDir "SPT-016A-Evidence-Compatibility-Patch.md"
$ComponentPath = Join-Path `
    $ProjectRoot `
    "config\learning_analytics\SPT-016A-component.json"

Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $SourceDir "models.py"),
    (Join-Path $SourceDir "repository.py"),
    (Join-Path $SourceDir "metrics.py"),
    (Join-Path $SourceDir "trends.py"),
    (Join-Path $SourceDir "recommendations.py"),
    (Join-Path $SourceDir "exporter.py"),
    (Join-Path $SourceDir "service.py"),
    (Join-Path $SourceDir "cli.py"),
    (Join-Path $SourceDir "__init__.py"),
    $TestPath,
    $DemoRequest,
    $DemoOutput,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"),
    (Join-Path $ProjectRoot "src\sgoda\governance\adaptive_policy_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File $Required
}

Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

if (Test-Path -LiteralPath $OriginalEvidence -PathType Leaf) {
    Copy-Item `
        -LiteralPath $OriginalEvidence `
        -Destination (Join-Path $BackupDir "SPT-016-implementation-evidence.json") `
        -Force
}

if (Test-Path -LiteralPath $PatchEvidence -PathType Leaf) {
    Copy-Item `
        -LiteralPath $PatchEvidence `
        -Destination (Join-Path $BackupDir "SPT-016A-implementation-evidence.json") `
        -Force
}

$PatchDocumentation = @'
# SPT-016A v1.0.1 — Evidence Compatibility Patch

## Problema corregido

La implementación funcional de SPT-016 aprobó sus pruebas específicas,
suite completa y demostración, pero el instalador intentó asignar propiedades
sobre un objeto `PSCustomObject` que no contenía previamente dichas
propiedades.

## Solución

SPT-016A reconstruye la evidencia institucional mediante un `ordered
hashtable` nuevo. No modifica propiedades inexistentes ni depende de la
estructura previa del archivo generado por SGD-114F.

## Garantías

- El código funcional de SPT-016 permanece intacto.
- Las métricas de pruebas provienen de JUnit XML.
- SGD-114F sigue siendo la fuente oficial.
- La publicación solo se permite con todos los gates aprobados.
'@

$Component = @'
{
  "increment_code": "SPT-016A",
  "name": "Evidence Compatibility Patch",
  "component_type": "institutional_maintenance_patch",
  "version": "1.0.1",
  "status": "implemented",
  "phase": "Fase Tecnológica IV",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "SPT-016",
    "SGD-114F",
    "SGD-114D",
    "SGD-114E",
    "SGD-115A",
    "SGD-116",
    "SPB-007"
  ],
  "scope": [
    "evidence reconstruction",
    "JUnit synchronization",
    "release regeneration",
    "institutional closure"
  ]
}
'@

Write-Utf8 -Path $PatchDoc -Content $PatchDocumentation
Write-Utf8 -Path $ComponentPath -Content $Component

Run "Validando nuevamente sintaxis Python de SPT-016" {
    python -m py_compile `
        "src/sgoda/learning_analytics/models.py" `
        "src/sgoda/learning_analytics/repository.py" `
        "src/sgoda/learning_analytics/metrics.py" `
        "src/sgoda/learning_analytics/trends.py" `
        "src/sgoda/learning_analytics/recommendations.py" `
        "src/sgoda/learning_analytics/exporter.py" `
        "src/sgoda/learning_analytics/service.py" `
        "src/sgoda/learning_analytics/cli.py" `
        "src/sgoda/learning_analytics/__init__.py" `
        "tests/learning_analytics/test_SPT_016_learning_analytics_engine.py"
}

Run "Ejecutando pruebas específicas SPT-016 mediante SGD-114F" {
    & (Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1") `
        -Component "SPT-016" `
        -TestPath "tests/learning_analytics/test_SPT_016_learning_analytics_engine.py" `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific"
}

$SpecificSummary = Get-Content `
    -LiteralPath $SpecificJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$SpecificSummary.approved) {
    throw "Las pruebas específicas SPT-016 no fueron aprobadas."
}

if (-not $SkipFullSuite) {
    Run "Ejecutando suite completa con evidencia JUnit" {
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

    $FullSummary = Get-Content `
        -LiteralPath $FullJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$FullSummary.approved) {
        throw "La suite completa no fue aprobada."
    }
}

Step "Validando demostración AMDA existente"

$Demo = Get-Content `
    -LiteralPath $DemoOutput `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración AMDA no está aprobada."
}

if ([double]$Demo.data.progress.mastery -ne 0.75) {
    throw "El dominio AMDA esperado no es 0.75."
}

if ($Demo.data.trend -ne "improving") {
    throw "La tendencia AMDA esperada no es improving."
}

Step "Reconstruyendo evidencia compatible"

$FullSuiteEvidence = $null

if (-not $SkipFullSuite) {
    $FullSuiteEvidence = [ordered]@{
        executed = [int]$FullSummary.executed
        passed = [int]$FullSummary.passed
        failures = [int]$FullSummary.failures
        errors = [int]$FullSummary.errors
        skipped = [int]$FullSummary.skipped
        duration_seconds = [double]$FullSummary.duration_seconds
        approved = [bool]$FullSummary.approved
        source_report = [string]$FullSummary.source_report
    }
}

$Evidence = [ordered]@{
    increment_code = "SPT-016A"
    target_increment = "SPT-016"
    version = "1.0.1"
    status = "implemented_tested_and_approved"
    patch_type = "evidence_compatibility"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_of_test_truth = "SGD-114F / pytest JUnit XML"
    functional_code_modified = $false
    specific_tests = [ordered]@{
        executed = [int]$SpecificSummary.executed
        passed = [int]$SpecificSummary.passed
        failures = [int]$SpecificSummary.failures
        errors = [int]$SpecificSummary.errors
        skipped = [int]$SpecificSummary.skipped
        duration_seconds = [double]$SpecificSummary.duration_seconds
        approved = [bool]$SpecificSummary.approved
        source_report = [string]$SpecificSummary.source_report
    }
    full_suite = $FullSuiteEvidence
    demonstration = [ordered]@{
        status = [string]$Demo.status
        learner_id = [string]$Demo.data.learner_id
        mastery = [double]$Demo.data.progress.mastery
        trend = [string]$Demo.data.trend
        recommendation = [string]$Demo.data.recommendation.action
        approved = $true
        source = $DemoOutput
    }
    compatibility_fix = [ordered]@{
        previous_failure = "Missing property increment_code on PSCustomObject"
        resolution = "Rebuild evidence from ordered hashtable"
        previous_evidence_backed_up = (
            Test-Path -LiteralPath `
                (Join-Path $BackupDir "SPT-016-implementation-evidence.json")
        )
    }
    artifacts = [ordered]@{
        specific_summary_json = $SpecificJson
        specific_summary_markdown = $SpecificMd
        full_suite_summary_json = $FullJson
        full_suite_summary_markdown = $FullMd
        demonstration = $DemoOutput
    }
    backup = $BackupDir
}

Write-Json -Path $PatchEvidence -Value $Evidence
Write-Json -Path $OriginalEvidence -Value $Evidence

$EvidenceMarkdown = @"
# SPT-016A v1.0.1 — Evidencia institucional

- Incremento corregido: SPT-016
- Código funcional modificado: No
- Pruebas específicas: $($SpecificSummary.passed)/$($SpecificSummary.executed)
- Fallidas: $($SpecificSummary.failures)
- Errores: $($SpecificSummary.errors)
- Omitidas: $($SpecificSummary.skipped)
- Demostración AMDA: APROBADA
- Dominio AMDA: $($Demo.data.progress.mastery)
- Tendencia AMDA: $($Demo.data.trend)
- Fuente de pruebas: SGD-114F / pytest JUnit XML
"@

if (-not $SkipFullSuite) {
    $EvidenceMarkdown += @"

- Suite completa: $($FullSummary.passed)/$($FullSummary.executed)
- Fallidas suite: $($FullSummary.failures)
- Errores suite: $($FullSummary.errors)
- Omitidas suite: $($FullSummary.skipped)
"@
}

Write-Utf8 -Path $PatchEvidenceMd -Content $EvidenceMarkdown

Step "Regenerando release institucional"

foreach ($ReleaseFile in @(
    (Join-Path $SourceDir "models.py"),
    (Join-Path $SourceDir "repository.py"),
    (Join-Path $SourceDir "metrics.py"),
    (Join-Path $SourceDir "trends.py"),
    (Join-Path $SourceDir "recommendations.py"),
    (Join-Path $SourceDir "exporter.py"),
    (Join-Path $SourceDir "service.py"),
    (Join-Path $SourceDir "cli.py"),
    (Join-Path $SourceDir "__init__.py"),
    $TestPath,
    $DemoRequest,
    $DemoOutput,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $PatchEvidence,
    $PatchEvidenceMd,
    $PatchDoc,
    $ComponentPath
)) {
    Require-File $ReleaseFile
    Copy-Item -LiteralPath $ReleaseFile -Destination $ReleaseDir -Force
}

if (-not $SkipFullSuite) {
    foreach ($FullFile in @(
        $FullXml,
        $FullJson,
        $FullMd
    )) {
        Require-File $FullFile
        Copy-Item -LiteralPath $FullFile -Destination $ReleaseDir -Force
    }
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SPT-016A"
        target_increment = "SPT-016"
        version = "1.0.1"
        status = "implemented_tested_and_approved"
        files = @(
            Get-ChildItem -LiteralPath $ReleaseDir -File |
                Select-Object -ExpandProperty Name
        )
    })

Step "Evaluando SPT-016A mediante SGD-114D"

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$ProjectRoot" `
    --increment "SPT-016A" `
    --output-json "$PolicyJson" `
    --output-md "$PolicyMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114D no aprobó SPT-016A."
}

Step "Evaluando arquitectura nativa mediante SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$NativeJson" `
    --output-md "$NativeMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SPT-016A."
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
        -CommitMessage "fix(analytics): implement SPT-016A evidence compatibility patch" `
        -EvidenceCommitMessage "chore(analytics): publish SPT-016A synchronized evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SPT-016A v1.0.1 implementado." -ForegroundColor Green
Write-Host "Evidence Compatibility Patch: APLICADO." -ForegroundColor Green
Write-Host "Código funcional SPT-016: INTACTO." -ForegroundColor Green
Write-Host (
    "Pruebas específicas: " +
    "$($SpecificSummary.passed)/$($SpecificSummary.executed) APROBADAS."
) -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host (
        "Suite completa: " +
        "$($FullSummary.passed)/$($FullSummary.executed) APROBADAS."
    ) -ForegroundColor Green
}

Write-Host "Demostración AMDA: APROBADA." -ForegroundColor Green
Write-Host "Evidencia compatible: GENERADA." -ForegroundColor Green
Write-Host "SGD-114D: APROBADO." -ForegroundColor Green
Write-Host "SGD-114E: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-016A-v1.0.1" -ForegroundColor Cyan
Write-Host "Evidencia: $PatchEvidence" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Publicación no solicitada. Reejecute con -Publish." `
        -ForegroundColor Yellow
}
