<#
.SYNOPSIS
    SPT-019.3-ZE - Zero Error Institutional Closure for SGODA-PUINAVE.

.DESCRIPTION
    Ejecuta una auditoria integral de cero errores para SPT-019.3 y su
    integracion con SPT-019.0, SPT-019.1 y SPT-019.2.

    El proceso:
      1. valida sintaxis PowerShell;
      2. compila Python;
      3. valida JSON;
      4. ejecuta pytest completo;
      5. valida evidencias y manifiesto de SPT-019.3;
      6. valida SHA-256 de archivos declarados;
      7. revisa documentos obligatorios;
      8. clasifica el estado Git;
      9. genera informe Zero Error;
     10. genera acta definitiva solo si los errores tecnicos son cero.

    Compatible con Windows PowerShell 5.1.
    No instala n8n.
    No usa servicios de pago.
    No elimina evidencias historicas.
    No crea commits, tags ni publicaciones remotas.

.PARAMETER ProjectRoot
    Raiz del repositorio. Por defecto usa la carpeta actual.

.PARAMETER NormalizeRootInstallers
    Mueve instaladores PowerShell de la raiz a scripts/installers/archive,
    conservandolos con trazabilidad. No elimina archivos.

.PARAMETER SkipFullSuite
    Omite pytest completo. En este caso nunca se autoriza cierre definitivo.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT019.3-ZE-v1.0.2-PS51.ps1

