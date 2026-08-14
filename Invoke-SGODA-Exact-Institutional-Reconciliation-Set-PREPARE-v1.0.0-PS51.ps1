$ErrorActionPreference = "Stop"

$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root

$ExpectedHead = "4d463840b2bae0bbc6f18ea869f37e792b69d450"
$Branch = (git branch --show-current).Trim()

$AuditScript = "Invoke-SGODA-Worktree-Institutional-Reconciliation-AUDIT-v1.0.0-PS51.ps1"
$FailedSync  = "Invoke-SGODA-InstitutionalMasterSynchronization-SPT025Reconciliation-FINAL-v1.0.0-PS51.ps1"
$RuntimeState = "artifacts/runtime/sgd002-auto/state.json"

$EvidenceRoot = "artifacts/institutional/master-synchronization/worktree-reconciliation-v1.0.0"

Write-Host ""
Write-Host "============================================================"
Write-Host " SGODA - EXACT INSTITUTIONAL RECONCILIATION SET / PREPARE"
Write-Host "============================================================"

Write-Host ""
Write-Host "[1/10] AUTHORITATIVE BASELINE"

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

$Ahead  = (git rev-list --count "origin/$Branch..HEAD").Trim()
$Behind = (git rev-list --count "HEAD..origin/$Branch").Trim()

if (($Ahead -ne "0") -or ($Behind -ne "0")) {
    throw "Local/remote divergence detected. HOLD."
}

Write-Host "BASELINE_GATE=PASS"
Write-Host "REMOTE_SYNCHRONIZATION=PASS"

Write-Host ""
Write-Host "[2/10] SAFETY GATE"

$Staged = @(git diff --cached --name-only)
$Deleted = @(
    git -c core.longpaths=true -c core.quotepath=false ls-files --deleted
)

if ($Staged.Count -ne 0) {
    throw "Unexpected staged content. HOLD."
}

if ($Deleted.Count -ne 0) {
    throw "Tracked deletion detected. HOLD."
}

Write-Host "STAGED=0"
Write-Host "DELETED_TRACKED=0"
Write-Host "DESTRUCTIVE_OPERATION=NO"
Write-Host "SAFETY_GATE=PASS"

Write-Host ""
Write-Host "[3/10] BUILD TRACKED SHA256 INDEX"

$TrackedFiles = @(
    git -c core.quotepath=false ls-files
)

$TrackedHashIndex = @{}

foreach ($Path in $TrackedFiles) {

    if (Test-Path -LiteralPath $Path -PathType Leaf) {

        try {
            $Hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash

            if (-not $TrackedHashIndex.ContainsKey($Hash)) {
                $TrackedHashIndex[$Hash] = New-Object System.Collections.ArrayList
            }

            [void]$TrackedHashIndex[$Hash].Add($Path)
        }
        catch {
        }
    }
}

Write-Host "TRACKED_FILES_INDEXED=$($TrackedFiles.Count)"
Write-Host "TRACKED_SHA256_INDEX=CREATED"

Write-Host ""
Write-Host "[4/10] CLASSIFY CURRENT UNTRACKED SET"

$Untracked = @(
    git -c core.quotepath=false ls-files --others --exclude-standard
)

$Records = @()

