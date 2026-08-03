<#
.SYNOPSIS
    Aplica SGD-114E v1.0.4 — Multi-Test-Path Invocation Fix.

.DESCRIPTION
    Corrige la invocación de varias rutas de pruebas a través del ejecutor
    reutilizable instalado por SGD-114F.

    El error anterior entregaba dos rutas como una sola cadena a pytest.
    Este correctivo:
      - actualiza Invoke-InstitutionalPytest.ps1 para aceptar string[];
      - conserva intacta la lógica SGD-114E v1.0.3;
      - ejecuta ambas suites específicas correctamente;
      - ejecuta la suite completa;
      - autoevalúa SGD-114E;
      - revalida SPT-016A;
      - genera evidencia, release y publicación condicionada.
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
    param([string]$Path, [string]$Content)

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
    param([string]$Path, [object]$Value)

    Write-Utf8 `
        -Path $Path `
        -Content (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
}

function Run {
    param([string]$Description, [scriptblock]$Action)

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

$RunnerPath = Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"
$ExistingTestPath = Join-Path $ProjectRoot "tests\governance\test_SGD_114E_native_ecosystem_architecture_policy.py"
$PatchTestPath = Join-Path $ProjectRoot "tests\governance\test_SGD_114E_v1_0_3_approval_logic_fix.py"
$ValidatorPath = Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_validator.py"
$CliPath = Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_cli.py"
$ComponentPath = Join-Path $ProjectRoot "config\governance\SGD-114E-v1.0.3-component.json"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E-v1.0.4"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114E-v1.0.4"
$BackupDir = Join-Path $PmoDir ("backups\pre-SGD114E-v1.0.4-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$SpecificXml = Join-Path $ReportsDir "SGD-114E-v1.0.4-specific.xml"
$SpecificJson = Join-Path $ReportsDir "SGD-114E-v1.0.4-specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "SGD-114E-v1.0.4-specific-summary.md"
$FullXml = Join-Path $ReportsDir "SGD-114E-v1.0.4-full-suite.xml"
$FullJson = Join-Path $ReportsDir "SGD-114E-v1.0.4-full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "SGD-114E-v1.0.4-full-suite-summary.md"

$SelfJson = Join-Path $PmoDir "SGD-114E-v1.0.4-self-validation.json"
$SelfMd = Join-Path $PmoDir "SGD-114E-v1.0.4-self-validation.md"
$Spt016AJson = Join-Path $PmoDir "SPT-016A-native-validation.json"
$Spt016AMd = Join-Path $PmoDir "SPT-016A-native-validation.md"
$EvidencePath = Join-Path $PmoDir "SGD-114E-v1.0.4-implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "SGD-114E-v1.0.4-implementation-evidence.md"

$PatchDoc = Join-Path $ProjectRoot "docs\01_Gobierno\SGD-114E-v1.0.4-Multi-Test-Path-Invocation-Fix.md"
$PatchComponent = Join-Path $ProjectRoot "config\governance\SGD-114E-v1.0.4-component.json"

Step "Validando línea base institucional"

foreach ($Required in @(
    $RunnerPath,
    $ExistingTestPath,
    $PatchTestPath,
    $ValidatorPath,
    $CliPath,
    $ComponentPath,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "config\learning_analytics\SPT-016A-component.json")
)) {
    Require-File $Required
}

Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Copy-Item `
    -LiteralPath $RunnerPath `
    -Destination (Join-Path $BackupDir "Invoke-InstitutionalPytest.ps1") `
    -Force

$Runner = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Component,

    [Parameter(Mandatory = $true)]
    [string[]]$TestPath,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$SummaryJson,

    [Parameter(Mandatory = $true)]
    [string]$SummaryMarkdown,

    [string]$Scope = "specific",

    [string]$EvidencePath,

    [string]$EvidenceKey = "specific_tests"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

if (@($TestPath).Count -eq 0) {
    throw "Debe proporcionar al menos una ruta de prueba."
}

foreach ($Path in $TestPath) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No existe la ruta de prueba: $Path"
    }
}

$ReportParent = Split-Path -Parent $ReportPath
if ($ReportParent) {
    New-Item -ItemType Directory -Path $ReportParent -Force | Out-Null
}

$PytestArguments = @(
    "-m",
    "pytest"
)

$PytestArguments += @($TestPath)
$PytestArguments += @(
    "--junitxml=$ReportPath",
    "-q"
)

& python @PytestArguments

if ($LASTEXITCODE -ne 0) {
    throw "pytest terminó con errores. Código: $LASTEXITCODE"
}

$SummaryArguments = @(
    "-m",
    "sgoda.governance.test_evidence.cli",
    "--junit",
    $ReportPath,
    "--component",
    $Component,
    "--scope",
    $Scope,
    "--output-json",
    $SummaryJson,
    "--output-md",
    $SummaryMarkdown,
    "--evidence-key",
    $EvidenceKey
)

if ($EvidencePath) {
    $SummaryArguments += @(
        "--evidence",
        $EvidencePath
    )
}

& python @SummaryArguments

exit $LASTEXITCODE
'@

$Documentation = @'
# SGD-114E v1.0.4 — Multi-Test-Path Invocation Fix

## Problema

`Invoke-InstitutionalPytest.ps1` declaraba `TestPath` como una cadena única.
Cuando el correctivo SGD-114E v1.0.3 envió dos rutas separadas por espacio,
pytest recibió una sola ruta inexistente.

## Corrección

El parámetro ahora es:

`[string[]]$TestPath`

Cada ruta se valida individualmente y se agrega como argumento independiente
a pytest.

La lógica de aprobación SGD-114E v1.0.3 permanece intacta.
'@

$Component = @'
{
  "increment_code": "SGD-114E-v1.0.4",
  "name": "Multi-Test-Path Invocation Fix",
  "component_type": "governance_execution_patch",
  "version": "1.0.4",
  "status": "implemented",
  "phase": "Gobierno Digital",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "SGD-114E-v1.0.3",
    "SGD-114F",
    "SGD-115A",
    "SGD-116",
    "SPB-007"
  ],
  "scope": [
    "multiple pytest path invocation",
    "reusable institutional runner",
    "SPT-016A revalidation"
  ]
}
'@

Step "Aplicando corrección de múltiples rutas"

Write-Utf8 -Path $RunnerPath -Content $Runner
Write-Utf8 -Path $PatchDoc -Content $Documentation
Write-Utf8 -Path $PatchComponent -Content $Component

Step "Validando sintaxis PowerShell del ejecutor"

$RunnerTokens = $null
$RunnerErrors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path -LiteralPath $RunnerPath),
    [ref]$RunnerTokens,
    [ref]$RunnerErrors
) | Out-Null

if (@($RunnerErrors).Count -gt 0) {
    $RunnerErrors |
        Select-Object ErrorId, Message, Extent |
        Format-List

    throw "El ejecutor institucional corregido contiene errores de sintaxis."
}

Run "Validando sintaxis Python SGD-114E" {
    python -m py_compile `
        "src/sgoda/governance/native_ecosystem_validator.py" `
        "src/sgoda/governance/native_ecosystem_cli.py" `
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py" `
        "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py"
}

