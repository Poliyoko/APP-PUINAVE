<#
.SYNOPSIS
    SPT-019.3E v2.0.0 - Institutional PowerShell Remediation Engine.

.DESCRIPTION
    Motor institucional de remediacion para dejar cero errores de sintaxis
    PowerShell activos en SGODA-PUINAVE.

    El motor:
      - analiza todos los archivos .ps1 activos;
      - excluye .git, entornos virtuales, artifacts, releases y cuarentena;
      - preserva cada script invalido sin modificar su contenido;
      - calcula SHA-256 antes y despues;
      - mueve el script invalido a cuarentena;
      - cambia su extension a .ps1.failed.txt;
      - vuelve a analizar todos los scripts activos;
      - exige cero errores PowerShell;
      - compila Python;
      - ejecuta pytest completo;
      - genera manifiesto, evidencia, informe, acta y release candidato.

    Compatible con Windows PowerShell 5.1.
    No elimina evidencias.
    No instala n8n.
    No usa servicios de pago.
    No crea commits, tags ni publicaciones remotas.

.PARAMETER ProjectRoot
    Raiz del repositorio. Por defecto usa la carpeta actual.

.PARAMETER SkipFullSuite
    Omite pytest completo. Si se usa, el cierre queda bloqueado.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT019.3E-v2.0.0-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-019.3E"
$Version = "2.0.0"
$GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$CurrentScriptPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-AsciiFile {
    param(
        [string]$Path,
        [AllowEmptyString()][string]$Content
    )

    $Parent = Split-Path -Parent $Path
    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.Encoding]::ASCII
    )
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $Json = $Data | ConvertTo-Json -Depth 50
    Write-AsciiFile -Path $Path -Content ($Json + "`r`n")
}

