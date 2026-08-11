param(
    [string]$ProjectRoot = "",
    [string]$ExpectedHead = "889455a4328c84258cfa523977dfda7ba40b404d",
    [string]$AuditRun = "20260809-173436",
    [bool]$Publish = $true
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "chore(institutional): reconcile audited untracked artifacts"

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host (" " + $Text) -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
}

function Fail {
    param(
        [string]$Message,
        [bool]$ResetIndex = $false
    )

    if ($ResetIndex) {
        & git reset -q HEAD -- 2>$null
    }

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host " SGODA RECONCILIATION v2.0.0 : HOLD" -ForegroundColor Red
    Write-Host (" " + $Message) -ForegroundColor Red
    Write-Host " NO COMMIT / NO PUSH FROM THIS FAILED RUN" -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Red
    exit 20
}

function Get-GitOutput {
    param([string[]]$Arguments)

    $Output = @(& git @Arguments 2>&1)
    $Code = $LASTEXITCODE

    if ($Code -ne 0) {
        $Text = ($Output -join "`n")
        throw "git $($Arguments -join ' ') failed with exit code $Code`n$Text"
    }

    return @($Output)
}

function Normalize-Slashes {
    param([string]$Path)
    return $Path.Replace("\","/")
}

function Write-Utf8Lf {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $Text = ($Lines -join "`n").TrimEnd("`r","`n") + "`n"
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
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
        $Message = ($Errors | ForEach-Object { $_.Message }) -join " | "
        throw "PowerShell syntax error in $Path :: $Message"
    }
}

