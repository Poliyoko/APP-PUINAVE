param(
    [string]$ProjectRoot = "",
    [string]$ExpectedPublishedHead = "94b7d91aab208dba922d2551574968f4b60fbf3c"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Invoke-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Arguments,
        [switch]$AllowExitCodeOne
    )

    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = @(& git @Arguments 2>&1)
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    if ($AllowExitCodeOne -and $code -eq 1) {
        return @()
    }

    if ($code -ne 0) {
        throw ("git " + ($Arguments -join " ") + " failed with exit code " + $code + ": " + ($output -join " "))
    }

    return @($output | ForEach-Object { [string]$_ })
}

function Git-One {
    param([string[]]$Arguments)

    $result = @(Invoke-Git -Arguments $Arguments)

    if ($result.Count -eq 0) {
        throw ("git " + ($Arguments -join " ") + " returned no output.")
    }

    return ([string]$result[0]).Trim()
}

function Fail {
    param([string]$Message)

    $lines = @(
        "",
        "======================================================================",
        " SPT-023.3 CAPA 1 : HOLD",
        " REASON           : $Message",
        " COMMIT / PUSH    : NO",
        " ERRORS PENDING   : 1",
        "======================================================================"
    )

    $lines | Write-Output
    exit 20
}

try {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = Git-One -Arguments @("rev-parse","--show-toplevel")
    }

    Set-Location $ProjectRoot

    $Root = Git-One -Arguments @("rev-parse","--show-toplevel")
    $Branch = Git-One -Arguments @("branch","--show-current")
    $Origin = Git-One -Arguments @("remote","get-url","origin")

    # 1. Remote synchronization
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $fetchOutput = @(& git fetch origin $Branch --no-tags 2>&1)
        $fetchCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    $fetchOutput | ForEach-Object { Write-Output ([string]$_) }

    if ($fetchCode -ne 0) {
        Fail "Unable to fetch official remote."
    }

    # 2. Authoritative repository state
    $LocalHead = Git-One -Arguments @("rev-parse","HEAD")
    $RemoteHead = Git-One -Arguments @("rev-parse","origin/$Branch")

    $Ahead = @(Invoke-Git -Arguments @("rev-list","origin/$Branch..HEAD")).Count
    $Behind = @(Invoke-Git -Arguments @("rev-list","HEAD..origin/$Branch")).Count
    $Staged = @(Invoke-Git -Arguments @("diff","--cached","--name-only")).Count
    $Deleted = @(Invoke-Git -Arguments @("ls-files","--deleted")).Count

    if ($LocalHead -ne $ExpectedPublishedHead) {
        Fail "Local HEAD differs from certified SPT-023.3 Capa 1 commit."
    }

    if ($RemoteHead -ne $ExpectedPublishedHead) {
        Fail "Remote HEAD differs from certified SPT-023.3 Capa 1 commit."
    }

    if ($Ahead -ne 0) {
        Fail "Local repository is ahead of official remote."
    }

    if ($Behind -ne 0) {
        Fail "Local repository is behind official remote."
    }

    if ($Staged -ne 0) {
        Fail "Staging is not clean."
    }

    if ($Deleted -ne 0) {
        Fail "Tracked deletions detected."
    }

    # 3. Exact published package
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

    $Missing = @()

    foreach ($Path in $RequiredPaths) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & git cat-file -e ($ExpectedPublishedHead + ":" + $Path) 2>$null
            $existsCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previous
        }

        if ($existsCode -ne 0) {
            $Missing += $Path
        }
    }

    if ($Missing.Count -ne 0) {
        Fail ("Published package is incomplete: " + ($Missing -join ", "))
    }

    # 4. Evidence
    $EvidencePath = Join-Path `
        $Root `
        "artifacts\development\SPT-023.3-v1.0.1\runs\20260810-001831\implementation-evidence.json"

    if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
        Fail "Implementation evidence is missing."
    }

    $Evidence = Get-Content `
        -LiteralPath $EvidencePath `
        -Raw `
        -Encoding UTF8 |
    ConvertFrom-Json

    $Targeted = [int]$Evidence.targeted_tests_passed
    $FullSuite = [int]$Evidence.institutional_tests_passed
    $ProtectedChanges = [int]$Evidence.protected_files_changed

    if ($Targeted -lt 9) {
        Fail "Targeted test evidence is below 9."
    }

    if ($FullSuite -lt 870) {
        Fail "Institutional test evidence is below 870."
    }

    if ($ProtectedChanges -ne 0) {
        Fail "Protected SPT-023.1/SPT-023.2 components changed."
    }

    # 5. Final banner. Use Write-Output so transcript/pipeline always captures it.
    $Banner = @(
        "",
        "======================================================================",
        " SPT-023.3 CAPA 1 : PUBLISHED / CLOSED",
        " COMMIT           : $LocalHead",
        " TARGETED TESTS   : $Targeted PASSED",
        " FULL SUITE       : $FullSuite PASSED",
        " SPT-023.1/.2     : PRESERVED",
        " LOCAL/REMOTE     : IDENTICAL",
        " AHEAD            : $Ahead",
        " BEHIND           : $Behind",
        " STAGING          : CLEAN",
        " DELETED TRACKED  : $Deleted",
        " ERRORS PENDING   : 0",
        " NEXT             : SPT-023.3 CAPA 2",
        "======================================================================",
        "FINAL_CLOSURE_EXIT_CODE=0"
    )

    $Banner | Write-Output
    exit 0
}
catch {
    Fail $_.Exception.Message
}
