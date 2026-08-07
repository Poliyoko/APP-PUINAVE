<#
.SYNOPSIS
    SPT-020.8 - Zero Error Institutional Closure v1.0.1
    Optimized One File Installer for Windows PowerShell 5.1.

.DESCRIPTION
    Ejecuta el cierre institucional integral de SPT-020.

    Esta version optimiza la validacion JSON:
      - NO recorre masivamente artifacts/ ni releases/.
      - valida JSON activos en config/, src/, tests/ y docs/.
      - valida directamente las evidencias y manifiestos requeridos
        de SPT-020.1 a SPT-020.7.
      - preserva todas las evidencias historicas.

    Gates:
      - evidencias SPT-020.1 a SPT-020.7 conformes;
      - manifiestos de release conformes;
      - sintaxis PowerShell activa sin errores;
      - JSON institucional activo valido;
      - compilacion Python correcta;
      - suite completa aprobada;
      - cero errores tecnicos.

    Si todos los gates pasan:
      - SPT-020.1 a SPT-020.8 quedan CLOSED;
      - SPT-020 queda CLOSED;
      - se genera registro maestro de cierre;
      - se genera ACT-020.8;
      - se genera SGD-437;
      - se genera release institucional SPT-020-v1.0.0.

    No instala n8n.
    No usa servicios de pago.
    No publica en Git.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-020.8"
