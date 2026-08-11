param(
    [string]$ProjectRoot = "",
    [string]$ExpectedHead = "543dd7e52c24e661b8b7a1936aae7b88346733e1"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.3): implement category engine layer 1"

function Stop-Publish {
    param(
        [string]$Message,
        [bool]$ResetIndex = $true
    )

    if ($ResetIndex) {
        $PreviousEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try { & git reset -q HEAD -- 2>$null | Out-Null } finally { $ErrorActionPreference = $PreviousEAP }
    }

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host " SPT-023.3 CAPA 1 PUBLICATION : HOLD" -ForegroundColor Red
    Write-Host (" " + $Message) -ForegroundColor Red
    Write-Host " NO NEW PUBLICATION CONFIRMED" -ForegroundColor Red
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

    foreach ($Line in $Output) { [string]$Line }
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
    if ($Errors.Count -ne 0) {
        throw ("PowerShell syntax failure: " + $Path + " :: " + (($Errors | ForEach-Object { $_.Message }) -join " | "))
    }
}

function Get-HashMap {
    param([string]$Root,[string[]]$Paths)

    $Map = @{}
    foreach ($Rel in $Paths) {
        $Full = Join-Path $Root $Rel
        if (Test-Path -LiteralPath $Full -PathType Leaf) {
            $Map[$Rel] = (Get-FileHash -LiteralPath $Full -Algorithm SHA256).Hash
        }
    }
    return $Map
}