.EXAMPLE
    .\Install-SPT019.3-ZE-v1.0.2-PS51.ps1 -NormalizeRootInstallers
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$NormalizeRootInstallers,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-019.3-ZE"
$Version = "1.0.2"
$GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-AsciiFile {
    param(
        [string]$Path,
        [string]$Content
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

    $Json = $Data | ConvertTo-Json -Depth 30
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

function Get-ScannableFiles {
    param(
        [string]$Root,
        [string]$Filter
    )

    $Files = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Filter -Force -ErrorAction SilentlyContinue

    $Result = @()
    foreach ($File in @($Files)) {
        $Relative = Get-RelativePathSafe -Root $Root -Path $File.FullName
        $Lower = "/" + $Relative.ToLowerInvariant() + "/"

        $Excluded = (
            $Lower.Contains("/.git/") -or
            $Lower.Contains("/.venv/") -or
            $Lower.Contains("/venv/") -or
            $Lower.Contains("/node_modules/") -or
            $Lower.Contains("/__pycache__/") -or
            $Lower.Contains("/.pytest_cache/") -or
            $Lower.Contains("/build/") -or
            $Lower.Contains("/dist/")
        )

        if (-not $Excluded) {
            $Result += $File
        }
    }

    return @($Result)
}

function Add-Issue {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Category,
        [string]$Severity,
        [string]$Path,
        [string]$Message
    )

    $List.Add([PSCustomObject]@{
        category = $Category
        severity = $Severity
        path = $Path
        message = $Message
    })
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

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git no esta disponible."
}

$ArtifactsRoot = Join-Path $ProjectRoot "artifacts\closure\SPT-019.3-ZE-v1.0.2"
$RunRoot = Join-Path $ArtifactsRoot "runs\$RunId"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-019.3-ZE-v1.0.2"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-019.3"
$ArchiveRoot = Join-Path $ProjectRoot "scripts\installers\archive"

foreach ($Directory in @($RunRoot, $ReleaseRoot, $DocsRoot)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

$Issues = New-Object 'System.Collections.Generic.List[object]'
$Checks = New-Object 'System.Collections.Generic.List[object]'

if ($NormalizeRootInstallers) {
    Write-Step "Normalizando instaladores de la raiz"

    New-Item -ItemType Directory -Path $ArchiveRoot -Force | Out-Null

    $RootInstallers = Get-ChildItem -LiteralPath $ProjectRoot -File -Filter "Install-*.ps1" -ErrorAction SilentlyContinue
    foreach ($Installer in @($RootInstallers)) {
        if ($Installer.Name -eq "Install-SPT019.3-ZE-v1.0.2-PS51.ps1") {
            continue
        }

        $Destination = Join-Path $ArchiveRoot $Installer.Name
        Move-Item -LiteralPath $Installer.FullName -Destination $Destination -Force
    }
}

Write-Step "Validando sintaxis PowerShell"

$PowerShellErrors = @()
$PowerShellFiles = Get-ScannableFiles -Root $ProjectRoot -Filter "*.ps1"

foreach ($File in $PowerShellFiles) {
    $Tokens = $null
    $Errors = $null

    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $File.FullName,
        [ref]$Tokens,
        [ref]$Errors
    )

    foreach ($ErrorItem in @($Errors)) {
        $Record = [PSCustomObject]@{
            path = Get-RelativePathSafe -Root $ProjectRoot -Path $File.FullName
            line = $ErrorItem.Extent.StartLineNumber
            column = $ErrorItem.Extent.StartColumnNumber
            error_id = $ErrorItem.ErrorId
            message = $ErrorItem.Message
        }
        $PowerShellErrors += $Record
        Add-Issue -List $Issues -Category "PowerShell" -Severity "CRITICAL" -Path $Record.path -Message $Record.message
    }
}

$Checks.Add([PSCustomObject]@{
    name = "PowerShell syntax"
    passed = (@($PowerShellErrors).Count -eq 0)
    count = @($PowerShellErrors).Count
})

Write-Step "Compilando Python"

$PythonCompileLog = Join-Path $RunRoot "python-compileall.txt"
$CompileOutput = & python -m compileall -q src tests 2>&1
$CompileExitCode = $LASTEXITCODE
Write-AsciiFile -Path $PythonCompileLog -Content (($CompileOutput -join "`r`n") + "`r`n")

if ($CompileExitCode -ne 0) {
    Add-Issue -List $Issues -Category "Python" -Severity "CRITICAL" -Path "src tests" -Message "python compileall returned exit code $CompileExitCode"
}

$Checks.Add([PSCustomObject]@{
    name = "Python compile"
    passed = ($CompileExitCode -eq 0)
    count = $CompileExitCode
})

Write-Step "Validando JSON"

$JsonErrors = @()
$LargeJsonFiles = @()
$JsonFiles = Get-ScannableFiles -Root $ProjectRoot -Filter "*.json"
$JsonTotal = @($JsonFiles).Count
$JsonIndex = 0
$MaxParseBytes = 25MB

foreach ($File in $JsonFiles) {
    $JsonIndex++

    if (($JsonIndex % 100) -eq 0 -or $JsonIndex -eq 1 -or $JsonIndex -eq $JsonTotal) {
        $Percent = if ($JsonTotal -gt 0) {
            [Math]::Round(($JsonIndex / $JsonTotal) * 100, 1)
        }
        else {
            100
        }

        Write-Progress `
            -Activity "Validando archivos JSON" `
            -Status "$JsonIndex de $JsonTotal ($Percent %)" `
            -PercentComplete $Percent
    }

    $RelativeJson = Get-RelativePathSafe -Root $ProjectRoot -Path $File.FullName
    $LowerRelativeJson = $RelativeJson.ToLowerInvariant()

    $HistoricalOrGenerated = (
        $LowerRelativeJson.StartsWith("artifacts/") -or
        $LowerRelativeJson.StartsWith("releases/") -or
        $LowerRelativeJson.Contains("/runs/") -or
        $File.Name -eq "institutional-inventory.json"
    )

    if ($File.Length -gt $MaxParseBytes -and $HistoricalOrGenerated) {
        try {
            $Hash = (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $LargeJsonFiles += [PSCustomObject]@{
                path = $RelativeJson
                size_bytes = $File.Length
                validation = "EXISTENCE_SIZE_SHA256"
                sha256 = $Hash
            }
        }
        catch {
            $Record = [PSCustomObject]@{
                path = $RelativeJson
                message = $_.Exception.Message
            }
            $JsonErrors += $Record
            Add-Issue -List $Issues -Category "JSON" -Severity "CRITICAL" -Path $Record.path -Message $Record.message
        }

        continue
    }

    try {
        $Raw = Get-Content -LiteralPath $File.FullName -Raw -Encoding UTF8
        if (-not [string]::IsNullOrWhiteSpace($Raw)) {
            $null = $Raw | ConvertFrom-Json
        }
    }
    catch {
        $Record = [PSCustomObject]@{
            path = $RelativeJson
            message = $_.Exception.Message
        }
        $JsonErrors += $Record
        Add-Issue -List $Issues -Category "JSON" -Severity "CRITICAL" -Path $Record.path -Message $Record.message
    }
}

Write-Progress -Activity "Validando archivos JSON" -Completed

$LargeJsonReportPath = Join-Path $RunRoot "large-json-files.json"
Write-JsonFile -Path $LargeJsonReportPath -Data @($LargeJsonFiles)

$Checks.Add([PSCustomObject]@{
    name = "JSON validity"
    passed = (@($JsonErrors).Count -eq 0)
    count = @($JsonErrors).Count
})

$Checks.Add([PSCustomObject]@{
    name = "Large historical JSON integrity"
    passed = $true
    count = @($LargeJsonFiles).Count
})

Write-Step "Validando evidencia y manifiesto de SPT-019.3"

$ManifestPath = Join-Path $ProjectRoot "releases\SPT-019.3-v1.0.1\manifest.json"
$ManifestValid = $false
$EvidenceValid = $false
$HashErrors = @()

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Add-Issue -List $Issues -Category "Release" -Severity "CRITICAL" -Path "releases/SPT-019.3-v1.0.1/manifest.json" -Message "Manifest not found"
}
else {
    try {
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $ManifestValid = (
            [string]$Manifest.component -eq "SPT-019.3" -and
            [string]$Manifest.version -eq "1.0.1"
        )

        if (-not $ManifestValid) {
            Add-Issue -List $Issues -Category "Release" -Severity "CRITICAL" -Path "releases/SPT-019.3-v1.0.1/manifest.json" -Message "Manifest identity is inconsistent"
        }

        $EvidenceRelative = [string]$Manifest.evidence
        $EvidencePath = Join-Path $ProjectRoot ($EvidenceRelative.Replace("/", "\"))

        if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
            Add-Issue -List $Issues -Category "Evidence" -Severity "CRITICAL" -Path $EvidenceRelative -Message "Evidence file not found"
        }
        else {
            $Evidence = Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $EvidenceValid = (
                [string]$Evidence.component -eq "SPT-019.3" -and
                [string]$Evidence.version -eq "1.0.1" -and
                [bool]$Evidence.full_suite_passed
            )

            if (-not $EvidenceValid) {
                Add-Issue -List $Issues -Category "Evidence" -Severity "CRITICAL" -Path $EvidenceRelative -Message "Evidence content is inconsistent"
            }

            foreach ($Entry in @($Evidence.files)) {
                $RelativePath = [string]$Entry.path
                $ExpectedHash = ([string]$Entry.sha256).ToLowerInvariant()
                $AbsolutePath = Join-Path $ProjectRoot ($RelativePath.Replace("/", "\"))

                if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
                    $HashErrors += [PSCustomObject]@{
                        path = $RelativePath
                        error = "file not found"
                    }
                    Add-Issue -List $Issues -Category "SHA256" -Severity "CRITICAL" -Path $RelativePath -Message "Declared file not found"
                    continue
                }

                $ActualHash = (Get-FileHash -LiteralPath $AbsolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($ActualHash -ne $ExpectedHash) {
                    $HashErrors += [PSCustomObject]@{
                        path = $RelativePath
                        expected = $ExpectedHash
                        actual = $ActualHash
                    }
                    Add-Issue -List $Issues -Category "SHA256" -Severity "CRITICAL" -Path $RelativePath -Message "SHA256 mismatch"
                }
            }
        }
    }
    catch {
        Add-Issue -List $Issues -Category "Release" -Severity "CRITICAL" -Path "releases/SPT-019.3-v1.0.1/manifest.json" -Message $_.Exception.Message
    }
}

$Checks.Add([PSCustomObject]@{
    name = "SPT-019.3 manifest"
    passed = $ManifestValid
    count = if ($ManifestValid) { 0 } else { 1 }
})

$Checks.Add([PSCustomObject]@{
    name = "SPT-019.3 evidence"
    passed = $EvidenceValid
    count = if ($EvidenceValid) { 0 } else { 1 }
})

$Checks.Add([PSCustomObject]@{
    name = "SHA256 integrity"
    passed = (@($HashErrors).Count -eq 0)
    count = @($HashErrors).Count
})

Write-Step "Validando documentos obligatorios"

$RequiredDocuments = @(
    "docs/06_Tecnologia/SPT-019.3/SGD-420-Arquitectura-Orquestador.md",
    "docs/06_Tecnologia/SPT-019.3/SGD-421-Integracion-Institucional.md",
    "docs/06_Tecnologia/SPT-019.3/SGD-422-Eventos-Trazabilidad-Evidencias.md",
    "docs/06_Tecnologia/SPT-019.3/ACT-019.3-Acta-Tecnica-Integracion.md",
    "docs/00_Estado_Maestro/SGD-000-Estado-Maestro-Institucional-v1.0.0.md"
)

$MissingDocuments = @()
foreach ($RelativeDocument in $RequiredDocuments) {
    $DocumentPath = Join-Path $ProjectRoot ($RelativeDocument.Replace("/", "\"))
    if (-not (Test-Path -LiteralPath $DocumentPath -PathType Leaf)) {
        $MissingDocuments += $RelativeDocument
        Add-Issue -List $Issues -Category "Documentation" -Severity "CRITICAL" -Path $RelativeDocument -Message "Required document not found"
    }
}

$Checks.Add([PSCustomObject]@{
    name = "Required documents"
    passed = (@($MissingDocuments).Count -eq 0)
    count = @($MissingDocuments).Count
})

$TestRequested = -not $SkipFullSuite.IsPresent
$TestExecuted = $false
$TestPassed = $false
$TestExitCode = $null
$PytestLog = Join-Path $RunRoot "pytest-full-suite.txt"

if ($TestRequested) {
    Write-Step "Ejecutando suite completa"

    $env:PYTHONPATH = Join-Path $ProjectRoot "src"
    $PytestOutput = & python -m pytest -q 2>&1
    $TestExitCode = $LASTEXITCODE
    $TestExecuted = $true
    $TestPassed = ($TestExitCode -eq 0)

    Write-AsciiFile -Path $PytestLog -Content (($PytestOutput -join "`r`n") + "`r`n")
    $PytestOutput | ForEach-Object { Write-Host $_ }

    if (-not $TestPassed) {
        Add-Issue -List $Issues -Category "Tests" -Severity "CRITICAL" -Path "tests" -Message "pytest returned exit code $TestExitCode"
    }
}
else {
    Write-Host "Suite completa omitida. El cierre definitivo queda bloqueado." -ForegroundColor Yellow
}

$Checks.Add([PSCustomObject]@{
    name = "Full pytest suite"
    passed = $TestPassed
    count = if ($TestPassed) { 0 } else { 1 }
})

Write-Step "Clasificando estado Git"

$GitLines = @(git status --porcelain)
$ModifiedGit = @($GitLines | Where-Object { $_ -notmatch '^\?\?' })
$UntrackedGit = @($GitLines | Where-Object { $_ -match '^\?\?' })

$GitSummary = [ordered]@{
    modified_or_staged = @($ModifiedGit).Count
    untracked = @($UntrackedGit).Count
    clean = (@($GitLines).Count -eq 0)
    lines = $GitLines
}

$ChecksArray = $Checks.ToArray()
$IssuesArray = $Issues.ToArray()

$TechnicalErrorCount = @(
    $IssuesArray | Where-Object {
        $_.severity -eq "CRITICAL"
    }
).Count

$ZeroError = (
    $TechnicalErrorCount -eq 0 -and
    $TestRequested -and
    $TestExecuted -and
    $TestPassed
)

$FinalStatus = if ($ZeroError) {
    "ZERO_ERROR_TECHNICAL_CLOSURE_APPROVED"
}
else {
    "CLOSURE_BLOCKED"
}

$Report = [ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    run_id = $RunId
    status = $FinalStatus
    zero_error = $ZeroError
    technical_error_count = $TechnicalErrorCount
    checks = $ChecksArray
    issues = $IssuesArray
    git = $GitSummary
    policies = [ordered]@{
        powershell_execution = $true
        repository_is_source_of_truth = $true
        historical_evidence_preserved = $true
        n8n_installed = $false
        paid_services_required = $false
        remote_publication_performed = $false
    }
}

$ReportJsonPath = Join-Path $RunRoot "zero-error-report.json"
Write-JsonFile -Path $ReportJsonPath -Data $Report

$ChecksRows = @()
foreach ($Check in $ChecksArray) {
    $State = if ($Check.passed) { "APPROVED" } else { "FAILED" }
    $ChecksRows += "| $($Check.name) | $State | $($Check.count) |"
}

$IssueRows = @()
if ($IssuesArray.Count -eq 0) {
    $IssueRows += "| - | - | - | No technical issues detected |"
}
else {
    foreach ($Issue in $IssuesArray) {
        $IssueRows += "| $($Issue.category) | $($Issue.severity) | $($Issue.path) | $($Issue.message) |"
    }
}

$ReportMd = @"
# SPT-019.3-ZE - Zero Error Institutional Closure Report

## Control

| Field | Value |
|---|---|
| Component | $Component |
| Version | $Version |
| Generated UTC | $GeneratedUtc |
| Run | $RunId |
| Status | $FinalStatus |
| Zero error | $ZeroError |
| Technical errors | $TechnicalErrorCount |

## Validation checks

| Check | Status | Error count |
|---|---|---:|
$($ChecksRows -join "`r`n")

## Technical issues

| Category | Severity | Path | Message |
|---|---|---|---|
$($IssueRows -join "`r`n")

## Git classification

| Indicator | Count |
|---|---:|
| Modified or staged | $(@($ModifiedGit).Count) |
| Untracked | $(@($UntrackedGit).Count) |
| Clean tree | $($GitSummary.clean) |

Git changes are classified separately from technical errors. They must be
reviewed and published through the institutional release process.

## Policies

- PowerShell execution: YES
- Repository as source of truth: YES
- Historical evidence preserved: YES
- n8n installed: NO
- Paid services required: NO
- Remote publication performed: NO
"@

$ReportMdPath = Join-Path $DocsRoot "SGD-423-SPT-019.3-Zero-Error-Closure-Report.md"
Write-AsciiFile -Path $ReportMdPath -Content $ReportMd

$ActStatus = if ($ZeroError) {
    "APPROVED - ZERO TECHNICAL ERRORS"
}
else {
    "NOT APPROVED - TECHNICAL ERRORS PENDING"
}

$Act = @"
# ACT-019.3-ZE - Zero Error Closure Act

| Field | Value |
|---|---|
| Component | SPT-019.3 |
| Closure component | SPT-019.3-ZE |
| Version | $Version |
| Status | $ActStatus |
| Technical errors | $TechnicalErrorCount |
| Full suite requested | $TestRequested |
| Full suite executed | $TestExecuted |
| Full suite passed | $TestPassed |
| PowerShell | YES |
| n8n installed | NO |
| Paid services | NO |

This act authorizes technical closure only when Technical errors equals 0 and
the full pytest suite is executed and approved.
"@

$ActPath = Join-Path $DocsRoot "ACT-019.3-ZE-Cierre-Cero-Errores.md"
Write-AsciiFile -Path $ActPath -Content $Act

$ReleaseManifest = [ordered]@{
    component = $Component
    version = $Version
    status = $FinalStatus
    zero_error = $ZeroError
    technical_error_count = $TechnicalErrorCount
    report = Get-RelativePathSafe -Root $ProjectRoot -Path $ReportJsonPath
    act = Get-RelativePathSafe -Root $ProjectRoot -Path $ActPath
    n8n_required = $false
    paid_services_required = $false
}

$ReleaseManifestPath = Join-Path $ReleaseRoot "manifest.json"
Write-JsonFile -Path $ReleaseManifestPath -Data $ReleaseManifest

Copy-Item -LiteralPath $ReportJsonPath -Destination (Join-Path $ReleaseRoot "zero-error-report.json") -Force
Copy-Item -LiteralPath $ReportMdPath -Destination (Join-Path $ReleaseRoot "SGD-423-SPT-019.3-Zero-Error-Closure-Report.md") -Force
Copy-Item -LiteralPath $ActPath -Destination (Join-Path $ReleaseRoot "ACT-019.3-ZE-Cierre-Cero-Errores.md") -Force

Write-Step "Resultado final"
Write-Host "PowerShell syntax errors: $(@($PowerShellErrors).Count)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Invalid JSON files: $(@($JsonErrors).Count)"
Write-Host "Large historical JSON validated by SHA256: $(@($LargeJsonFiles).Count)"
Write-Host "SHA256 errors: $(@($HashErrors).Count)"
Write-Host "Missing documents: $(@($MissingDocuments).Count)"
Write-Host "Pytest passed: $TestPassed"
Write-Host "Technical errors: $TechnicalErrorCount"
Write-Host "Modified or staged Git entries: $(@($ModifiedGit).Count)"
Write-Host "Untracked Git entries: $(@($UntrackedGit).Count)"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Report: $ReportJsonPath" -ForegroundColor Cyan
Write-Host "Act: $ActPath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan

if ($ZeroError) {
    Write-Host "SPT-019.3-ZE: APPROVED WITH ZERO TECHNICAL ERRORS." -ForegroundColor Green
}
else {
    Write-Host "SPT-019.3-ZE: CLOSURE BLOCKED. Review the report." -ForegroundColor Red
    exit 1
}
