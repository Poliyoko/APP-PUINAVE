$ErrorActionPreference = "Stop"

$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root

$ExpectedHead = "4d463840b2bae0bbc6f18ea869f37e792b69d450"
$Branch = (git branch --show-current).Trim()

Write-Host ""
Write-Host "============================================================"
Write-Host " SGODA - INSTITUTIONAL WORKTREE RECONCILIATION AUDIT"
Write-Host "============================================================"

Write-Host ""
Write-Host "[1/8] AUTHORITATIVE BASELINE"

git fetch origin $Branch
if ($LASTEXITCODE -ne 0) {
    throw "git fetch failed"
}

$Local  = (git rev-parse HEAD).Trim()
$Remote = (git rev-parse "origin/$Branch").Trim()

Write-Host "EXPECTED=$ExpectedHead"
Write-Host "LOCAL=$Local"
Write-Host "REMOTE=$Remote"

if (($Local -ne $ExpectedHead) -or ($Remote -ne $ExpectedHead)) {
    throw "Authoritative baseline changed. HOLD."
}

Write-Host "BASELINE_GATE=PASS"

Write-Host ""
Write-Host "[2/8] WORKTREE INVENTORY"

$Untracked = @(
    git -c core.quotepath=false ls-files --others --exclude-standard
)

$TrackedModified = @(
    git -c core.quotepath=false diff --name-only
)

$Staged = @(
    git diff --cached --name-only
)

$Deleted = @(
    git -c core.longpaths=true `
        -c core.quotepath=false `
        ls-files --deleted
)

Write-Host "UNTRACKED=$($Untracked.Count)"
Write-Host "TRACKED_MODIFIED=$($TrackedModified.Count)"
Write-Host "STAGED=$($Staged.Count)"
Write-Host "DELETED_TRACKED=$($Deleted.Count)"

if ($Staged.Count -ne 0) {
    throw "Unexpected staged content. HOLD."
}

if ($Deleted.Count -ne 0) {
    throw "Tracked deletions detected. HOLD."
}

Write-Host "WORKTREE_SAFETY_GATE=PASS"

Write-Host ""
Write-Host "[3/8] HASH-BASED TRACKED EQUIVALENCE"

$TrackedFiles = @(
    git -c core.quotepath=false ls-files
)

$TrackedHashIndex = @{}

foreach ($TrackedPath in $TrackedFiles) {

    if (Test-Path -LiteralPath $TrackedPath -PathType Leaf) {

        try {
            $Hash = (Get-FileHash -LiteralPath $TrackedPath -Algorithm SHA256).Hash

            if (-not $TrackedHashIndex.ContainsKey($Hash)) {
                $TrackedHashIndex[$Hash] = New-Object System.Collections.ArrayList
            }

            [void]$TrackedHashIndex[$Hash].Add($TrackedPath)
        }
        catch {
        }
    }
}

$Inventory = @()

foreach ($Path in $Untracked) {

    $Category = "UNIQUE_REVIEW"
    $Hash = ""
    $EquivalentTracked = @()

    if (Test-Path -LiteralPath $Path -PathType Leaf) {

        try {
            $Hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash

            if ($TrackedHashIndex.ContainsKey($Hash)) {
                $EquivalentTracked = @($TrackedHashIndex[$Hash])
                $Category = "EXACT_TRACKED_DUPLICATE"
            }
        }
        catch {
        }
    }

    if ($Category -ne "EXACT_TRACKED_DUPLICATE") {

        if ($Path -match '(^|/)backup(/|$)') {
            $Category = "HISTORICAL_BACKUP_UNIQUE"
        }
        elseif ($Path -match '\.log$') {
            $Category = "RUNTIME_LOG_UNIQUE"
        }
        elseif ($Path -match '\.zip$') {
            $Category = "ARCHIVE_INPUT_UNIQUE"
        }
        elseif ($Path -eq "Invoke-SGODA-InstitutionalMasterSynchronization-SPT025Reconciliation-FINAL-v1.0.0-PS51.ps1") {
            $Category = "FAILED_SYNC_SCRIPT"
        }
        elseif ($Path -match '\.ps1$') {
            $Category = "HISTORICAL_SCRIPT_UNIQUE"
        }
        elseif ($Path -match '^releases/') {
            $Category = "RELEASE_EVIDENCE_UNIQUE"
        }
        elseif ($Path -match '^artifacts/') {
            $Category = "ARTIFACT_UNIQUE"
        }
    }

    $Inventory += [PSCustomObject]@{
        Path = $Path
        Category = $Category
        SHA256 = $Hash
        EquivalentTrackedCount = $EquivalentTracked.Count
        EquivalentTrackedPaths = ($EquivalentTracked -join " | ")
    }
}