function Compare-HashMaps {
    param($Before,$After)

    $Changed = @()
    foreach ($Key in @($Before.Keys + $After.Keys | Sort-Object -Unique)) {
        if (-not $Before.ContainsKey($Key) -or -not $After.ContainsKey($Key) -or $Before[$Key] -ne $After[$Key]) {
            $Changed += $Key
        }
    }
    return @($Changed)
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
    Write-Host " SGODA-PUINAVE - SPT-023.3 CAPA 1 CONTROLLED PUBLICATION" -ForegroundColor Cyan
    Write-Host " SINGLE FILE / QUALITY GATE / COMMIT / PUSH / VERIFY" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "[1/9] AUTHORITATIVE BASELINE" -ForegroundColor Yellow

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git fetch origin $Branch --no-tags
        $FetchCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }
    if ($FetchCode -ne 0) { throw "Fetch failed." }

    $Local = Invoke-GitSingleLine @("rev-parse","HEAD")
    $Remote = Invoke-GitSingleLine @("rev-parse","origin/$Branch")
    $Staged = @(Invoke-GitLines @("diff","--cached","--name-only"))
    $Deleted = @(Invoke-GitLines @("ls-files","--deleted"))

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if ($Local -ne $ExpectedHead) { throw "Local HEAD changed from certified baseline." }
    if ($Remote -ne $ExpectedHead) { throw "Remote HEAD changed from certified baseline." }
    if ($Staged.Count -ne 0) { throw "Staging is not clean." }
    if ($Deleted.Count -ne 0) { throw "Tracked deletions detected." }

    $VenvPython = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
        throw ".venv Python not found."
    }

    Write-Host "BASELINE : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[2/9] IMPLEMENTATION PACKAGE" -ForegroundColor Yellow

    $ImplementationFiles = @(
        "src/sgoda/integration/spt0233/__init__.py",
        "src/sgoda/integration/spt0233/models.py",
        "src/sgoda/integration/spt0233/catalog.py",
        "src/sgoda/integration/spt0233/service.py",
        "tests/integration/test_spt0233_category_engine.py",
        "docs/06_Tecnologia/SPT-023.3/SGD-SPT023.3-Capa1-Motor-Categorias.md"
    )

    foreach ($Rel in $ImplementationFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $Rel) -PathType Leaf)) {
            throw "Implementation file missing: $Rel"
        }
    }

    $Evidence = Get-ChildItem `
        -LiteralPath (Join-Path $Root "artifacts\development\SPT-023.3-v1.0.1\runs") `
        -Filter "implementation-evidence.json" `
        -File `
        -Recurse `
        -ErrorAction Stop |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($null -eq $Evidence) { throw "SPT-023.3 implementation evidence not found." }

    $EvidenceData = Get-Content -LiteralPath $Evidence.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

    Write-Host "EVIDENCE        : $($Evidence.FullName)"
    Write-Host "TARGETED TESTS  : $($EvidenceData.targeted_tests_passed)"
    Write-Host "FULL SUITE      : $($EvidenceData.institutional_tests_passed)"
    Write-Host "PROTECTED CHANGE: $($EvidenceData.protected_files_changed)"

    if ([int]$EvidenceData.targeted_tests_passed -lt 9) { throw "Evidence does not certify 9 targeted tests." }
    if ([int]$EvidenceData.institutional_tests_passed -lt 870) { throw "Evidence does not certify 870 institutional tests." }
    if ([int]$EvidenceData.protected_files_changed -ne 0) { throw "Evidence reports protected-file changes." }

    Write-Host "PACKAGE EVIDENCE : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/9] PRESERVE SPT-023.1 / SPT-023.2" -ForegroundColor Yellow

    $Tracked = @(Invoke-GitLines @("-c","core.quotepath=false","ls-files"))
    $Protected = @(
        $Tracked | Where-Object {
            $_ -match '(?i)^src/sgoda/integration/spt0231/' -or
            $_ -match '(?i)^src/sgoda/integration/spt0232/' -or
            $_ -match '(?i)^docs/06_Tecnologia/SPT-023\.1/' -or
            $_ -match '(?i)^docs/06_Tecnologia/SPT-023\.2/'
        }
    )
    $ProtectedBefore = Get-HashMap -Root $Root -Paths $Protected
    Write-Host "PROTECTED FILES : $($ProtectedBefore.Count)"

    Write-Host ""
    Write-Host "[4/9] PUBLISH INSTITUTIONAL SCRIPTS" -ForegroundColor Yellow

    $PrepareSource = Join-Path $Root "Prepare-SPT023-Authoritative-Continuation-v1.0.2-PS51.ps1"
    $InstallSource = Join-Path $Root "Install-SPT023.3-Capa1-v1.0.1-OneFile-PS51.ps1"

    if (-not (Test-Path -LiteralPath $PrepareSource -PathType Leaf)) { throw "Executed PREPARE script missing from repository root." }
    if (-not (Test-Path -LiteralPath $InstallSource -PathType Leaf)) { throw "Executed installer script missing from repository root." }

    $ToolsDir = Join-Path $Root "tools\institutional"
    if (-not (Test-Path -LiteralPath $ToolsDir)) {
        New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    }

    $PrepareDest = Join-Path $ToolsDir "Prepare-SPT023-Authoritative-Continuation-v1.0.2-PS51.ps1"
    $InstallDest = Join-Path $ToolsDir "Install-SPT023.3-Capa1-v1.0.1-OneFile-PS51.ps1"

    Copy-Item -LiteralPath $PrepareSource -Destination $PrepareDest -Force
    Copy-Item -LiteralPath $InstallSource -Destination $InstallDest -Force

    Test-PowerShellSyntax $PrepareDest
    Test-PowerShellSyntax $InstallDest

    Write-Host "SCRIPT ARCHIVAL : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[5/9] QUALITY GATE" -ForegroundColor Yellow

    $env:PYTHONPATH = Join-Path $Root "src"

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $TargetOutput = @(& $VenvPython -m pytest "tests/integration/test_spt0233_category_engine.py" -q 2>&1)
        $TargetCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $PreviousEAP }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) { throw "Targeted SPT-023.3 tests failed." }

    $TargetMatch = [regex]::Match((($TargetOutput | ForEach-Object { [string]$_ }) -join "`n"), '(\d+)\s+passed')
    if (-not $TargetMatch.Success -or [int]$TargetMatch.Groups[1].Value -lt 9) { throw "Targeted test certification failed." }

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $SuiteOutput = @(& $VenvPython -m pytest -q 2>&1)
        $SuiteCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $PreviousEAP }

    $SuiteOutput | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
    if ($SuiteCode -ne 0) { throw "Institutional suite failed." }

    $SuiteMatch = [regex]::Match((($SuiteOutput | ForEach-Object { [string]$_ }) -join "`n"), '(\d+)\s+passed')
    if (-not $SuiteMatch.Success -or [int]$SuiteMatch.Groups[1].Value -lt 870) { throw "Institutional test certification failed." }

    $SuitePassed = [int]$SuiteMatch.Groups[1].Value
    Write-Host "QUALITY GATE : PASS ($SuitePassed tests)" -ForegroundColor Green

    $ProtectedAfter = Get-HashMap -Root $Root -Paths $Protected
    $ChangedProtected = @(Compare-HashMaps $ProtectedBefore $ProtectedAfter)
    if ($ChangedProtected.Count -ne 0) { throw "Protected SPT-023.1/SPT-023.2 files changed during publication gate." }

    Write-Host ""
    Write-Host "[6/9] EXACT CONTROLLED STAGING" -ForegroundColor Yellow

    $EvidenceRel = $Evidence.FullName.Substring($Root.Length).TrimStart([char[]]@("\","/")).Replace("\","/")
    $PrepareRel = "tools/institutional/Prepare-SPT023-Authoritative-Continuation-v1.0.2-PS51.ps1"
    $InstallRel = "tools/institutional/Install-SPT023.3-Capa1-v1.0.1-OneFile-PS51.ps1"

    $Allowed = @($ImplementationFiles + $EvidenceRel + $PrepareRel + $InstallRel | Sort-Object -Unique)

    & git reset -q HEAD --
    if ($LASTEXITCODE -ne 0) { throw "Unable to guarantee clean index." }

    & git -c core.safecrlf=false add -- @Allowed
    if ($LASTEXITCODE -ne 0) { throw "Controlled staging failed." }

    $Actual = @(
        Invoke-GitLines @("-c","core.quotepath=false","diff","--cached","--name-only") |
        ForEach-Object { $_.Replace("\","/") } |
        Sort-Object -Unique
    )

    $Missing = @($Allowed | Where-Object { $Actual -notcontains $_ })
    $Unexpected = @($Actual | Where-Object { $Allowed -notcontains $_ })

    Write-Host "STAGED     : $($Actual.Count)"
    Write-Host "MISSING    : $($Missing.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if ($Missing.Count -ne 0 -or $Unexpected.Count -ne 0) { throw "Exact staging manifest mismatch." }

    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw "git diff --cached --check failed." }

    Write-Host "STAGING QUALITY : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[7/9] FINAL REMOTE GATE" -ForegroundColor Yellow

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git fetch origin $Branch --no-tags
        $Fetch2 = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $PreviousEAP }
    if ($Fetch2 -ne 0) { throw "Final fetch failed." }

    $LocalBeforeCommit = Invoke-GitSingleLine @("rev-parse","HEAD")
    $RemoteBeforeCommit = Invoke-GitSingleLine @("rev-parse","origin/$Branch")

    if ($LocalBeforeCommit -ne $ExpectedHead -or $RemoteBeforeCommit -ne $ExpectedHead) {
        throw "Repository moved during publication preparation."
    }

    Write-Host "REMOTE GATE : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[8/9] COMMIT + PUSH" -ForegroundColor Yellow

    & git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { Stop-Publish "Commit failed." -ResetIndex $false }

    $NewCommit = Invoke-GitSingleLine @("rev-parse","HEAD")
    Write-Host "NEW COMMIT : $NewCommit"

    & git push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        Stop-Publish "Push failed; local commit is preserved. Do not recommit." -ResetIndex $false
    }

    Write-Host ""
    Write-Host "[9/9] REMOTE VERIFICATION" -ForegroundColor Yellow

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git fetch origin $Branch --no-tags
        $Fetch3 = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $PreviousEAP }
    if ($Fetch3 -ne 0) { Stop-Publish "Verification fetch failed; do not recommit." -ResetIndex $false }

    $LocalFinal = Invoke-GitSingleLine @("rev-parse","HEAD")
    $RemoteFinal = Invoke-GitSingleLine @("rev-parse","origin/$Branch")
    $Ahead = @(Invoke-GitLines @("rev-list","origin/$Branch..HEAD")).Count
    $Behind = @(Invoke-GitLines @("rev-list","HEAD..origin/$Branch")).Count
    $StagedFinal = @(Invoke-GitLines @("diff","--cached","--name-only"))
    $DeletedFinal = @(Invoke-GitLines @("ls-files","--deleted"))

    Write-Host "LOCAL HEAD      : $LocalFinal"
    Write-Host "REMOTE HEAD     : $RemoteFinal"
    Write-Host "AHEAD           : $Ahead"
    Write-Host "BEHIND          : $Behind"
    Write-Host "STAGED          : $($StagedFinal.Count)"
    Write-Host "DELETED TRACKED : $($DeletedFinal.Count)"

    if ($LocalFinal -ne $RemoteFinal -or $Ahead -ne 0 -or $Behind -ne 0 -or $StagedFinal.Count -ne 0 -or $DeletedFinal.Count -ne 0) {
        Stop-Publish "Post-publication verification failed; do not recommit." -ResetIndex $false
    }

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host " SPT-023.3 CAPA 1 : PUBLISHED / CLOSED" -ForegroundColor Green
    Write-Host " COMMIT           : $LocalFinal" -ForegroundColor Green
    Write-Host " TARGETED TESTS   : 9 PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE       : $SuitePassed PASSED" -ForegroundColor Green
    Write-Host " SPT-023.1/.2     : PRESERVED" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE     : IDENTICAL" -ForegroundColor Green
    Write-Host " STAGING          : CLEAN" -ForegroundColor Green
    Write-Host " NEXT             : SPT-023.3 CAPA 2" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green

    exit 0
}
catch {
    Stop-Publish $_.Exception.Message
}