Run "Ejecutando ambas suites específicas mediante SGD-114F" {
    & $RunnerPath `
        -Component "SGD-114E-v1.0.4" `
        -TestPath @(
            "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py",
            "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py"
        ) `
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
    throw "Las pruebas específicas SGD-114E no fueron aprobadas."
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

Step "Autoevaluando SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$SelfJson" `
    --output-md "$SelfMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó su autoevaluación."
}

$SelfResult = Get-Content `
    -LiteralPath $SelfJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$SelfResult.approved) {
    throw "La autoevaluación SGD-114E devolvió NO APROBADO."
}

Step "Revalidando SPT-016A"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$Spt016AJson" `
    --output-md "$Spt016AMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SPT-016A."
}

$Spt016AResult = Get-Content `
    -LiteralPath $Spt016AJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Spt016AResult.approved) {
    throw "SPT-016A continúa sin aprobación."
}

Step "Generando evidencia y release"

$FullEvidence = $null

if (-not $SkipFullSuite) {
    $FullEvidence = [ordered]@{
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
    increment_code = "SGD-114E-v1.0.4"
    target_component = "SGD-114E-v1.0.3"
    version = "1.0.4"
    status = "implemented_tested_and_approved"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    patch_type = "multi_test_path_invocation_fix"
    institutional_runner = [ordered]@{
        path = $RunnerPath
        parameter_type = "string[]"
        multiple_paths_supported = $true
    }
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
    full_suite = $FullEvidence
    native_validation = [ordered]@{
        approved = [bool]$SelfResult.approved
        result = [string]$SelfResult.result
        native_components = [int]$SelfResult.native_component_count
        forbidden_terms = [int]$SelfResult.forbidden_term_count
        proprietary_dependencies = [int]$SelfResult.mandatory_proprietary_dependency_count
        structural_errors = [int]$SelfResult.structural_error_count
    }
    spt_016a = [ordered]@{
        approved = [bool]$Spt016AResult.approved
        result = [string]$Spt016AResult.result
    }
    backup = $BackupDir
}

Write-Json -Path $EvidencePath -Value $Evidence

$EvidenceText = @"
# SGD-114E v1.0.4 — Evidencia

- Correctivo: Multi-Test-Path Invocation Fix
- Ejecutor institucional: string[]
- Pruebas específicas: $($SpecificSummary.passed)/$($SpecificSummary.executed)
- Autoevaluación SGD-114E: $($SelfResult.result)
- SPT-016A: $($Spt016AResult.result)
- Componentes nativos: $($SelfResult.native_component_count)
- Términos prohibidos: $($SelfResult.forbidden_term_count)
- Dependencias propietarias obligatorias: $($SelfResult.mandatory_proprietary_dependency_count)
- Errores estructurales: $($SelfResult.structural_error_count)
"@

if (-not $SkipFullSuite) {
    $EvidenceText += @"

- Suite completa: $($FullSummary.passed)/$($FullSummary.executed)
- Fallos: $($FullSummary.failures)
- Errores: $($FullSummary.errors)
- Omitidas: $($FullSummary.skipped)
"@
}

Write-Utf8 -Path $EvidenceMd -Content $EvidenceText

foreach ($ReleaseFile in @(
    $RunnerPath,
    $ValidatorPath,
    $CliPath,
    $ExistingTestPath,
    $PatchTestPath,
    $PatchDoc,
    $PatchComponent,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $SelfJson,
    $SelfMd,
    $Spt016AJson,
    $Spt016AMd,
    $EvidencePath,
    $EvidenceMd
)) {
    Require-File $ReleaseFile
    Copy-Item -LiteralPath $ReleaseFile -Destination $ReleaseDir -Force
}

if (-not $SkipFullSuite) {
    foreach ($File in @($FullXml, $FullJson, $FullMd)) {
        Require-File $File
        Copy-Item -LiteralPath $File -Destination $ReleaseDir -Force
    }
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SGD-114E-v1.0.4"
        version = "1.0.4"
        status = "implemented_tested_and_approved"
        files = @(
            Get-ChildItem -LiteralPath $ReleaseDir -File |
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
        -CommitMessage "fix(governance): support multiple SGD-114E test paths" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114E v1.0.4 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SGD-114E v1.0.4 implementado." -ForegroundColor Green
Write-Host "Multi-Test-Path Invocation Fix: APLICADO." -ForegroundColor Green
Write-Host "Ejecutor institucional string[]: OPERATIVO." -ForegroundColor Green
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

Write-Host "Autoevaluación SGD-114E: APROBADA." -ForegroundColor Green
Write-Host "SPT-016A: APROBADO POR SGD-114E." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SGD-114E-v1.0.4" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Publicación no solicitada. Reejecute con -Publish." `
        -ForegroundColor Yellow
}