$Inventory |
    Sort-Object Category, Path |
    Format-Table Category, EquivalentTrackedCount, Path -AutoSize

Write-Host ""
Write-Host "[4/8] HASH CLASSIFICATION COUNTS"

$Inventory |
    Group-Object Category |
    Sort-Object Name |
    ForEach-Object {
        Write-Host "$($_.Name)=$($_.Count)"
    }

Write-Host ""
Write-Host "[5/8] EXACT DUPLICATES"

$ExactDuplicates = @(
    $Inventory |
        Where-Object { $_.Category -eq "EXACT_TRACKED_DUPLICATE" }
)

Write-Host "EXACT_TRACKED_DUPLICATES=$($ExactDuplicates.Count)"

foreach ($Item in $ExactDuplicates) {
    Write-Host "DUPLICATE=$($Item.Path)"
    Write-Host "TRACKED_EQUIVALENT=$($Item.EquivalentTrackedPaths)"
}

Write-Host ""
Write-Host "[6/8] UNIQUE INSTITUTIONAL CANDIDATES"

$UniqueCandidates = @(
    $Inventory |
        Where-Object {
            $_.Category -notin @(
                "EXACT_TRACKED_DUPLICATE",
                "RUNTIME_LOG_UNIQUE",
                "FAILED_SYNC_SCRIPT"
            )
        }
)

Write-Host "UNIQUE_INSTITUTIONAL_CANDIDATES=$($UniqueCandidates.Count)"

$UniqueCandidates |
    Group-Object Category |
    Sort-Object Name |
    ForEach-Object {
        Write-Host "CANDIDATE_$($_.Name)=$($_.Count)"
    }

Write-Host ""
Write-Host "[7/8] SGD002 OPERATIONAL STATE"

$RuntimeState = "artifacts/runtime/sgd002-auto/state.json"

$RuntimeModified = @(
    git diff --name-only -- $RuntimeState
)

if ($RuntimeModified.Count -eq 1) {
    Write-Host "SGD002_RUNTIME_STATE=MODIFIED_OPERATIONAL_STATE"
    Write-Host "SGD002_RUNTIME_STATE_ACTION=REQUIRES_EXPLICIT_POLICY_DECISION"
}
else {
    Write-Host "SGD002_RUNTIME_STATE=UNCHANGED"
}

Write-Host ""
Write-Host "[8/8] FINAL RECONCILIATION AUDIT GATE"

$Ahead  = (git rev-list --count "origin/$Branch..HEAD").Trim()
$Behind = (git rev-list --count "HEAD..origin/$Branch").Trim()

Write-Host "AHEAD=$Ahead"
Write-Host "BEHIND=$Behind"
Write-Host "STAGED=$($Staged.Count)"
Write-Host "DELETED_TRACKED=$($Deleted.Count)"
Write-Host "UNTRACKED=$($Untracked.Count)"
Write-Host "EXACT_TRACKED_DUPLICATES=$($ExactDuplicates.Count)"
Write-Host "UNIQUE_INSTITUTIONAL_CANDIDATES=$($UniqueCandidates.Count)"

if (
    ($Local -eq $ExpectedHead) -and
    ($Remote -eq $ExpectedHead) -and
    ($Ahead -eq "0") -and
    ($Behind -eq "0") -and
    ($Staged.Count -eq 0) -and
    ($Deleted.Count -eq 0)
) {
    Write-Host "AUTHORITATIVE_BASELINE=PASS"
    Write-Host "REMOTE_SYNCHRONIZATION=PASS"
    Write-Host "NON_DESTRUCTIVE_RECONCILIATION_AUDIT=PASS"
    Write-Host "NEXT_ACTION=BUILD_EXACT_INSTITUTIONAL_RECONCILIATION_SET"
}
else {
    Write-Host "NON_DESTRUCTIVE_RECONCILIATION_AUDIT=HOLD"
}

Write-Host ""
Write-Host "SPT025_REOPENED=NO"
Write-Host "FILES_DELETED=0"
Write-Host "FILES_STAGED=0"
Write-Host "FILES_COMMITTED=0"
Write-Host "FILES_PUSHED=0"

Write-Host ""
Write-Host "============================================================"
Write-Host " RECONCILIATION AUDIT COMPLETED"
Write-Host "============================================================"