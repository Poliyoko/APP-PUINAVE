param(
    [string]$ProjectRoot = "",
    [string]$ExpectedPublishedHead = "94b7d91aab208dba922d2551574968f4b60fbf3c"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Stop-Verification {
    param([string]$Message)

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host " SPT-023.3 CAPA 1 FINAL VERIFICATION : HOLD" -ForegroundColor Red
    Write-Host (" " + $Message) -ForegroundColor Red
    Write-Host " NO COMMIT / NO PUSH" -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Red
    exit 20
}

function Invoke-GitSingleLine {
    param([string[]]$GitArguments)

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Output = @(& git @GitArguments 2>&1)
        $Code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }

    if ($Code -ne 0) {
        throw ("git " + ($GitArguments -join " ") + " failed: " + ($Output -join " "))
    }

    if ($Output.Count -eq 0) {
        throw ("git " + ($GitArguments -join " ") + " returned no output.")
    }

    return ([string]($Output | Select-Object -First 1)).Trim()
}

function Invoke-GitLines {
    param([string[]]$GitArguments)

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Output = @(& git @GitArguments 2>&1)
        $Code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }

    if ($Code -ne 0) {
        throw ("git " + ($GitArguments -join " ") + " failed: " + ($Output -join " "))
    }

    foreach ($Line in $Output) {
        [string]$Line
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = Invoke-GitSingleLine @("rev-parse","--show-toplevel")
    }

    Set-Location $ProjectRoot

    $Root = Invoke-GitSingleLine @("rev-parse","--show-toplevel")
    $Branch = Invoke-GitSingleLine @("branch","--show-current")
    $Origin = Invoke-GitSingleLine @("remote","get-url","origin")

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host " SGODA-PUINAVE - SPT-023.3 CAPA 1 FINAL CLOSURE VERIFICATION" -ForegroundColor Cyan
    Write-Host " VERIFY ONLY / NO COMMIT / NO PUSH" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "[1/5] REMOTE SYNCHRONIZATION CHECK" -ForegroundColor Yellow

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git fetch origin $Branch --no-tags
        $FetchCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }

    if ($FetchCode -ne 0) {
        Stop-Verification "Unable to fetch official remote."
    }

    $LocalHead = Invoke-GitSingleLine @("rev-parse","HEAD")
    $RemoteHead = Invoke-GitSingleLine @("rev-parse","origin/$Branch")

    Write-Host "LOCAL HEAD  : $LocalHead"
    Write-Host "REMOTE HEAD : $RemoteHead"

    if ($LocalHead -ne $ExpectedPublishedHead) {
        Stop-Verification "Local HEAD is not the published SPT-023.3 Capa 1 commit."
    }

    if ($RemoteHead -ne $ExpectedPublishedHead) {
        Stop-Verification "Remote HEAD is not the published SPT-023.3 Capa 1 commit."
    }

    Write-Host ""
    Write-Host "[2/5] DIVERGENCE / INDEX CHECK" -ForegroundColor Yellow

    $AheadLines = @(Invoke-GitLines @("rev-list","origin/$Branch..HEAD"))
    $BehindLines = @(Invoke-GitLines @("rev-list","HEAD..origin/$Branch"))
    $Staged = @(Invoke-GitLines @("diff","--cached","--name-only"))
    $Deleted = @(Invoke-GitLines @("ls-files","--deleted"))

    $Ahead = $AheadLines.Count
    $Behind = $BehindLines.Count

    Write-Host "AHEAD           : $Ahead"
    Write-Host "BEHIND          : $Behind"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if ($Ahead -ne 0) {
        Stop-Verification "Local repository is ahead of remote."
    }

    if ($Behind -ne 0) {
        Stop-Verification "Local repository is behind remote."
    }

    if ($Staged.Count -ne 0) {
        Stop-Verification "Staging is not clean."
    }

    if ($Deleted.Count -ne 0) {
        Stop-Verification "Tracked deletions detected."
    }

    Write-Host ""
    Write-Host "[3/5] COMMIT CONTENT CHECK" -ForegroundColor Yellow

    $RequiredPaths = @(
        "artifacts/development/SPT-023.3-v1.0.1/runs/20260810-001831/implementation-evidence.json",
        "docs/06_Tecnologia/SPT-023.3/SGD-SPT023.3-Capa1-Motor-Categorias.md",
        "src/sgoda/integration/spt0233/__init__.py",
        "src/sgoda/integration/spt0233/catalog.py",
        "src/sgoda/integration/spt0233/models.py",
        "src/sgoda/integration/spt0233/service.py",
        "tests/integration/test_spt0233_category_engine.py",
        "tools/institutional/Install-SPT023.3-Capa1-v1.0.1-OneFile-PS51.ps1",
        "tools/institutional/Prepare-SPT023-Authoritative-Continuation-v1.0.2-PS51.ps1"
    )

    $MissingPaths = @()

    foreach ($Path in $RequiredPaths) {
        $PreviousEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & git cat-file -e ($ExpectedPublishedHead + ":" + $Path) 2>$null
            $ExistsCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $PreviousEAP
        }

        if ($ExistsCode -ne 0) {
            $MissingPaths += $Path
        }
    }

    Write-Host "REQUIRED PATHS : $($RequiredPaths.Count)"
    Write-Host "MISSING PATHS  : $($MissingPaths.Count)"

    if ($MissingPaths.Count -ne 0) {
        $MissingPaths | ForEach-Object {
            Write-Host ("MISSING : " + $_) -ForegroundColor Red
        }
        Stop-Verification "Published commit does not contain the complete Capa 1 package."
    }

    Write-Host ""
    Write-Host "[4/5] EVIDENCE CHECK" -ForegroundColor Yellow

    $EvidencePath = Join-Path `
        $Root `
        "artifacts\development\SPT-023.3-v1.0.1\runs\20260810-001831\implementation-evidence.json"

    if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
        Stop-Verification "Implementation evidence is missing from worktree."
    }

    $Evidence = Get-Content `
        -LiteralPath $EvidencePath `
        -Raw `
        -Encoding UTF8 |
    ConvertFrom-Json

    Write-Host "TARGETED TESTS      : $($Evidence.targeted_tests_passed)"
    Write-Host "INSTITUTIONAL TESTS : $($Evidence.institutional_tests_passed)"
    Write-Host "PROTECTED CHANGES   : $($Evidence.protected_files_changed)"

    if ([int]$Evidence.targeted_tests_passed -lt 9) {
        Stop-Verification "Evidence does not certify 9 targeted tests."
    }

    if ([int]$Evidence.institutional_tests_passed -lt 870) {
        Stop-Verification "Evidence does not certify 870 institutional tests."
    }

    if ([int]$Evidence.protected_files_changed -ne 0) {
        Stop-Verification "Evidence reports protected component changes."
    }

    Write-Host ""
    Write-Host "[5/5] FINAL AUTHORITATIVE RESULT" -ForegroundColor Yellow

    $FinalLocal = Invoke-GitSingleLine @("rev-parse","HEAD")
    $FinalRemote = Invoke-GitSingleLine @("rev-parse","origin/$Branch")
    $FinalStaged = @(Invoke-GitLines @("diff","--cached","--name-only"))
    $FinalDeleted = @(Invoke-GitLines @("ls-files","--deleted"))

    if ($FinalLocal -ne $FinalRemote) {
        Stop-Verification "Final local/remote mismatch."
    }

    if ($FinalStaged.Count -ne 0) {
        Stop-Verification "Final staging is not clean."
    }

    if ($FinalDeleted.Count -ne 0) {
        Stop-Verification "Final tracked deletions detected."
    }

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host " SPT-023.3 CAPA 1 : PUBLISHED / CLOSED" -ForegroundColor Green
    Write-Host " COMMIT           : $FinalLocal" -ForegroundColor Green
    Write-Host " TARGETED TESTS   : 9 PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE       : 870 PASSED" -ForegroundColor Green
    Write-Host " SPT-023.1/.2     : PRESERVED" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE     : IDENTICAL" -ForegroundColor Green
    Write-Host " AHEAD            : 0" -ForegroundColor Green
    Write-Host " BEHIND           : 0" -ForegroundColor Green
    Write-Host " STAGING          : CLEAN" -ForegroundColor Green
    Write-Host " DELETED TRACKED  : 0" -ForegroundColor Green
    Write-Host " ERRORS PENDING   : 0" -ForegroundColor Green
    Write-Host " NEXT             : SPT-023.3 CAPA 2" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green

    exit 0
}
catch {
    Stop-Verification $_.Exception.Message
}