foreach ($Path in $Untracked) {

    $Hash = ""
    $Equivalent = @()
    $Category = "UNIQUE_REVIEW"
    $Disposition = "PRESERVE_FOR_INSTITUTIONAL_REVIEW"
    $Reason = "Unique untracked institutional candidate"

    if (Test-Path -LiteralPath $Path -PathType Leaf) {

        try {
            $Hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash

            if ($TrackedHashIndex.ContainsKey($Hash)) {
                $Equivalent = @($TrackedHashIndex[$Hash])
            }
        }
        catch {
        }
    }

    if ($Equivalent.Count -gt 0) {
        $Category = "EXACT_TRACKED_DUPLICATE"
        $Disposition = "ALREADY_REPRESENTED_IN_REPOSITORY"
        $Reason = "SHA256 identical to tracked repository content"
    }
    elseif ($Path -eq $AuditScript) {
        $Category = "CURRENT_RECONCILIATION_TOOL"
        $Disposition = "INCLUDE_IN_RECONCILIATION_PACKAGE"
        $Reason = "Generated institutional audit tool for current synchronization"
    }
    elseif ($Path -eq $FailedSync) {
        $Category = "FAILED_SUPERSEDED_SYNC_SCRIPT"
        $Disposition = "PRESERVE_AS_FAILED_EXECUTION_EVIDENCE"
        $Reason = "Superseded parser-failed synchronization script"
    }
    elseif ($Path -match '(^|/)backup(/|$)') {
        $Category = "HISTORICAL_BACKUP_UNIQUE"
        $Disposition = "PRESERVE_AS_HISTORICAL_EVIDENCE"
        $Reason = "Unique historical backup not represented by identical tracked content"
    }
    elseif ($Path -match '\.log$') {
        $Category = "RUNTIME_LOG"
        $Disposition = "PRESERVE_PENDING_RUNTIME_POLICY"
        $Reason = "Operational runtime log"
    }
    elseif ($Path -match '\.zip$') {
        $Category = "ARCHIVE_INPUT_UNIQUE"
        $Disposition = "PRESERVE_AS_SOURCE_EVIDENCE"
        $Reason = "Unique historical/source archive"
    }
    elseif ($Path -match '^releases/') {
        $Category = "RELEASE_EVIDENCE_UNIQUE"
        $Disposition = "INCLUDE_AS_RELEASE_EVIDENCE"
        $Reason = "Unique release evidence"
    }
    elseif ($Path -match '^artifacts/') {
        $Category = "ARTIFACT_UNIQUE"
        $Disposition = "INCLUDE_AS_INSTITUTIONAL_EVIDENCE"
        $Reason = "Unique institutional artifact"
    }
    elseif ($Path -match '\.ps1$') {
        $Category = "HISTORICAL_SCRIPT_UNIQUE"
        $Disposition = "PRESERVE_AS_EXECUTION_HISTORY"
        $Reason = "Unique historical PowerShell execution asset"
    }

    $Records += [PSCustomObject]@{
        path = $Path
        category = $Category
        disposition = $Disposition
        sha256 = $Hash
        tracked_equivalent_count = $Equivalent.Count
        tracked_equivalents = @($Equivalent)
        reason = $Reason
    }
}

Write-Host "CURRENT_UNTRACKED=$($Records.Count)"

$Records |
    Group-Object category |
    Sort-Object Name |
    ForEach-Object {
        Write-Host "$($_.Name)=$($_.Count)"
    }

Write-Host ""
Write-Host "[5/10] POLICY DECISION SET"

$AlreadyRepresented = @(
    $Records | Where-Object {
        $_.disposition -eq "ALREADY_REPRESENTED_IN_REPOSITORY"
    }
)

$PreservationSet = @(
    $Records | Where-Object {
        $_.disposition -ne "ALREADY_REPRESENTED_IN_REPOSITORY"
    }
)

$PublicationCandidates = @(
    $Records | Where-Object {
        $_.disposition -in @(
            "INCLUDE_IN_RECONCILIATION_PACKAGE",
            "INCLUDE_AS_RELEASE_EVIDENCE",
            "INCLUDE_AS_INSTITUTIONAL_EVIDENCE"
        )
    }
)

Write-Host "ALREADY_REPRESENTED=$($AlreadyRepresented.Count)"
Write-Host "PRESERVATION_SET=$($PreservationSet.Count)"
Write-Host "DIRECT_PUBLICATION_CANDIDATES=$($PublicationCandidates.Count)"

Write-Host ""
Write-Host "[6/10] SGD002 OPERATIONAL STATE POLICY"

$RuntimeDiff = @(git diff --name-only -- $RuntimeState)

if ($RuntimeDiff.Count -eq 1) {
    $RuntimeDecision = "PRESERVE_WORKTREE_STATE_PENDING_MASTER_SYNC_RECERTIFICATION"
    Write-Host "SGD002_RUNTIME_STATE=MODIFIED"
    Write-Host "SGD002_RUNTIME_DECISION=$RuntimeDecision"
}
else {
    $RuntimeDecision = "UNCHANGED"
    Write-Host "SGD002_RUNTIME_STATE=UNCHANGED"
}

Write-Host ""
Write-Host "[7/10] CREATE RECONCILIATION EVIDENCE"

New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null

$ManifestPath = Join-Path $EvidenceRoot "worktree-reconciliation-manifest.json"
$DecisionPath = Join-Path $EvidenceRoot "institutional-disposition-ledger.json"
$PreparePath  = Join-Path $EvidenceRoot "master-synchronization-recovery-prepare.json"

$Manifest = [ordered]@{
    schema_version = "1.0.0"
    generated_utc = [DateTime]::UtcNow.ToString("o")
    authoritative_head = $ExpectedHead
    branch = $Branch
    local_head = $Local
    remote_head = $Remote
    ahead = [int]$Ahead
    behind = [int]$Behind
    spt025_status = "INSTITUTIONALLY_CLOSED"
    spt025_reopened = $false
    destructive_cleanup_performed = $false
    records = @($Records)
}

