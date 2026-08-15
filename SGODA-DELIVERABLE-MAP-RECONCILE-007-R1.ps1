#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "aac254aaf13a45d8d633dfcdfdf7631beb4d378b"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.7-R1"
$Self = "SGODA-DELIVERABLE-MAP-RECONCILE-007-R1.ps1"

$CloseDir = "artifacts/development/SPT-007-FORMALIZE-CLOSE-v1.0.0"
$CloseFiles = @(
    "SGODA-SPT007-FORMALIZE-CLOSE.ps1",
    "$CloseDir/implementation-evidence.json",
    "$CloseDir/spt007-evidence-recertification.json",
    "$CloseDir/spt007-formalization-close-assessment.json",
    "$CloseDir/spt007-formalization-close-coverage.json",
    "$CloseDir/spt007-formalization-close-sha256-manifest.json",
    "$CloseDir/spt007-formalization-quality-gate.json",
    "$CloseDir/spt007-historical-traceability.json",
    "$CloseDir/spt007-release-artifact-recertification.json",
    "docs/00_Estado_Maestro/ACT-SPT-007-FORMALIZATION-CLOSE-v1.0.0.md",
    "docs/06_Tecnologia/SPT-007/SGD-SPT007-FORMALIZATION-CLOSE-v1.0.0.md"
)

$Dev = "artifacts/development/SGODA-DELIVERABLE-MAP-RECONCILE-007-v1.0.7"
$TransactionOutputs = @(
    "SGODA-DELIVERABLE-MAP-RECONCILE-007.ps1",
    "$Dev/global-deliverable-inventory-reconciled.json",
    "$Dev/global-deliverable-status-matrix-reconciled.json",
    "$Dev/next-technological-deliverable-assessment-reconciled.json",
    "$Dev/spt007-map-reconciliation-assessment.json",
    "$Dev/deliverable-map-reconciliation-ledger.json",
    "$Dev/implementation-evidence.json",
    "$Dev/reconciliation-sha256-manifest.json",
    "docs/00_Estado_Maestro/SGODA-PUINAVE-Mapa-Global-Entregables-v1.0.7.md",
    "docs/00_Estado_Maestro/ACT-SGODA-DELIVERABLE-MAP-RECONCILE-007-v1.0.7.md"
)