function Get-RelativePathSafe {
    param(
        [string]$Root,
        [string]$Path
    )

    $RootFull = [System.IO.Path]::GetFullPath($Root)
    $PathFull = [System.IO.Path]::GetFullPath($Path)

    if (-not $RootFull.EndsWith("\")) {
        $RootFull = $RootFull + "\"
    }

    $RootUri = New-Object System.Uri($RootFull)
    $PathUri = New-Object System.Uri($PathFull)
    $Relative = $RootUri.MakeRelativeUri($PathUri).ToString()

    return [System.Uri]::UnescapeDataString($Relative).Replace("\", "/")
}

function Get-ActivePowerShellFiles {
    param([string]$Root)

    $AllFiles = @(
        Get-ChildItem `
            -LiteralPath $Root `
            -Recurse `
            -File `
            -Filter "*.ps1" `
            -Force `
            -ErrorAction SilentlyContinue
    )

    $Result = @()

    foreach ($File in $AllFiles) {
        $Relative = Get-RelativePathSafe -Root $Root -Path $File.FullName
        $Lower = "/" + $Relative.ToLowerInvariant() + "/"

        $Excluded = (
            $Lower.Contains("/.git/") -or
            $Lower.Contains("/.venv/") -or
            $Lower.Contains("/venv/") -or
            $Lower.Contains("/node_modules/") -or
            $Lower.Contains("/__pycache__/") -or
            $Lower.Contains("/.pytest_cache/") -or
            $Lower.Contains("/artifacts/") -or
            $Lower.Contains("/releases/") -or
            $Lower.Contains("/scripts/installers/quarantine/")
        )

        if (-not $Excluded) {
            $Result += $File
        }
    }

    return @($Result)
}

function Get-PowerShellSyntaxErrors {
    param([string]$Path)

    $Tokens = $null
    $Errors = $null

    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$Tokens,
        [ref]$Errors
    )

    return @($Errors)
}

function Get-UniqueQuarantinePath {
    param(
        [string]$Directory,
        [string]$SourceName
    )

    $BaseName = $SourceName + ".failed.txt"
    $Candidate = Join-Path $Directory $BaseName

    if (-not (Test-Path -LiteralPath $Candidate)) {
        return $Candidate
    }

    $Suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)
    return Join-Path $Directory ($SourceName + "." + $Suffix + ".failed.txt")
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

foreach ($Required in @("src", "tests", "docs", "artifacts", "releases")) {
    $RequiredPath = Join-Path $ProjectRoot $Required
    if (-not (Test-Path -LiteralPath $RequiredPath -PathType Container)) {
        throw "Falta la carpeta obligatoria: $Required"
    }
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python no esta disponible."
}

$ArtifactsRoot = Join-Path $ProjectRoot "artifacts\remediation\SPT-019.3E-v2.0.0"
$RunRoot = Join-Path $ArtifactsRoot "runs\$RunId"
$QuarantineRoot = Join-Path $ProjectRoot "scripts\installers\quarantine\SPT-019.3E-v2.0.0\$RunId"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-019.3"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-019.3E-v2.0.0"

foreach ($Directory in @($RunRoot, $QuarantineRoot, $DocsRoot, $ReleaseRoot)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

Write-Step "Validando sintaxis del motor SPT-019.3E"

$SelfErrors = @(Get-PowerShellSyntaxErrors -Path $CurrentScriptPath)
if (@($SelfErrors).Count -ne 0) {
    throw "El motor contiene errores de sintaxis y no puede ejecutarse."
}

Write-Host "Sintaxis del motor: APROBADA." -ForegroundColor Green

Write-Step "Inventariando PowerShell activo"

$BeforeFiles = @(Get-ActivePowerShellFiles -Root $ProjectRoot)
$BeforeErrors = @()
$InvalidFiles = @()

$Index = 0
$Total = @($BeforeFiles).Count

foreach ($File in $BeforeFiles) {
    $Index++

    if (($Index % 20) -eq 0 -or $Index -eq 1 -or $Index -eq $Total) {
        $Percent = if ($Total -gt 0) {
            [Math]::Round(($Index / $Total) * 100, 1)
        }
        else {
            100
        }

        Write-Progress `
            -Activity "Analizando scripts PowerShell" `
            -Status "$Index de $Total ($Percent %)" `
            -PercentComplete $Percent
    }

    $Errors = @(Get-PowerShellSyntaxErrors -Path $File.FullName)

    if (@($Errors).Count -gt 0) {
        $InvalidFiles += $File

        foreach ($ErrorItem in $Errors) {
            $BeforeErrors += [ordered]@{
                path = Get-RelativePathSafe -Root $ProjectRoot -Path $File.FullName
                line = $ErrorItem.Extent.StartLineNumber
                column = $ErrorItem.Extent.StartColumnNumber
                error_id = $ErrorItem.ErrorId
                message = $ErrorItem.Message
            }
        }
    }
}

Write-Progress -Activity "Analizando scripts PowerShell" -Completed

Write-Host "Scripts activos analizados: $(@($BeforeFiles).Count)"
Write-Host "Scripts invalidos detectados: $(@($InvalidFiles).Count)"
Write-Host "Errores detectados: $(@($BeforeErrors).Count)"

Write-Step "Aplicando cuarentena institucional"

$QuarantineRecords = @()

foreach ($InvalidFile in $InvalidFiles) {
    if ([System.IO.Path]::GetFullPath($InvalidFile.FullName) -eq $CurrentScriptPath) {
        throw "El motor actual no puede ponerse en cuarentena."
    }

    $RelativeSource = Get-RelativePathSafe -Root $ProjectRoot -Path $InvalidFile.FullName
    $Errors = @(Get-PowerShellSyntaxErrors -Path $InvalidFile.FullName)
    $BeforeHash = (Get-FileHash -LiteralPath $InvalidFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $DestinationPath = Get-UniqueQuarantinePath -Directory $QuarantineRoot -SourceName $InvalidFile.Name

    Move-Item `
        -LiteralPath $InvalidFile.FullName `
        -Destination $DestinationPath `
        -Force

    $AfterHash = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash.ToLowerInvariant()

    if ($BeforeHash -ne $AfterHash) {
        throw "La integridad SHA-256 cambio durante la cuarentena: $RelativeSource"
    }

    $ErrorDetails = @()

    foreach ($ErrorItem in $Errors) {
        $ErrorDetails += [ordered]@{
            line = $ErrorItem.Extent.StartLineNumber
            column = $ErrorItem.Extent.StartColumnNumber
            error_id = $ErrorItem.ErrorId
            message = $ErrorItem.Message
        }
    }

    $QuarantineRecords += [ordered]@{
        source = $RelativeSource
        quarantine = Get-RelativePathSafe -Root $ProjectRoot -Path $DestinationPath
        sha256 = $BeforeHash
        syntax_error_count = @($Errors).Count
        errors = $ErrorDetails
        preserved = $true
        executable = $false
    }

    Write-Host "Cuarentena: $RelativeSource" -ForegroundColor Yellow
}

$QuarantineManifestPath = Join-Path $RunRoot "quarantine-manifest.json"

Write-JsonFile -Path $QuarantineManifestPath -Data ([ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    run_id = $RunId
    scripts = $QuarantineRecords
})

Write-Step "Verificando cero errores PowerShell activos"

$AfterFiles = @(Get-ActivePowerShellFiles -Root $ProjectRoot)
$AfterErrors = @()

$Index = 0
$Total = @($AfterFiles).Count

foreach ($File in $AfterFiles) {
    $Index++

    if (($Index % 20) -eq 0 -or $Index -eq 1 -or $Index -eq $Total) {
        $Percent = if ($Total -gt 0) {
            [Math]::Round(($Index / $Total) * 100, 1)
        }
        else {
            100
        }

        Write-Progress `
            -Activity "Revalidando PowerShell activo" `
            -Status "$Index de $Total ($Percent %)" `
            -PercentComplete $Percent
    }

    $Errors = @(Get-PowerShellSyntaxErrors -Path $File.FullName)

    foreach ($ErrorItem in $Errors) {
        $AfterErrors += [ordered]@{
            path = Get-RelativePathSafe -Root $ProjectRoot -Path $File.FullName
            line = $ErrorItem.Extent.StartLineNumber
            column = $ErrorItem.Extent.StartColumnNumber
            error_id = $ErrorItem.ErrorId
            message = $ErrorItem.Message
        }
    }
}

Write-Progress -Activity "Revalidando PowerShell activo" -Completed

$ActiveErrorsPath = Join-Path $RunRoot "active-powershell-errors.json"
Write-JsonFile -Path $ActiveErrorsPath -Data $AfterErrors

Write-Step "Compilando Python"

$CompileLogPath = Join-Path $RunRoot "python-compileall.txt"
$CompileOutput = @(& python -m compileall -q src tests 2>&1)
$CompileExitCode = $LASTEXITCODE

Write-AsciiFile `
    -Path $CompileLogPath `
    -Content (($CompileOutput -join "`r`n") + "`r`n")

$TestRequested = -not $SkipFullSuite.IsPresent
$TestExecuted = $false
$TestPassed = $false
$TestExitCode = $null
$PytestLogPath = Join-Path $RunRoot "pytest-full-suite.txt"

if ($TestRequested) {
    Write-Step "Ejecutando suite completa"

    $env:PYTHONPATH = Join-Path $ProjectRoot "src"
    $PytestOutput = @(& python -m pytest -q 2>&1)
    $TestExitCode = $LASTEXITCODE
    $TestExecuted = $true
    $TestPassed = ($TestExitCode -eq 0)

    Write-AsciiFile `
        -Path $PytestLogPath `
        -Content (($PytestOutput -join "`r`n") + "`r`n")

    $PytestOutput | ForEach-Object { Write-Host $_ }
}
else {
    Write-Host "Suite completa omitida. El cierre queda bloqueado." -ForegroundColor Yellow
}

$ActiveErrorCount = @($AfterErrors).Count
$CompileErrorCount = if ($CompileExitCode -eq 0) { 0 } else { 1 }
$TestErrorCount = if ($TestPassed) { 0 } else { 1 }
$TechnicalErrors = $ActiveErrorCount + $CompileErrorCount + $TestErrorCount

$Approved = (
    $ActiveErrorCount -eq 0 -and
    $CompileExitCode -eq 0 -and
    $TestRequested -and
    $TestExecuted -and
    $TestPassed
)

$Status = if ($Approved) {
    "APPROVED_ZERO_ACTIVE_POWERSHELL_ERRORS"
}
else {
    "REMEDIATION_BLOCKED"
}

$Evidence = [ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    run_id = $RunId
    status = $Status
    approved = $Approved
    active_files_before = @($BeforeFiles).Count
    invalid_files_detected = @($InvalidFiles).Count
    syntax_errors_before = @($BeforeErrors).Count
    quarantined_scripts = @($QuarantineRecords).Count
    active_files_after = @($AfterFiles).Count
    active_syntax_errors_after = $ActiveErrorCount
    python_compile_exit_code = $CompileExitCode
    full_suite_requested = $TestRequested
    full_suite_executed = $TestExecuted
    full_suite_passed = $TestPassed
    full_suite_exit_code = $TestExitCode
    technical_errors = $TechnicalErrors
    quarantine_manifest = Get-RelativePathSafe -Root $ProjectRoot -Path $QuarantineManifestPath
    active_errors_report = Get-RelativePathSafe -Root $ProjectRoot -Path $ActiveErrorsPath
    historical_evidence_preserved = $true
    n8n_installed = $false
    paid_services_required = $false
    remote_publication_performed = $false
}

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
Write-JsonFile -Path $EvidencePath -Data $Evidence

$ReportPath = Join-Path $DocsRoot "SGD-424-PowerShell-Syntax-Remediation-v2.0.0.md"

$Report = @"
# SGD-424 - Institutional PowerShell Remediation Engine

| Field | Value |
|---|---|
| Component | $Component |
| Version | $Version |
| Status | $Status |
| Active files before | $(@($BeforeFiles).Count) |
| Invalid files detected | $(@($InvalidFiles).Count) |
| Syntax errors before | $(@($BeforeErrors).Count) |
| Quarantined scripts | $(@($QuarantineRecords).Count) |
| Active files after | $(@($AfterFiles).Count) |
| Active syntax errors after | $ActiveErrorCount |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $TestPassed |
| Technical errors | $TechnicalErrors |

Invalid historical scripts were preserved without content changes, verified
with SHA-256, moved to institutional quarantine and renamed with the extension
.ps1.failed.txt.
"@

Write-AsciiFile -Path $ReportPath -Content $Report

$ActPath = Join-Path $DocsRoot "ACT-019.3E-v2.0.0-Remediacion-PowerShell.md"

$ActStatus = if ($Approved) {
    "APPROVED - ZERO ACTIVE POWERSHELL SYNTAX ERRORS"
}
else {
    "NOT APPROVED - ERRORS PENDING"
}

$Act = @"
# ACT-019.3E - Institutional PowerShell Remediation Act

| Field | Value |
|---|---|
| Component | SPT-019.3E |
| Version | $Version |
| Status | $ActStatus |
| Quarantined scripts | $(@($QuarantineRecords).Count) |
| Active PowerShell syntax errors | $ActiveErrorCount |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $TestPassed |
| Technical errors | $TechnicalErrors |
| n8n installed | NO |
| Paid services | NO |
"@

Write-AsciiFile -Path $ActPath -Content $Act

$ReleaseManifest = [ordered]@{
    component = $Component
    version = $Version
    status = $Status
    approved = $Approved
    active_powershell_syntax_errors = $ActiveErrorCount
    python_compile_exit_code = $CompileExitCode
    full_suite_passed = $TestPassed
    technical_errors = $TechnicalErrors
    evidence = Get-RelativePathSafe -Root $ProjectRoot -Path $EvidencePath
    act = Get-RelativePathSafe -Root $ProjectRoot -Path $ActPath
    n8n_required = $false
    paid_services_required = $false
}

$ReleaseManifestPath = Join-Path $ReleaseRoot "manifest.json"
Write-JsonFile -Path $ReleaseManifestPath -Data $ReleaseManifest

Copy-Item `
    -LiteralPath $EvidencePath `
    -Destination (Join-Path $ReleaseRoot "implementation-evidence.json") `
    -Force

Copy-Item `
    -LiteralPath $QuarantineManifestPath `
    -Destination (Join-Path $ReleaseRoot "quarantine-manifest.json") `
    -Force

Copy-Item `
    -LiteralPath $ReportPath `
    -Destination (Join-Path $ReleaseRoot "SGD-424-PowerShell-Syntax-Remediation-v2.0.0.md") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-019.3E-v2.0.0-Remediacion-PowerShell.md") `
    -Force

Write-Step "Resultado final"

Write-Host "PowerShell activos antes: $(@($BeforeFiles).Count)"
Write-Host "Scripts invalidos detectados: $(@($InvalidFiles).Count)"
Write-Host "Errores PowerShell antes: $(@($BeforeErrors).Count)"
Write-Host "Scripts en cuarentena: $(@($QuarantineRecords).Count)"
Write-Host "PowerShell activos despues: $(@($AfterFiles).Count)"
Write-Host "PowerShell syntax errors activos: $ActiveErrorCount"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Pytest passed: $TestPassed"
Write-Host "Technical errors: $TechnicalErrors"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan

if ($Approved) {
    Write-Host "SPT-019.3E v2.0.0: APPROVED WITH ZERO ACTIVE POWERSHELL ERRORS." -ForegroundColor Green
}
else {
    Write-Host "SPT-019.3E v2.0.0: REMEDIATION BLOCKED." -ForegroundColor Red
    exit 1
}