$Version = "1.0.1"
$ParentComponent = "SPT-020"
$ParentVersion = "1.0.0"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
$SelfPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-TextFile {
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
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $Json = $Data | ConvertTo-Json -Depth 60
    Write-TextFile -Path $Path -Content ($Json + "`r`n")
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

function Test-PowerShellSyntax {
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

function Test-JsonFile {
    param([string]$Path)

    try {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Get-LatestEvidencePath {
    param(
        [string]$Root,
        [string]$ComponentId
    )

    $RunsRoot = Join-Path $Root (
        "artifacts\development\" +
        $ComponentId +
        "-v1.0.0\runs"
    )

    if (-not (Test-Path -LiteralPath $RunsRoot -PathType Container)) {
        return $null
    }

    $Runs = @(
        Get-ChildItem `
            -LiteralPath $RunsRoot `
            -Directory `
            -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    )

    foreach ($Run in $Runs) {
        $Evidence = Join-Path $Run.FullName "implementation-evidence.json"
        if (Test-Path -LiteralPath $Evidence -PathType Leaf) {
            return $Evidence
        }
    }

    return $null
}

function Get-ActivePowerShellFiles {
    param([string]$Root)

    $CandidateRoots = @(
        $Root,
        (Join-Path $Root "scripts")
    )

    $Files = @()

    foreach ($CandidateRoot in $CandidateRoots) {
        if (-not (Test-Path -LiteralPath $CandidateRoot -PathType Container)) {
            continue
        }

        if ($CandidateRoot -eq $Root) {
            $Files += @(
                Get-ChildItem `
                    -LiteralPath $CandidateRoot `
                    -File `
                    -Filter "*.ps1" `
                    -ErrorAction SilentlyContinue
            )
        }
        else {
            $Files += @(
                Get-ChildItem `
                    -LiteralPath $CandidateRoot `
                    -Recurse `
                    -File `
                    -Filter "*.ps1" `
                    -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.FullName -notmatch "\\quarantine\\"
                }
            )
        }
    }

    return @(
        $Files |
        Sort-Object FullName -Unique
    )
}

function Get-ActiveJsonFiles {
    param([string]$Root)

    $Roots = @(
        (Join-Path $Root "config"),
        (Join-Path $Root "src"),
        (Join-Path $Root "tests"),
        (Join-Path $Root "docs")
    )

    $Files = @()

    foreach ($JsonRoot in $Roots) {
        if (-not (Test-Path -LiteralPath $JsonRoot -PathType Container)) {
            continue
        }

        $Files += @(
            Get-ChildItem `
                -LiteralPath $JsonRoot `
                -Recurse `
                -File `
                -Filter "*.json" `
                -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch "\\__pycache__\\" -and
                $_.FullName -notmatch "\\.pytest_cache\\"
            }
        )
    }

    return @(
        $Files |
        Sort-Object FullName -Unique
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

foreach ($Required in @(
    "src",
    "tests",
    "docs",
    "artifacts",
    "releases",
    "config"
)) {
    $RequiredPath = Join-Path $ProjectRoot $Required

    if (-not (Test-Path -LiteralPath $RequiredPath -PathType Container)) {
        throw "Falta la carpeta obligatoria: $Required"
    }
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python no esta disponible."
}

$SelfErrors = @(Test-PowerShellSyntax -Path $SelfPath)

if ($SelfErrors.Count -ne 0) {
    throw "El ejecutable contiene errores de sintaxis PowerShell."
}

$RunRoot = Join-Path $ProjectRoot (
    "artifacts\closure\SPT-020.8-v1.0.1\runs\" + $RunId
)
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-020.8"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-020-v1.0.0"
$RegistryRoot = Join-Path $ProjectRoot "config\platform"

foreach ($Directory in @(
    $RunRoot,
    $DocsRoot,
    $ReleaseRoot,
    $RegistryRoot
)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

$Components = @(
    "SPT-020.1",
    "SPT-020.2",
    "SPT-020.3",
    "SPT-020.4",
    "SPT-020.5",
    "SPT-020.6",
    "SPT-020.7"
)

Write-Step "Auditando evidencias y releases SPT-020.1 a SPT-020.7"

$ComponentAudit = @()
$ComponentAuditErrors = @()

foreach ($ComponentId in $Components) {
    Write-Host "  - $ComponentId" -ForegroundColor DarkCyan

    $EvidencePath = Get-LatestEvidencePath `
        -Root $ProjectRoot `
        -ComponentId $ComponentId

    $ReleaseManifestPath = Join-Path $ProjectRoot (
        "releases\" +
        $ComponentId +
        "-v1.0.0\manifest.json"
    )

    $EvidenceExists = (
        $null -ne $EvidencePath -and
        (Test-Path -LiteralPath $EvidencePath -PathType Leaf)
    )

    $ManifestExists = Test-Path `
        -LiteralPath $ReleaseManifestPath `
        -PathType Leaf

    $EvidenceValidJson = $false
    $ManifestValidJson = $false
    $EvidenceApproved = $false
    $EvidenceStatus = ""
    $ManifestStatus = ""

    if ($EvidenceExists) {
        $EvidenceValidJson = Test-JsonFile -Path $EvidencePath

        if ($EvidenceValidJson) {
            $Evidence = Get-Content `
                -LiteralPath $EvidencePath `
                -Raw |
                ConvertFrom-Json

            if ($Evidence.PSObject.Properties.Name -contains "status") {
                $EvidenceStatus = [string]$Evidence.status
            }

            if ($Evidence.PSObject.Properties.Name -contains "approved") {
                $EvidenceApproved = [bool]$Evidence.approved
            }
            elseif ($Evidence.PSObject.Properties.Name -contains "closed") {
                $EvidenceApproved = [bool]$Evidence.closed
            }
            else {
                $EvidenceApproved = (
                    $EvidenceStatus -eq "CLOSED" -or
                    $EvidenceStatus -eq "CANDIDATE_FOR_INSTITUTIONAL_CLOSURE"
                )
            }

            if (
                $Evidence.PSObject.Properties.Name -contains
                "component_tests_passed"
            ) {
                $EvidenceApproved = (
                    $EvidenceApproved -and
                    [bool]$Evidence.component_tests_passed
                )
            }

            if (
                $Evidence.PSObject.Properties.Name -contains
                "python_compile_exit_code"
            ) {
                $EvidenceApproved = (
                    $EvidenceApproved -and
                    ([int]$Evidence.python_compile_exit_code -eq 0)
                )
            }

            if (
                $Evidence.PSObject.Properties.Name -contains
                "full_suite_passed"
            ) {
                $EvidenceApproved = (
                    $EvidenceApproved -and
                    [bool]$Evidence.full_suite_passed
                )
            }

            if (
                $Evidence.PSObject.Properties.Name -contains
                "technical_errors"
            ) {
                $EvidenceApproved = (
                    $EvidenceApproved -and
                    ([int]$Evidence.technical_errors -eq 0)
                )
            }
        }
    }

    if ($ManifestExists) {
        $ManifestValidJson = Test-JsonFile -Path $ReleaseManifestPath

        if ($ManifestValidJson) {
            $Manifest = Get-Content `
                -LiteralPath $ReleaseManifestPath `
                -Raw |
                ConvertFrom-Json

            if ($Manifest.PSObject.Properties.Name -contains "status") {
                $ManifestStatus = [string]$Manifest.status
            }
        }
    }

    $ComponentConform = (
        $EvidenceExists -and
        $ManifestExists -and
        $EvidenceValidJson -and
        $ManifestValidJson -and
        $EvidenceApproved
    )

    if (-not $ComponentConform) {
        $ComponentAuditErrors += (
            $ComponentId +
            ": evidencia/release no conforme"
        )
    }

    $ComponentAudit += [ordered]@{
        component = $ComponentId
        evidence = if ($EvidenceExists) {
            Get-RelativePathSafe -Root $ProjectRoot -Path $EvidencePath
        }
        else {
            ""
        }
        evidence_exists = $EvidenceExists
        evidence_json_valid = $EvidenceValidJson
        evidence_status = $EvidenceStatus
        evidence_approved = $EvidenceApproved
        release_manifest = Get-RelativePathSafe `
            -Root $ProjectRoot `
            -Path $ReleaseManifestPath
        manifest_exists = $ManifestExists
        manifest_json_valid = $ManifestValidJson
        manifest_status = $ManifestStatus
        closure_status = if ($ComponentConform) {
            "CLOSED_BY_SPT-020.8"
        }
        else {
            "BLOCKED"
        }
        conform = $ComponentConform
    }
}

$ComponentAuditPath = Join-Path $RunRoot "component-closure-audit.json"
Write-JsonFile -Path $ComponentAuditPath -Data $ComponentAudit

Write-Step "Validando sintaxis PowerShell activa"

$PowerShellFiles = @(Get-ActivePowerShellFiles -Root $ProjectRoot)
$PowerShellErrors = @()

$Index = 0
foreach ($File in $PowerShellFiles) {
    $Index++
    if (($Index % 25) -eq 0) {
        Write-Host (
            "  PowerShell: {0}/{1}" -f $Index, $PowerShellFiles.Count
        ) -ForegroundColor DarkGray
    }

    $Errors = @(Test-PowerShellSyntax -Path $File.FullName)

    foreach ($ErrorItem in $Errors) {
        $PowerShellErrors += [ordered]@{
            path = Get-RelativePathSafe `
                -Root $ProjectRoot `
                -Path $File.FullName
            line = $ErrorItem.Extent.StartLineNumber
            column = $ErrorItem.Extent.StartColumnNumber
            error_id = $ErrorItem.ErrorId
            message = $ErrorItem.Message
        }
    }
}

$PowerShellErrorsPath = Join-Path $RunRoot "powershell-syntax-errors.json"
Write-JsonFile -Path $PowerShellErrorsPath -Data $PowerShellErrors

Write-Step "Validando JSON institucional activo"

$JsonFiles = @(Get-ActiveJsonFiles -Root $ProjectRoot)
$InvalidJson = @()

$Index = 0
foreach ($JsonFile in $JsonFiles) {
    $Index++
    if (($Index % 50) -eq 0) {
        Write-Host (
            "  JSON: {0}/{1}" -f $Index, $JsonFiles.Count
        ) -ForegroundColor DarkGray
    }

    if (-not (Test-JsonFile -Path $JsonFile.FullName)) {
        $InvalidJson += [ordered]@{
            path = Get-RelativePathSafe `
                -Root $ProjectRoot `
                -Path $JsonFile.FullName
        }
    }
}

$InvalidJsonPath = Join-Path $RunRoot "invalid-json-files.json"
Write-JsonFile -Path $InvalidJsonPath -Data $InvalidJson

Write-Step "Compilando Python"

$CompileOutput = @(& python -m compileall -q src tests 2>&1)
$CompileExitCode = $LASTEXITCODE
$CompileLogPath = Join-Path $RunRoot "python-compileall.txt"

Write-TextFile `
    -Path $CompileLogPath `
    -Content (($CompileOutput -join "`r`n") + "`r`n")

Write-Step "Ejecutando suite completa"

$env:PYTHONPATH = Join-Path $ProjectRoot "src"
$PytestOutput = @(& python -m pytest -q 2>&1)
$PytestExitCode = $LASTEXITCODE
$PytestPassed = ($PytestExitCode -eq 0)
$PytestLogPath = Join-Path $RunRoot "pytest-full-suite.txt"

Write-TextFile `
    -Path $PytestLogPath `
    -Content (($PytestOutput -join "`r`n") + "`r`n")

$PytestOutput | ForEach-Object { Write-Host $_ }

$TechnicalErrors = (
    @($ComponentAuditErrors).Count +
    @($PowerShellErrors).Count +
    @($InvalidJson).Count +
    $(if ($CompileExitCode -eq 0) { 0 } else { 1 }) +
    $(if ($PytestPassed) { 0 } else { 1 })
)

$Closed = ($TechnicalErrors -eq 0)

$FinalStatus = if ($Closed) {
    "CLOSED"
}
else {
    "CLOSURE_BLOCKED"
}

$ComponentClosureRegistry = @()

foreach ($Audit in $ComponentAudit) {
    $ComponentClosureRegistry += [ordered]@{
        component = $Audit.component
        version = "1.0.0"
        final_status = if ($Closed -and $Audit.conform) {
            "CLOSED"
        }
        else {
            "BLOCKED"
        }
        closed_by = $Component
        closure_run = $RunId
        evidence = $Audit.evidence
        release_manifest = $Audit.release_manifest
    }
}

$ComponentClosureRegistry += [ordered]@{
    component = $Component
    version = $Version
    final_status = $FinalStatus
    closed_by = $Component
    closure_run = $RunId
    evidence = "artifacts/closure/SPT-020.8-v1.0.1/runs/$RunId/zero-error-report.json"
    release_manifest = "releases/SPT-020-v1.0.0/manifest.json"
}

$MasterRegistryPath = Join-Path $RegistryRoot "SPT-020-closure-registry.json"

Write-JsonFile `
    -Path $MasterRegistryPath `
    -Data ([ordered]@{
        parent_component = $ParentComponent
        version = $ParentVersion
        generated_at_utc = $GeneratedUtc
        closure_run = $RunId
        final_status = $FinalStatus
        components = $ComponentClosureRegistry
    })

$ZeroErrorReport = [ordered]@{
    component = $Component
    version = $Version
    parent_component = $ParentComponent
    parent_version = $ParentVersion
    generated_at_utc = $GeneratedUtc
    run_id = $RunId
    status = $FinalStatus
    closed = $Closed
    components_audited = @($ComponentAudit).Count
    component_audit_errors = @($ComponentAuditErrors).Count
    active_powershell_files = @($PowerShellFiles).Count
    powershell_syntax_errors = @($PowerShellErrors).Count
    active_json_files_validated = @($JsonFiles).Count
    invalid_json_files = @($InvalidJson).Count
    python_compile_exit_code = $CompileExitCode
    pytest_exit_code = $PytestExitCode
    pytest_passed = $PytestPassed
    technical_errors = $TechnicalErrors
    n8n_installed = $false
    paid_services_required = $false
    external_infrastructure_required = $false
    component_audit = $ComponentAudit
}

$ZeroErrorReportPath = Join-Path $RunRoot "zero-error-report.json"
Write-JsonFile -Path $ZeroErrorReportPath -Data $ZeroErrorReport

$ActStatus = if ($Closed) {
    "CLOSED - ZERO TECHNICAL ERRORS"
}
else {
    "CLOSURE BLOCKED"
}

$Act = @"
# ACT-020.8 - Zero Error Institutional Closure

| Field | Value |
|---|---|
| Parent component | SPT-020 |
| Closure component | SPT-020.8 |
| Version | $Version |
| Status | $ActStatus |
| Components audited | $(@($ComponentAudit).Count) |
| Component audit errors | $(@($ComponentAuditErrors).Count) |
| PowerShell syntax errors | $(@($PowerShellErrors).Count) |
| Active JSON files validated | $(@($JsonFiles).Count) |
| Invalid JSON files | $(@($InvalidJson).Count) |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $PytestPassed |
| Technical errors | $TechnicalErrors |
| n8n installed | NO |
| Paid services | NO |
| External infrastructure required | NO |

This closure preserves historical evidence and validates only active
institutional JSON plus the exact evidences and manifests required for
SPT-020.1 through SPT-020.7.
"@

$ActPath = Join-Path $DocsRoot "ACT-020.8-Cierre-Institucional-Cero-Errores.md"
Write-TextFile -Path $ActPath -Content $Act

$ReportDoc = @"
# SGD-437 - SPT-020 Zero Error Institutional Closure Report

| Control | Result |
|---|---|
| Final status | $FinalStatus |
| Components audited | $(@($ComponentAudit).Count) |
| Component audit errors | $(@($ComponentAuditErrors).Count) |
| Active PowerShell files | $(@($PowerShellFiles).Count) |
| PowerShell syntax errors | $(@($PowerShellErrors).Count) |
| Active JSON files validated | $(@($JsonFiles).Count) |
| Invalid JSON files | $(@($InvalidJson).Count) |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $PytestPassed |
| Technical errors | $TechnicalErrors |
"@

$ReportDocPath = Join-Path $DocsRoot "SGD-437-SPT-020-Zero-Error-Closure.md"
Write-TextFile -Path $ReportDocPath -Content $ReportDoc

$ReleaseManifest = [ordered]@{
    component = $ParentComponent
    version = $ParentVersion
    closure_component = $Component
    closure_version = $Version
    status = $FinalStatus
    closed = $Closed
    technical_errors = $TechnicalErrors
    zero_error_report = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $ZeroErrorReportPath
    closure_act = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $ActPath
    closure_registry = Get-RelativePathSafe `
        -Root $ProjectRoot `
        -Path $MasterRegistryPath
    n8n_required = $false
    paid_services_required = $false
    external_infrastructure_required = $false
}

$ReleaseManifestPath = Join-Path $ReleaseRoot "manifest.json"
Write-JsonFile -Path $ReleaseManifestPath -Data $ReleaseManifest

Copy-Item `
    -LiteralPath $ZeroErrorReportPath `
    -Destination (Join-Path $ReleaseRoot "zero-error-report.json") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-020.8-Cierre-Institucional-Cero-Errores.md") `
    -Force

Copy-Item `
    -LiteralPath $ReportDocPath `
    -Destination (Join-Path $ReleaseRoot "SGD-437-SPT-020-Zero-Error-Closure.md") `
    -Force

Copy-Item `
    -LiteralPath $MasterRegistryPath `
    -Destination (Join-Path $ReleaseRoot "SPT-020-closure-registry.json") `
    -Force

Write-Step "Resultado final"

Write-Host "Components audited: $(@($ComponentAudit).Count)"
Write-Host "Component audit errors: $(@($ComponentAuditErrors).Count)"
Write-Host "PowerShell syntax errors: $(@($PowerShellErrors).Count)"
Write-Host "Active JSON files validated: $(@($JsonFiles).Count)"
Write-Host "Invalid JSON files: $(@($InvalidJson).Count)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Pytest passed: $PytestPassed"
Write-Host "Technical errors: $TechnicalErrors"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Closure registry: $MasterRegistryPath" -ForegroundColor Cyan
Write-Host "Report: $ZeroErrorReportPath" -ForegroundColor Cyan
Write-Host "Act: $ActPath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Institutional status: $FinalStatus" -ForegroundColor Cyan

if ($Closed) {
    Write-Host "SPT-020.8: CLOSED WITH ZERO TECHNICAL ERRORS." -ForegroundColor Green
    Write-Host "SPT-020: INSTITUTIONALLY CLOSED." -ForegroundColor Green
}
else {
    Write-Host "SPT-020.8: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
