<#
.SYNOPSIS
    Aplica SGD-114E v2.0.0-R2.2 — Release Name Normalization.

.DESCRIPTION
    Normaliza exclusivamente el nombre del release de SGD-114E.

    Corrige referencias como:
        releases\SGD-114E-v2.0.0-R2.1.1

    para consolidarlas como:
        releases\SGD-114E-v2.0.0-R2.1

    El correctivo:
      - no modifica el validador;
      - no modifica modelos;
      - no modifica contratos;
      - no modifica pruebas históricas;
      - respalda cualquier release previo;
      - fusiona de forma segura el contenido;
      - actualiza manifiestos y evidencias textuales;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - ejecuta autoevaluación SGD-114E;
      - genera evidencia R2.2;
      - publica solo si todo queda aprobado.
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

function Copy-DirectoryContent {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        return
    }

    New-Item `
        -ItemType Directory `
        -Path $Destination `
        -Force | Out-Null

    Get-ChildItem `
        -LiteralPath $Source `
        -Force |
        ForEach-Object {
            Copy-Item `
                -LiteralPath $_.FullName `
                -Destination $Destination `
                -Recurse `
                -Force
        }
}

function Replace-TextReference {
    param(
        [string]$Path,
        [string]$OldValue,
        [string]$NewValue
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $Content = Get-Content `
        -LiteralPath $Path `
        -Raw `
        -Encoding UTF8

    if ($Content.IndexOf($OldValue, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        return $false
    }

    $Updated = $Content.Replace($OldValue, $NewValue)

    Write-Utf8 `
        -Path $Path `
        -Content $Updated

    return $true
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$RunnerPath = Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"
$CliPath = Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_cli.py"
$TestsDir = Join-Path $ProjectRoot "tests\governance"

$CanonicalReleaseName = "SGD-114E-v2.0.0-R2.1"
$IncorrectReleaseName = "SGD-114E-v2.0.0-R2.1.1"

$CanonicalRelease = Join-Path $ProjectRoot ("releases\" + $CanonicalReleaseName)
$IncorrectRelease = Join-Path $ProjectRoot ("releases\" + $IncorrectReleaseName)

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E-v2.0.0-R2.2"
$ReportsDir = Join-Path $PmoDir "test-reports"
$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-R2.2-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114E-v2.0.0-R2.2"

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"

$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"

$SelfJson = Join-Path $PmoDir "self-validation.json"
$SelfMd = Join-Path $PmoDir "self-validation.md"
$NormalizationJson = Join-Path $PmoDir "release-name-normalization.json"
$EvidenceJson = Join-Path $PmoDir "implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "implementation-evidence.md"

$ComponentPath = Join-Path `
    $ProjectRoot `
    "config\governance\SGD-114E-v2.0.0-R2.2-component.json"

$DocPath = Join-Path `
    $ProjectRoot `
    "docs\01_Gobierno\SGD-114E-v2.0.0-R2.2-Release-Name-Normalization.md"

Step "Validando línea base"

foreach ($Required in @(
    $RunnerPath,
    $CliPath,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File $Required
}

if (
    -not (Test-Path -LiteralPath $CanonicalRelease -PathType Container) -and
    -not (Test-Path -LiteralPath $IncorrectRelease -PathType Container)
) {
    throw (
        "No existe el release canónico ni el release incorrecto. " +
        "Se esperaba encontrar $CanonicalReleaseName o $IncorrectReleaseName."
    )
}

Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

if (Test-Path -LiteralPath $CanonicalRelease -PathType Container) {
    Copy-Item `
        -LiteralPath $CanonicalRelease `
        -Destination (Join-Path $BackupDir $CanonicalReleaseName) `
        -Recurse `
        -Force
}

if (Test-Path -LiteralPath $IncorrectRelease -PathType Container) {
    Copy-Item `
        -LiteralPath $IncorrectRelease `
        -Destination (Join-Path $BackupDir $IncorrectReleaseName) `
        -Recurse `
        -Force
}

Step "Normalizando nombre del release"

$IncorrectExisted = Test-Path `
    -LiteralPath $IncorrectRelease `
    -PathType Container

$CanonicalExisted = Test-Path `
    -LiteralPath $CanonicalRelease `
    -PathType Container

if ($IncorrectExisted) {
    Copy-DirectoryContent `
        -Source $IncorrectRelease `
        -Destination $CanonicalRelease

    Remove-Item `
        -LiteralPath $IncorrectRelease `
        -Recurse `
        -Force
}

New-Item `
    -ItemType Directory `
    -Path $CanonicalRelease `
    -Force | Out-Null

$ReferenceRoots = @(
    (Join-Path $ProjectRoot "artifacts"),
    (Join-Path $ProjectRoot "docs"),
    (Join-Path $ProjectRoot "config"),
    (Join-Path $ProjectRoot "dashboard"),
    (Join-Path $ProjectRoot "releases")
)

$UpdatedReferences = @()

foreach ($Root in $ReferenceRoots) {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        continue
    }

    Get-ChildItem `
        -LiteralPath $Root `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @(
                ".json",
                ".md",
                ".txt",
                ".yaml",
                ".yml"
            )
        } |
        ForEach-Object {
            $Updated = Replace-TextReference `
                -Path $_.FullName `
                -OldValue $IncorrectReleaseName `
                -NewValue $CanonicalReleaseName

            if ($Updated) {
                $UpdatedReferences += $_.FullName
            }
        }
}

$CanonicalManifest = Join-Path $CanonicalRelease "manifest.json"

if (Test-Path -LiteralPath $CanonicalManifest -PathType Leaf) {
    try {
        $Manifest = Get-Content `
            -LiteralPath $CanonicalManifest `
            -Raw `
            -Encoding UTF8 |
            ConvertFrom-Json

        if ($null -eq $Manifest.PSObject.Properties["release_name"]) {
            $Manifest |
                Add-Member `
                    -MemberType NoteProperty `
                    -Name "release_name" `
                    -Value $CanonicalReleaseName
        }
        else {
            $Manifest.release_name = $CanonicalReleaseName
        }

        if ($null -eq $Manifest.PSObject.Properties["normalized_by"]) {
            $Manifest |
                Add-Member `
                    -MemberType NoteProperty `
                    -Name "normalized_by" `
                    -Value "SGD-114E-v2.0.0-R2.2"
        }
        else {
            $Manifest.normalized_by = "SGD-114E-v2.0.0-R2.2"
        }

        Write-Json `
            -Path $CanonicalManifest `
            -Value $Manifest
    }
    catch {
        throw "No fue posible normalizar el manifiesto canónico: $CanonicalManifest"
    }
}
else {
    Write-Json `
        -Path $CanonicalManifest `
        -Value ([ordered]@{
            increment_code = "SGD-114E-v2.0.0-R2.1"
            release_name = $CanonicalReleaseName
            status = "implemented_tested_and_approved"
            normalized_by = "SGD-114E-v2.0.0-R2.2"
            generated_at_utc = [DateTime]::UtcNow.ToString("o")
            files = @(
                Get-ChildItem `
                    -LiteralPath $CanonicalRelease `
                    -File |
                    Select-Object -ExpandProperty Name
            )
        })
}

$Normalization = [ordered]@{
    increment_code = "SGD-114E-v2.0.0-R2.2"
    canonical_release = $CanonicalReleaseName
    incorrect_release = $IncorrectReleaseName
    canonical_existed_before = $CanonicalExisted
    incorrect_existed_before = $IncorrectExisted
    incorrect_release_removed = (
        -not (
            Test-Path `
                -LiteralPath $IncorrectRelease `
                -PathType Container
        )
    )
    canonical_release_exists = (
        Test-Path `
            -LiteralPath $CanonicalRelease `
            -PathType Container
    )
    references_updated = $UpdatedReferences
    references_updated_count = $UpdatedReferences.Count
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    backup = $BackupDir
}

Write-Json `
    -Path $NormalizationJson `
    -Value $Normalization

if (
    Test-Path `
        -LiteralPath $IncorrectRelease `
        -PathType Container
) {
    throw "El release incorrecto todavía existe después de la normalización."
}

if (
    -not (
        Test-Path `
            -LiteralPath $CanonicalRelease `
            -PathType Container
    )
) {
    throw "El release canónico no existe después de la normalización."
}

$Component = @'
{
  "increment_code": "SGD-114E-v2.0.0-R2.2",
  "name": "Release Name Normalization",
  "version": "2.0.0-R2.2",
  "status": "implemented",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "scope": [
    "release directory normalization",
    "manifest normalization",
    "evidence reference normalization"
  ],
  "functional_code_modified": false,
  "tests_modified": false
}
'@

$Documentation = @'
# SGD-114E v2.0.0-R2.2 — Release Name Normalization

## Alcance

Este mantenimiento corrige únicamente el nombre duplicado del release:

- incorrecto: `SGD-114E-v2.0.0-R2.1.1`
- canónico: `SGD-114E-v2.0.0-R2.1`

## Garantías

- No modifica el validador.
- No modifica modelos.
- No modifica contratos.
- No modifica pruebas.
- Conserva respaldo del contenido previo.
- Actualiza referencias textuales y manifiestos.
- Reejecuta pruebas específicas, suite completa y autoevaluación.
'@

Write-Utf8 `
    -Path $ComponentPath `
    -Content $Component

Write-Utf8 `
    -Path $DocPath `
    -Content $Documentation

Run "Ejecutando pruebas específicas SGD-114E" {
    $ActiveTests = Get-ChildItem `
        -LiteralPath $TestsDir `
        -Filter "test_SGD_114E*.py" `
        -File |
        Select-Object -ExpandProperty FullName

    if (@($ActiveTests).Count -eq 0) {
        throw "No se encontraron pruebas activas de SGD-114E."
    }

    & $RunnerPath `
        -Component "SGD-114E-v2.0.0-R2.2" `
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
    throw "Las pruebas específicas no fueron aprobadas."
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

Step "Ejecutando autoevaluación SGD-114E"

python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$SelfJson" `
    --output-md "$SelfMd"

if ($LASTEXITCODE -ne 0) {
    throw "La autoevaluación SGD-114E no fue aprobada."
}

$Self = Get-Content `
    -LiteralPath $SelfJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Self.approved) {
    throw "La autoevaluación devolvió approved=false."
}

if ([int]$Self.exit_code -ne 0) {
    throw "La autoevaluación devolvió exit_code distinto de cero."
}

Step "Generando evidencia y release R2.2"

$EvidenceObject = [ordered]@{
    increment_code = "SGD-114E-v2.0.0-R2.2"
    status = "implemented_tested_and_approved"
    maintenance_type = "release_name_normalization"
    functional_code_modified = $false
    tests_modified = $false
    normalization = $Normalization
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
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    backup = $BackupDir
}

Write-Json `
    -Path $EvidenceJson `
    -Value $EvidenceObject

Write-Utf8 `
    -Path $EvidenceMd `
    -Content @"
# SGD-114E v2.0.0-R2.2 — Evidencia

- Release canónico: $CanonicalReleaseName
- Release incorrecto eliminado: $($Normalization.incorrect_release_removed)
- Referencias actualizadas: $($Normalization.references_updated_count)
- Código funcional modificado: No
- Pruebas modificadas: No
- Pruebas específicas: $($Specific.passed)/$($Specific.executed)
- Suite completa: $($Full.passed)/$($Full.executed)
- Autoevaluación: $($Self.result)
- Exit code: $($Self.exit_code)
"@

foreach ($File in @(
    $ComponentPath,
    $DocPath,
    $NormalizationJson,
    $CanonicalManifest,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $FullXml,
    $FullJson,
    $FullMd,
    $SelfJson,
    $SelfMd,
    $EvidenceJson,
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
        increment_code = "SGD-114E-v2.0.0-R2.2"
        release_name = "SGD-114E-v2.0.0-R2.2"
        status = "implemented_tested_and_approved"
        canonicalized_release = $CanonicalReleaseName
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
        -CommitMessage "fix(governance): normalize SGD-114E release name" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114E R2.2 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SGD-114E v2.0.0-R2.2 implementado." -ForegroundColor Green
Write-Host "Release Name Normalization: APROBADA." -ForegroundColor Green
Write-Host "Release canónico: releases\$CanonicalReleaseName" -ForegroundColor Green
Write-Host "Release incorrecto: ELIMINADO." -ForegroundColor Green
Write-Host (
    "Pruebas específicas: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Suite completa: " +
    "$($Full.passed)/$($Full.executed) APROBADA."
) -ForegroundColor Green
Write-Host "Autoevaluación SGD-114E: APROBADA." -ForegroundColor Green
Write-Host "Exit code: 0." -ForegroundColor Green
Write-Host "Release de mantenimiento: releases\SGD-114E-v2.0.0-R2.2" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