function Test-JsonFile {
    param([string]$Path)

    $null = Get-Content `
        -LiteralPath $Path `
        -Raw `
        -Encoding UTF8 |
    ConvertFrom-Json
}

function Stage-Batch {
    param([string[]]$Paths)

    if ($Paths.Count -eq 0) {
        return
    }

    & git -c core.safecrlf=false add -- @Paths

    if ($LASTEXITCODE -ne 0) {
        throw "git add failed for a controlled batch."
    }
}

# ----------------------------------------------------------------------
# Resolve repository
# ----------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = ((Get-GitOutput @("rev-parse","--show-toplevel"))[0]).Trim()
}

Set-Location $ProjectRoot

$Root = ((Get-GitOutput @("rev-parse","--show-toplevel"))[0]).Trim()
Set-Location $Root

$Branch = ((Get-GitOutput @("branch","--show-current"))[0]).Trim()
$Origin = ((Get-GitOutput @("remote","get-url","origin"))[0]).Trim()

Write-Section "SGODA-PUINAVE - TRANSACTIONAL UNTRACKED RECONCILIATION v2.0.0"
Write-Host "PowerShell target : 5.1"
Write-Host "Project root      : $Root"
Write-Host "Branch            : $Branch"
Write-Host "Origin            : $Origin"
Write-Host "Expected baseline : $ExpectedHead"
Write-Host "Publish           : $Publish"

if ($Origin -notmatch '(?i)github\.com[:/]Poliyoko/APP-PUINAVE(\.git)?$') {
    Fail "Unexpected origin: $Origin"
}

# ----------------------------------------------------------------------
# Remote state and resumable publication
# ----------------------------------------------------------------------

Write-Section "1/10 - AUTHORITATIVE BASELINE"

& git fetch origin $Branch --no-tags

if ($LASTEXITCODE -ne 0) {
    Fail "Unable to fetch official remote."
}

$LocalHead = ((Get-GitOutput @("rev-parse","HEAD"))[0]).Trim()
$RemoteHead = ((Get-GitOutput @("rev-parse","origin/$Branch"))[0]).Trim()

Write-Host "LOCAL HEAD  : $LocalHead"
Write-Host "REMOTE HEAD : $RemoteHead"

if ($LocalHead -ne $ExpectedHead) {

    if ($LocalHead -eq $RemoteHead) {
        Write-Host ""
        Write-Host "ALREADY PUBLISHED : YES" -ForegroundColor Green
        Write-Host "LOCAL/REMOTE HEAD  : IDENTICAL" -ForegroundColor Green
        exit 0
    }

    $Parent = ""
    $Subject = ""

    try {
        $Parent = ((Get-GitOutput @("rev-parse","HEAD^"))[0]).Trim()
        $Subject = ((Get-GitOutput @("log","-1","--pretty=%s"))[0]).Trim()
    }
    catch {
        Fail "HEAD differs from certified baseline and cannot be safely classified."
    }

    if (
        $Parent -eq $ExpectedHead -and
        $Subject -eq $CommitMessage -and
        $RemoteHead -eq $ExpectedHead
    ) {
        Write-Host "RESUME MODE : local institutional commit exists; only push remains." -ForegroundColor Yellow

        if (-not $Publish) {
            Write-Host "Publish=False, so the existing local commit is preserved without push."
            exit 0
        }

        & git push origin $Branch

        if ($LASTEXITCODE -ne 0) {
            Fail "Resume push failed. Local commit is preserved."
        }

        & git fetch origin $Branch --no-tags

        if ($LASTEXITCODE -ne 0) {
            Fail "Verification fetch failed after resume push."
        }

        $RemoteAfterResume = ((Get-GitOutput @("rev-parse","origin/$Branch"))[0]).Trim()

        if ($RemoteAfterResume -ne $LocalHead) {
            Fail "Remote HEAD does not match resumed local commit."
        }

        Write-Host ""
        Write-Host "RESUMED PUBLICATION : PASS" -ForegroundColor Green
        Write-Host "HEAD                : $LocalHead" -ForegroundColor Green
        exit 0
    }

    Fail "Local HEAD is not the certified baseline and is not a resumable institutional commit."
}

if ($RemoteHead -ne $ExpectedHead) {
    Fail "Official remote moved away from the certified baseline."
}

$DeletedBefore = @(Get-GitOutput @("ls-files","--deleted"))
$StagedBefore = @(Get-GitOutput @("diff","--cached","--name-only"))

Write-Host "STAGED BEFORE   : $($StagedBefore.Count)"
Write-Host "DELETED TRACKED : $($DeletedBefore.Count)"

if ($DeletedBefore.Count -ne 0) {
    Fail "Tracked deletions detected before reconciliation."
}

# Always clear INDEX ONLY. Working tree is preserved.
& git reset -q HEAD --

if ($LASTEXITCODE -ne 0) {
    Fail "Unable to reset index."
}

$StagedAfterReset = @(Get-GitOutput @("diff","--cached","--name-only"))

if ($StagedAfterReset.Count -ne 0) {
    Fail "Index is not clean after controlled reset."
}

Write-Host "INDEX CLEAN      : YES" -ForegroundColor Green
Write-Host "WORKTREE PRESERVED: YES" -ForegroundColor Green

# ----------------------------------------------------------------------
# Load certified audit using actual schema
# ----------------------------------------------------------------------

Write-Section "2/10 - CERTIFIED AUDIT MANIFEST"

$AuditRoot = Join-Path `
    $Root `
    ("artifacts\audit\untracked-institutional-audit\" + $AuditRun)

$InventoryPath = Join-Path $AuditRoot "untracked-inventory.json"

if (-not (Test-Path -LiteralPath $InventoryPath -PathType Leaf)) {
    Fail "Certified audit inventory not found: $InventoryPath"
}

$RawInventory = Get-Content `
    -LiteralPath $InventoryPath `
    -Raw `
    -Encoding UTF8

$ParsedInventory = $RawInventory | ConvertFrom-Json
$InventoryList = New-Object System.Collections.ArrayList

foreach ($Record in $ParsedInventory) {
    [void]$InventoryList.Add($Record)
}

$Inventory = @($InventoryList.ToArray())

Write-Host "CERTIFIED RECORDS : $($Inventory.Count)"

if ($Inventory.Count -ne 1576) {
    Fail "Certified audit cardinality is not 1576."
}

# IMPORTANT: The audit schema uses Decision, not classification.
$Versioning = @(
    $Inventory |
    Where-Object {
        $_.Decision -eq "PRESERVE_AND_REVIEW_FOR_VERSIONING"
    }
)

$IgnoreItems = @(
    $Inventory |
    Where-Object {
        $_.Decision -eq "IGNORE_POLICY_CANDIDATE"
    }
)

$SecretItems = @(
    $Inventory |
    Where-Object {
        $_.PotentialSecret -eq $true
    }
)

$Oversized = @(
    $Inventory |
    Where-Object {
        [long]$_.Bytes -ge 100MB
    }
)

$Backups = @(
    $Inventory |
    Where-Object {
        $_.Category -eq "BACKUP_REVIEW"
    }
)

Write-Host "VERSIONING       : $($Versioning.Count)"
Write-Host "IGNORE           : $($IgnoreItems.Count)"
Write-Host "POTENTIAL SECRET : $($SecretItems.Count)"
Write-Host ">=100MB          : $($Oversized.Count)"
Write-Host "BACKUP REVIEW    : $($Backups.Count)"

if ($Versioning.Count -ne 386) {
    Fail "Expected exactly 386 versioning candidates from Decision field."
}

if ($IgnoreItems.Count -ne 1160) {
    Fail "Expected exactly 1160 ignore-policy candidates."
}

if ($SecretItems.Count -ne 1) {
    Fail "Expected exactly one secret-review finding."
}

if ($Oversized.Count -ne 2) {
    Fail "Expected exactly two files >=100MB."
}

if ($Backups.Count -ne 27) {
    Fail "Expected exactly 27 backup-review items."
}

# ----------------------------------------------------------------------
# Preflight ALL candidates before staging anything
# ----------------------------------------------------------------------

Write-Section "3/10 - FULL PREFLIGHT BEFORE ANY STAGING"

$CandidatePaths = New-Object System.Collections.ArrayList
$PreflightErrors = New-Object System.Collections.ArrayList

foreach ($Item in $Versioning) {

    $Relative = Normalize-Slashes ([string]$Item.Path)

    if ([string]::IsNullOrWhiteSpace($Relative)) {
        [void]$PreflightErrors.Add("Empty candidate path.")
        continue
    }

    if ($Item.PotentialSecret -eq $true) {
        [void]$PreflightErrors.Add("Secret-marked candidate: $Relative")
        continue
    }

    if ([long]$Item.Bytes -ge 100MB) {
        [void]$PreflightErrors.Add("Oversized candidate: $Relative")
        continue
    }

    if ($Item.Category -eq "BACKUP_REVIEW") {
        [void]$PreflightErrors.Add("Backup candidate entered versioning set: $Relative")
        continue
    }

    if (
        $Relative -match '^\.runtime/' -or
        $Relative -match '^artifacts/runtime/' -or
        $Relative -match '(?i)(^|/)repository-backup(/|$)' -or
        $Relative -match '(?i)(^|/)registry-backup(/|$)'
    ) {
        [void]$PreflightErrors.Add("Forbidden runtime/backup path: $Relative")
        continue
    }

    $Full = Join-Path $Root $Relative

    if (-not (Test-Path -LiteralPath $Full -PathType Leaf)) {
        [void]$PreflightErrors.Add("Missing candidate: $Relative")
        continue
    }

    $Info = Get-Item -LiteralPath $Full

    if ($Info.Length -ge 100MB) {
        [void]$PreflightErrors.Add("Current file grew >=100MB: $Relative")
        continue
    }

    $Extension = $Info.Extension.ToLowerInvariant()

    try {
        if ($Extension -eq ".ps1") {
            Test-PowerShellSyntax -Path $Full
        }

        if ($Extension -eq ".json" -and $Info.Length -lt 25MB) {
            Test-JsonFile -Path $Full
        }
    }
    catch {
        [void]$PreflightErrors.Add($_.Exception.Message)
        continue
    }

    [void]$CandidatePaths.Add($Relative)
}

Write-Host "CANDIDATES PREFLIGHTED : $($CandidatePaths.Count)"
Write-Host "PREFLIGHT ERRORS       : $($PreflightErrors.Count)"

if ($PreflightErrors.Count -ne 0) {
    $PreflightErrors | Select-Object -First 50 | ForEach-Object {
        Write-Host ("  " + $_) -ForegroundColor Red
    }

    Fail "Full preflight found blocking candidate errors. Nothing was staged."
}

if ($CandidatePaths.Count -ne 386) {
    Fail "Preflight did not preserve the exact 386-candidate set."
}

Write-Host "FULL PREFLIGHT : PASS" -ForegroundColor Green

# ----------------------------------------------------------------------
# Update .gitignore in one deterministic write
# ----------------------------------------------------------------------

Write-Section "4/10 - PERMANENT LOCAL-RUNTIME PROTECTION"

$GitIgnore = Join-Path $Root ".gitignore"

if (-not (Test-Path -LiteralPath $GitIgnore -PathType Leaf)) {
    [System.IO.File]::WriteAllText(
        $GitIgnore,
        "",
        (New-Object System.Text.UTF8Encoding($false))
    )
}

$ExistingRules = @(
    Get-Content `
        -LiteralPath $GitIgnore `
        -Encoding UTF8 `
        -ErrorAction SilentlyContinue
)

$RequiredRules = @(
    "# SGODA institutional runtime / generated local state",
    ".runtime/",
    "artifacts/runtime/",
    "**/__pycache__/",
    "**/.pytest_cache/",
    "**/.cache/",
    "# SGODA local recursive/temporary backup protection",
    "**/repository-backup/",
    "**/registry-backup/"
)

$MergedRules = New-Object System.Collections.ArrayList

foreach ($Line in $ExistingRules) {
    [void]$MergedRules.Add($Line)
}

foreach ($Rule in $RequiredRules) {
    if ($MergedRules -notcontains $Rule) {
        [void]$MergedRules.Add($Rule)
    }
}

Write-Utf8Lf -Path $GitIgnore -Lines @($MergedRules.ToArray())

Write-Host ".gitignore : UTF-8 NO BOM + LF" -ForegroundColor Green
Write-Host "Runtime and recursive backup rules guaranteed." -ForegroundColor Green

# ----------------------------------------------------------------------
# Preserve the reconciler itself + audit evidence + prepublication record
# ----------------------------------------------------------------------

Write-Section "5/10 - INSTITUTIONAL EVIDENCE PACKAGE"

$InstitutionalTool = Join-Path `
    $Root `
    "tools\institutional\Invoke-SGODA-Untracked-Reconciliation-v2.0.0-PS51.ps1"

$ToolDirectory = Split-Path -Parent $InstitutionalTool

if (-not (Test-Path -LiteralPath $ToolDirectory)) {
    New-Item -ItemType Directory -Path $ToolDirectory -Force | Out-Null
}

$CurrentScript = $MyInvocation.MyCommand.Path

if (
    -not [string]::IsNullOrWhiteSpace($CurrentScript) -and
    (Resolve-Path -LiteralPath $CurrentScript).Path -ne $InstitutionalTool
) {
    [System.IO.File]::Copy(
        (Resolve-Path -LiteralPath $CurrentScript).Path,
        $InstitutionalTool,
        $true
    )
}

Test-PowerShellSyntax -Path $InstitutionalTool

$EvidenceRoot = Join-Path `
    $Root `
    "artifacts\audit\untracked-reconciliation-v2.0.0"

if (-not (Test-Path -LiteralPath $EvidenceRoot)) {
    New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
}

$EvidencePath = Join-Path $EvidenceRoot "prepublication-evidence.json"

$Evidence = [ordered]@{
    schema_version          = "2.0.0"
    generated_utc           = [DateTime]::UtcNow.ToString("o")
    certified_head          = $ExpectedHead
    audit_run               = $AuditRun
    audit_records           = $Inventory.Count
    versioning_candidates   = $Versioning.Count
    ignore_candidates       = $IgnoreItems.Count
    backup_review           = $Backups.Count
    oversized_100mb         = $Oversized.Count
    potential_secrets       = $SecretItems.Count
    secret_content_exposed  = $false
    destructive_actions     = 0
    preflight               = "PASS"
}

$EvidenceJson = $Evidence | ConvertTo-Json -Depth 6

[System.IO.File]::WriteAllText(
    $EvidencePath,
    $EvidenceJson + "`n",
    (New-Object System.Text.UTF8Encoding($false))
)

# Audit package is institutional evidence and is explicitly preserved.
$AuditEvidenceFiles = @(
    "untracked-inventory.csv",
    "untracked-inventory.json",
    "sha256-manifest.csv",
    "audit-summary.json",
    "audit-summary.md",
    "reconciliation-plan.json"
)

$ExtraPaths = New-Object System.Collections.ArrayList

foreach ($Name in $AuditEvidenceFiles) {
    $Full = Join-Path $AuditRoot $Name

    if (Test-Path -LiteralPath $Full -PathType Leaf) {
        $Relative = Normalize-Slashes ($Full.Substring($Root.Length).TrimStart("\","/"))

        if ((Get-Item -LiteralPath $Full).Length -ge 100MB) {
            Fail "Audit evidence unexpectedly exceeds 100MB: $Relative"
        }

        [void]$ExtraPaths.Add($Relative)
    }
}

$ToolRelative = Normalize-Slashes ($InstitutionalTool.Substring($Root.Length).TrimStart("\","/"))
$EvidenceRelative = Normalize-Slashes ($EvidencePath.Substring($Root.Length).TrimStart("\","/"))

if ($CandidatePaths -notcontains $ToolRelative) {
    [void]$ExtraPaths.Add($ToolRelative)
}

[void]$ExtraPaths.Add($EvidenceRelative)

$AllowedPaths = New-Object System.Collections.ArrayList

[void]$AllowedPaths.Add(".gitignore")

foreach ($P in $CandidatePaths) {
    if ($AllowedPaths -notcontains $P) {
        [void]$AllowedPaths.Add($P)
    }
}

foreach ($P in $ExtraPaths) {
    if ($AllowedPaths -notcontains $P) {
        [void]$AllowedPaths.Add($P)
    }
}

Write-Host "AUDIT EVIDENCE FILES : $($ExtraPaths.Count)"
Write-Host "ALLOWED STAGE PATHS  : $($AllowedPaths.Count)"

# ----------------------------------------------------------------------
# Transactional controlled staging
# core.safecrlf is disabled ONLY for these exact git-add invocations.
# Repository configuration is NOT changed.
# ----------------------------------------------------------------------

Write-Section "6/10 - TRANSACTIONAL CONTROLLED STAGING"

& git reset -q HEAD --

if ($LASTEXITCODE -ne 0) {
    Fail "Unable to guarantee clean index before staging."
}

try {
    $AllToStage = @($AllowedPaths.ToArray())
    $BatchSize = 40

    for ($Start = 0; $Start -lt $AllToStage.Count; $Start += $BatchSize) {

        $End = [Math]::Min($Start + $BatchSize - 1, $AllToStage.Count - 1)
        $Batch = @($AllToStage[$Start..$End])

        Stage-Batch -Paths $Batch
    }
}
catch {
    & git reset -q HEAD -- 2>$null
    Fail ("Atomic staging failed and index was rolled back: " + $_.Exception.Message)
}

$ActualStaged = @(
    Get-GitOutput @("-c","core.quotepath=false","diff","--cached","--name-only") |
    ForEach-Object { Normalize-Slashes $_ } |
    Sort-Object -Unique
)

$AllowedNormalized = @(
    $AllowedPaths |
    ForEach-Object { Normalize-Slashes $_ } |
    Sort-Object -Unique
)

$Unexpected = @(
    $ActualStaged |
    Where-Object {
        $AllowedNormalized -notcontains $_
    }
)

$Missing = @(
    $AllowedNormalized |
    Where-Object {
        $ActualStaged -notcontains $_
    }
)

Write-Host "STAGED TOTAL : $($ActualStaged.Count)"
Write-Host "UNEXPECTED   : $($Unexpected.Count)"
Write-Host "MISSING      : $($Missing.Count)"

if ($Unexpected.Count -ne 0 -or $Missing.Count -ne 0) {
    & git reset -q HEAD --
    Fail "Exact staging manifest mismatch; index rolled back."
}

# ----------------------------------------------------------------------
# Absolute exclusion + Git quality gate
# ----------------------------------------------------------------------

Write-Section "7/10 - ABSOLUTE EXCLUSION AND GIT QUALITY GATE"

$Violations = New-Object System.Collections.ArrayList

foreach ($Path in $ActualStaged) {

    if (
        $Path -match '^\.runtime/' -or
        $Path -match '^artifacts/runtime/' -or
        $Path -match '(?i)(^|/)repository-backup(/|$)' -or
        $Path -match '(?i)(^|/)registry-backup(/|$)'
    ) {
        [void]$Violations.Add("FORBIDDEN PATH STAGED: $Path")
    }

    $Full = Join-Path $Root $Path

    if (Test-Path -LiteralPath $Full -PathType Leaf) {
        if ((Get-Item -LiteralPath $Full).Length -ge 100MB) {
            [void]$Violations.Add(">=100MB STAGED: $Path")
        }
    }
}

foreach ($Secret in $SecretItems) {
    $SecretPath = Normalize-Slashes ([string]$Secret.Path)

    if ($ActualStaged -contains $SecretPath) {
        [void]$Violations.Add("SECRET-REVIEW FILE STAGED: $SecretPath")
    }
}

foreach ($Backup in $Backups) {
    $BackupPath = Normalize-Slashes ([string]$Backup.Path)

    if ($ActualStaged -contains $BackupPath) {
        [void]$Violations.Add("BACKUP-REVIEW FILE STAGED: $BackupPath")
    }
}

if ($Violations.Count -ne 0) {
    $Violations | ForEach-Object {
        Write-Host ("  " + $_) -ForegroundColor Red
    }

    & git reset -q HEAD --
    Fail "Forbidden content entered staging; index rolled back."
}

& git diff --cached --check

if ($LASTEXITCODE -ne 0) {
    & git reset -q HEAD --
    Fail "git diff --cached --check failed; index rolled back."
}

Write-Host "SECRET EXCLUSION  : PASS" -ForegroundColor Green
Write-Host ">=100MB EXCLUSION : PASS" -ForegroundColor Green
Write-Host "BACKUP EXCLUSION  : PASS" -ForegroundColor Green
Write-Host "RUNTIME EXCLUSION : PASS" -ForegroundColor Green
Write-Host "DIFF CHECK        : PASS" -ForegroundColor Green

# ----------------------------------------------------------------------
# Project quality gates
# ----------------------------------------------------------------------

Write-Section "8/10 - PROJECT QUALITY GATES"

$PsFiles = @(
    $ActualStaged |
    Where-Object { $_ -like "*.ps1" }
)

foreach ($Relative in $PsFiles) {
    Test-PowerShellSyntax -Path (Join-Path $Root $Relative)
}

Write-Host "POWERSHELL SYNTAX : PASS ($($PsFiles.Count) files)" -ForegroundColor Green

$JsonFiles = @(
    $ActualStaged |
    Where-Object { $_ -like "*.json" }
)

$JsonValidated = 0
$JsonLargeAuditTrusted = 0

foreach ($Relative in $JsonFiles) {

    $Full = Join-Path $Root $Relative
    $Info = Get-Item -LiteralPath $Full

    if ($Info.Length -lt 25MB) {
        Test-JsonFile -Path $Full
        $JsonValidated++
    }
    else {
        # Large candidate JSONs were already certified by the completed audit.
        $JsonLargeAuditTrusted++
    }
}

Write-Host "JSON VALIDATED DIRECTLY : $JsonValidated" -ForegroundColor Green
Write-Host "JSON LARGE / AUDIT TRUST: $JsonLargeAuditTrusted" -ForegroundColor Green

$env:PYTHONPATH = Join-Path $Root "src"

$PytestOutput = @(
    & python -m pytest -q 2>&1
)

$PytestCode = $LASTEXITCODE
$PytestText = $PytestOutput -join "`n"

$PytestOutput | Select-Object -Last 20 | ForEach-Object {
    Write-Host $_
}

if ($PytestCode -ne 0) {
    & git reset -q HEAD --
    Fail "pytest failed; index rolled back."
}

$PassedMatch = [regex]::Match(
    $PytestText,
    '(\d+)\s+passed'
)

if (-not $PassedMatch.Success) {
    & git reset -q HEAD --
    Fail "Unable to extract pytest passed count; index rolled back."
}

$PassedTests = [int]$PassedMatch.Groups[1].Value

Write-Host "PYTEST PASSED : $PassedTests"

if ($PassedTests -lt 861) {
    & git reset -q HEAD --
    Fail "Institutional test count regressed below 861; index rolled back."
}

& python -m compileall -q src

if ($LASTEXITCODE -ne 0) {
    & git reset -q HEAD --
    Fail "Python compileall failed; index rolled back."
}

Write-Host "PYTHON COMPILEALL : PASS" -ForegroundColor Green

# ----------------------------------------------------------------------
# Final remote gate before commit
# ----------------------------------------------------------------------

Write-Section "9/10 - FINAL PUBLICATION GATE"

& git fetch origin $Branch --no-tags

if ($LASTEXITCODE -ne 0) {
    & git reset -q HEAD --
    Fail "Final fetch failed; index rolled back."
}

$HeadBeforeCommit = ((Get-GitOutput @("rev-parse","HEAD"))[0]).Trim()
$RemoteBeforeCommit = ((Get-GitOutput @("rev-parse","origin/$Branch"))[0]).Trim()

$AheadBefore = @(Get-GitOutput @("rev-list","origin/$Branch..HEAD")).Count
$BehindBefore = @(Get-GitOutput @("rev-list","HEAD..origin/$Branch")).Count

Write-Host "LOCAL HEAD : $HeadBeforeCommit"
Write-Host "REMOTE HEAD: $RemoteBeforeCommit"
Write-Host "AHEAD      : $AheadBefore"
Write-Host "BEHIND     : $BehindBefore"

if (
    $HeadBeforeCommit -ne $ExpectedHead -or
    $RemoteBeforeCommit -ne $ExpectedHead -or
    $AheadBefore -ne 0 -or
    $BehindBefore -ne 0
) {
    & git reset -q HEAD --
    Fail "Repository moved during reconciliation; index rolled back."
}

Write-Host "FINAL QUALITY GATE : PASS" -ForegroundColor Green

if (-not $Publish) {
    Write-Host ""
    Write-Host "PUBLISH=False: staging is intentionally left prepared." -ForegroundColor Yellow
    Write-Host "No commit or push was performed."
    exit 0
}

# ----------------------------------------------------------------------
# Commit + push + remote verification
# ----------------------------------------------------------------------

Write-Section "10/10 - COMMIT, PUSH, AND REMOTE VERIFICATION"

& git commit -m $CommitMessage

if ($LASTEXITCODE -ne 0) {
    Fail "Institutional commit failed."
}

$PublishedCommit = ((Get-GitOutput @("rev-parse","HEAD"))[0]).Trim()

Write-Host "NEW COMMIT : $PublishedCommit" -ForegroundColor Green

& git push origin $Branch

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "PUSH FAILED. The local commit is preserved." -ForegroundColor Red
    Write-Host "Re-run THIS SAME FILE; it will enter RESUME MODE and push only." -ForegroundColor Yellow
    exit 21
}

& git fetch origin $Branch --no-tags

if ($LASTEXITCODE -ne 0) {
    Write-Host "Verification fetch failed. Re-run THIS SAME FILE." -ForegroundColor Yellow
    exit 21
}

$LocalFinal = ((Get-GitOutput @("rev-parse","HEAD"))[0]).Trim()
$RemoteFinal = ((Get-GitOutput @("rev-parse","origin/$Branch"))[0]).Trim()

$AheadFinal = @(Get-GitOutput @("rev-list","origin/$Branch..HEAD")).Count
$BehindFinal = @(Get-GitOutput @("rev-list","HEAD..origin/$Branch")).Count

$StagedFinal = @(Get-GitOutput @("diff","--cached","--name-only"))
$DeletedFinal = @(Get-GitOutput @("ls-files","--deleted"))

Write-Host ""
Write-Host "LOCAL HEAD      : $LocalFinal"
Write-Host "REMOTE HEAD     : $RemoteFinal"
Write-Host "AHEAD           : $AheadFinal"
Write-Host "BEHIND          : $BehindFinal"
Write-Host "STAGED          : $($StagedFinal.Count)"
Write-Host "DELETED TRACKED : $($DeletedFinal.Count)"

if (
    $LocalFinal -ne $RemoteFinal -or
    $AheadFinal -ne 0 -or
    $BehindFinal -ne 0 -or
    $StagedFinal.Count -ne 0 -or
    $DeletedFinal.Count -ne 0
) {
    Fail "Post-publication verification failed. Do not create another commit."
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host " SGODA RECONCILIATION v2.0.0 : PASS" -ForegroundColor Green
Write-Host " CERTIFIED AUDIT            : 1576 RECORDS" -ForegroundColor Green
Write-Host " VERSIONING CANDIDATES      : 386" -ForegroundColor Green
Write-Host " RUNTIME/IGNORE             : 1160" -ForegroundColor Green
Write-Host " BACKUPS PRESERVED          : 27" -ForegroundColor Green
Write-Host " >=100MB PRESERVED          : 2" -ForegroundColor Green
Write-Host " SECRET REVIEW EXCLUDED     : 1" -ForegroundColor Green
Write-Host " PYTEST                     : $PassedTests PASSED" -ForegroundColor Green
Write-Host " LOCAL/REMOTE               : IDENTICAL" -ForegroundColor Green
Write-Host " STAGING                    : CLEAN" -ForegroundColor Green
Write-Host " PUBLICATION                : COMPLETE" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green

exit 0