$Ledger = [ordered]@{
    schema_version = "1.0.0"
    authoritative_head = $ExpectedHead
    total_untracked = $Records.Count
    already_represented = $AlreadyRepresented.Count
    preservation_set = $PreservationSet.Count
    direct_publication_candidates = $PublicationCandidates.Count
    runtime_state = $RuntimeDecision
    policy = "NON_DESTRUCTIVE_INSTITUTIONAL_RECONCILIATION"
    records = @($Records)
}

$Prepare = [ordered]@{
    schema_version = "1.0.0"
    deliverable = "SGODA-INSTITUTIONAL-MASTER-SYNCHRONIZATION-RECOVERY"
    authoritative_input_head = $ExpectedHead
    baseline_gate = "PASS"
    remote_synchronization = "PASS"
    worktree_reconciliation = "PREPARED"
    spt025_status = "INSTITUTIONALLY_CLOSED"
    preserve_spt025 = $true
    update_sgd000 = $true
    update_sgd002 = $true
    update_master_index = $true
    update_master_registry = $true
    update_nomenclature = $true
    update_traceability_matrix = $true
    reconcile_deliverables = $true
    reconcile_evidence = $true
    reconcile_actas = $true
    reconcile_commits = $true
    reconcile_tags = $true
    reconcile_releases = $true
    allow_destructive_cleanup = $false
    auto_deployment = $false
    production_change = $false
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText(
    (Join-Path $Root $ManifestPath),
    ($Manifest | ConvertTo-Json -Depth 12),
    $Utf8NoBom
)

[System.IO.File]::WriteAllText(
    (Join-Path $Root $DecisionPath),
    ($Ledger | ConvertTo-Json -Depth 12),
    $Utf8NoBom
)

[System.IO.File]::WriteAllText(
    (Join-Path $Root $PreparePath),
    ($Prepare | ConvertTo-Json -Depth 12),
    $Utf8NoBom
)

Write-Host "RECONCILIATION_MANIFEST=CREATED"
Write-Host "DISPOSITION_LEDGER=CREATED"
Write-Host "MASTER_SYNC_RECOVERY_PREPARE=CREATED"

Write-Host ""
Write-Host "[8/10] JSON PREVALIDATION"

foreach ($JsonPath in @($ManifestPath, $DecisionPath, $PreparePath)) {

    try {
        Get-Content -LiteralPath $JsonPath -Raw |
            ConvertFrom-Json |
            Out-Null

        Write-Host "JSON_VALID=$JsonPath"
    }
    catch {
        throw "Invalid JSON generated: $JsonPath"
    }
}

Write-Host "JSON_PREVALIDATION=PASS"

Write-Host ""
Write-Host "[9/10] NON-DESTRUCTIVE PRESERVATION GATE"

$StagedAfter = @(git diff --cached --name-only)
$DeletedAfter = @(
    git -c core.longpaths=true -c core.quotepath=false ls-files --deleted
)

if ($StagedAfter.Count -ne 0) {
    throw "Unexpected staging detected."
}

if ($DeletedAfter.Count -ne 0) {
    throw "Unexpected tracked deletion detected."
}

Write-Host "FILES_DELETED=0"
Write-Host "FILES_STAGED=0"
Write-Host "SPT025_REOPENED=NO"
Write-Host "NON_DESTRUCTIVE_PRESERVATION_GATE=PASS"

Write-Host ""
Write-Host "[10/10] FINAL PREPARE STATUS"

Write-Host "AUTHORITATIVE_BASELINE=PASS"
Write-Host "REMOTE_SYNCHRONIZATION=PASS"
Write-Host "EXACT_RECONCILIATION_SET=PREPARED"
Write-Host "INSTITUTIONAL_DISPOSITION_LEDGER=PREPARED"
Write-Host "SGD002_RUNTIME_POLICY=RECORDED"
Write-Host "SPT025_STATUS=INSTITUTIONALLY_CLOSED"
Write-Host "NEXT_ACTION=RECOVER_INSTITUTIONAL_MASTER_SYNCHRONIZATION"
Write-Host "FINAL_EXIT_CODE=0"

Write-Host ""
Write-Host "============================================================"
Write-Host " EXACT INSTITUTIONAL RECONCILIATION SET PREPARED"
Write-Host "============================================================"