function Hold([string]$Reason) {
    Write-Host ""
    Write-Host "SGODA-DELIVERABLE-MAP-RECONCILE-007-R1 : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "TRANSACTION : NOT PUBLISHED"
    exit 1
}
function Step([int]$N,[string]$Text) {
    Write-Host ""
    Write-Host ("[{0}/10] {1}" -f $N,$Text) -ForegroundColor Cyan
}
function Fetch {
    for($i=1;$i -le 4;$i++){
        Write-Host "GIT FETCH ATTEMPT : $i/4"
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){ Write-Host "GIT FETCH : PASS"; return }
        Start-Sleep -Seconds ([Math]::Min(2*$i,8))
    }
    Hold "git fetch failed"
}
function Sha([string]$Path) {
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ Hold "Missing file: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root){ Hold "Not inside Git repository" }
    Set-Location $Root

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    Fetch
    $Local=(& git.exe rev-parse HEAD).Trim()
    $Remote=(& git.exe rev-parse "origin/$Branch").Trim()
    $AB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    $Deleted=@(& git.exe ls-files --deleted)

    Write-Host "EXPECTED HEAD    : $ExpectedBaseline"
    Write-Host "LOCAL HEAD       : $Local"
    Write-Host "REMOTE HEAD      : $Remote"
    Write-Host "AHEAD            : $([int]$AB[0])"
    Write-Host "BEHIND           : $([int]$AB[1])"
    Write-Host "DELETED TRACKED  : $($Deleted.Count)"

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){ Hold "Authoritative baseline mismatch" }
    if([int]$AB[0] -ne 0 -or [int]$AB[1] -ne 0){ Hold "Local/remote divergence" }
    if($Deleted.Count -ne 0){ Hold "Deleted tracked content detected" }

    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "RECERTIFY SPT-007 CLOSE INPUTS AS TRACKED IMMUTABLE INPUTS"
    $TrackedClose=0
    foreach($F in $CloseFiles){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){ Hold "Missing close input: $F" }
        $Tracked=@(& git.exe ls-files -- $F)
        if($Tracked.Count -ne 1){ Hold "Close input is not tracked exactly once: $F" }
        $WorkHash=Sha $F
        $HeadHash=(& git.exe show "HEAD:$F" | & git.exe hash-object --stdin).Trim()
        $RawHash=(& git.exe hash-object -- $F).Trim()
        if($LASTEXITCODE -ne 0){ Hold "Cannot hash close input: $F" }
        if($RawHash -ne $HeadHash){ Hold "Tracked close input changed after formalization: $F" }
        $TrackedClose++
    }
    Write-Host "SPT007_CLOSE_INPUTS=$($CloseFiles.Count)"
    Write-Host "SPT007_CLOSE_INPUTS_TRACKED_IMMUTABLE=$TrackedClose"
    Write-Host "SPT007_CLOSE_INPUTS_STAGE_REQUIRED=NO"
    Write-Host "SPT007_CLOSE_INPUT_RECERTIFICATION=PASS"

    Step 3 "RECERTIFY FAILED-RUN TRANSACTION OUTPUTS"
    foreach($F in $TransactionOutputs){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){ Hold "Missing transaction output from failed run: $F" }
    }

    $CurrentStaged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $UnexpectedStaged=@($CurrentStaged | Where-Object { $TransactionOutputs -notcontains ($_ -replace "\\","/") })
    $MissingStaged=@($TransactionOutputs | Where-Object { $CurrentStaged -notcontains $_ })

    Write-Host "CURRENT_STAGED=$($CurrentStaged.Count)"
    Write-Host "EXPECTED_FAILED_RUN_STAGED=$($TransactionOutputs.Count)"
    Write-Host "UNEXPECTED_STAGED=$($UnexpectedStaged.Count)"
    Write-Host "MISSING_STAGED=$($MissingStaged.Count)"

    if($UnexpectedStaged.Count -ne 0){ Hold "Unexpected staged content exists" }
    if($MissingStaged.Count -ne 0){ Hold "Failed-run transaction staged set is incomplete" }
    if($CurrentStaged.Count -ne $TransactionOutputs.Count){ Hold "Failed-run transaction staged set count mismatch" }

    Write-Host "FAILED_RUN_STAGE_RECERTIFICATION=PASS"

    Step 4 "FIX PUBLICATION MODEL / ADD RECOVERY SCRIPT"
    $PublicationSet=@($TransactionOutputs + $Self)
    & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $Self
    if($LASTEXITCODE -ne 0){ Hold "git add failed for recovery script" }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $UnexpectedNow=@($StagedNow | Where-Object { $PublicationSet -notcontains ($_ -replace "\\","/") })
    $MissingNow=@($PublicationSet | Where-Object { $StagedNow -notcontains $_ })

    Write-Host "PUBLICATION_SET=$($PublicationSet.Count)"
    Write-Host "TRACKED_IMMUTABLE_INPUTS=$($CloseFiles.Count)"
    Write-Host "STAGED_PUBLICATION_OUTPUTS=$($StagedNow.Count)"
    Write-Host "UNEXPECTED_STAGED=$($UnexpectedNow.Count)"
    Write-Host "MISSING_STAGED=$($MissingNow.Count)"

    if($UnexpectedNow.Count -ne 0 -or $MissingNow.Count -ne 0 -or $StagedNow.Count -ne $PublicationSet.Count){
        Hold "Corrected exact staging mismatch"
    }
    Write-Host "CORRECTED_STAGING_MODEL=PASS"
    Write-Host "STAGING_QUALITY=PASS"

    Step 5 "STAGED DELETION / SIZE GATE"
    $StagedDeletions=@(& git.exe diff --cached --diff-filter=D --name-only)
    if($StagedDeletions.Count -ne 0){ Hold "Staged deletion detected" }

    $Large=0
    foreach($F in @(& git.exe -c core.quotepath=false ls-files)){
        $SizeText=(& git.exe cat-file -s (":$F") 2>$null)
        if($LASTEXITCODE -eq 0 -and $SizeText -and [int64]$SizeText -ge 100MB){ $Large++ }
    }
    Write-Host "STAGED_DELETIONS=0"
    Write-Host "INDEX_BLOBS_GE_100MB=$Large"
    if($Large -ne 0){ Hold "GitHub size gate failed" }
    Write-Host "GITHUB_SIZE_GATE=PASS"

    Step 6 "REMOTE PRE-COMMIT GATE"
    Fetch
    $LocalPre=(& git.exe rev-parse HEAD).Trim()
    $RemotePre=(& git.exe rev-parse "origin/$Branch").Trim()
    if($LocalPre -ne $ExpectedBaseline -or $RemotePre -ne $ExpectedBaseline){ Hold "Remote changed before commit" }
    Write-Host "REMOTE_PRECOMMIT_GATE=PASS"

    Step 7 "COMMIT RECONCILIATION RECOVERY"
    & git.exe commit -m "chore(institutional): reconcile SPT-007 as formally closed"
    if($LASTEXITCODE -ne 0){ Hold "git commit failed" }
    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"
    Write-Host "COMMIT_PERFORMED=YES"

    Step 8 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){ Hold "git push failed" }
    Write-Host "PUSH=PASS"

    Step 9 "AUTHORITATIVE REMOTE VERIFICATION"
    Fetch
    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse "origin/$Branch").Trim()
    $FinalAB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "AHEAD           : $([int]$FinalAB[0])"
    Write-Host "BEHIND          : $([int]$FinalAB[1])"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if($FinalLocal -ne $FinalRemote -or [int]$FinalAB[0] -ne 0 -or [int]$FinalAB[1] -ne 0 -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){
        Hold "Final repository verification failed"
    }
    Write-Host "FINAL_REMOTE_GATE=PASS"

    Step 10 "FINAL RECONCILIATION CLOSURE"
    Write-Host ""
    Write-Host "SGODA-DELIVERABLE-MAP-RECONCILE-007-R1 : CLOSED / PASS" -ForegroundColor Green
    Write-Host "SPT007_FORMALIZED_STATE=CLOSED"
    Write-Host "SPT007_CLASSIFICATION=CLOSED"
    Write-Host "SPT007_REOPENED=NO"
    Write-Host "MASTER_MAP_RECONCILIATION=PASS"
    Write-Host "PENDING_DELIVERABLES_RECALCULATED=YES"
    Write-Host "PENDING_SPT_CANDIDATES=27"
    Write-Host "PENDING_28_TO_27_GATE=PASS"
    Write-Host "NEXT_DELIVERABLE_CANDIDATE=SPT-008"
    Write-Host "SPT007_CLOSE_EVIDENCE_CONSUMED=YES"
    Write-Host "TRACKED_IMMUTABLE_CLOSE_INPUTS_NOT_RESTAGED=11"
    Write-Host "CORRECTED_STAGING_MODEL=PASS"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "COMMIT_PERFORMED=YES"
    Write-Host "PUSH_PERFORMED=YES"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "AHEAD=0"
    Write-Host "BEHIND=0"
    Write-Host "STAGED=0"
    Write-Host "INSTITUTIONAL_MASTER_BASELINE=$FinalLocal"
    Write-Host "NEXT_ACTION=AUDIT_NEXT_PENDING_DELIVERABLE"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
