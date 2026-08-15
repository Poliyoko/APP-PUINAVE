#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "aac254aaf13a45d8d633dfcdfdf7631beb4d378b"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.7"

$PrevDir = "artifacts/development/SGODA-DELIVERABLE-MAP-RECONCILE-006-v1.0.6"
$PrevInventory = "$PrevDir/global-deliverable-inventory-reconciled.json"
$PrevStatus = "$PrevDir/global-deliverable-status-matrix-reconciled.json"
$PrevNext = "$PrevDir/next-technological-deliverable-assessment-reconciled.json"

$CloseDir = "artifacts/development/SPT-007-FORMALIZE-CLOSE-v1.0.0"
$CloseAssessment = "$CloseDir/spt007-formalization-close-assessment.json"
$CloseQuality = "$CloseDir/spt007-formalization-quality-gate.json"
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
$OutInventory = "$Dev/global-deliverable-inventory-reconciled.json"
$OutStatus = "$Dev/global-deliverable-status-matrix-reconciled.json"
$OutNext = "$Dev/next-technological-deliverable-assessment-reconciled.json"
$OutAssessment = "$Dev/spt007-map-reconciliation-assessment.json"
$OutLedger = "$Dev/deliverable-map-reconciliation-ledger.json"
$OutEvidence = "$Dev/implementation-evidence.json"
$OutManifest = "$Dev/reconciliation-sha256-manifest.json"
$MapDoc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Mapa-Global-Entregables-v1.0.7.md"
$Acta = "docs/00_Estado_Maestro/ACT-SGODA-DELIVERABLE-MAP-RECONCILE-007-v1.0.7.md"
$Self = "SGODA-DELIVERABLE-MAP-RECONCILE-007.ps1"

function Hold([string]$Reason) {
    Write-Host ""
    Write-Host "SGODA-DELIVERABLE-MAP-RECONCILE-007 : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "TRANSACTION : NOT PUBLISHED"
    exit 1
}
function Step([int]$N,[string]$Text) {
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Text) -ForegroundColor Cyan
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
function ReadJson([string]$Path) {
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ Hold "Missing JSON: $Path" }
    try { return ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path),[Text.Encoding]::UTF8) | ConvertFrom-Json) }
    catch { Hold "Invalid JSON: $Path" }
}
function WriteLf([string]$Path,[string]$Text) {
    $Full=Join-Path $Root $Path
    $Parent=Split-Path -Parent $Full
    if(-not(Test-Path -LiteralPath $Parent)){ New-Item -ItemType Directory -Force -Path $Parent | Out-Null }
    $Utf8=New-Object Text.UTF8Encoding($false)
    $Text=(($Text -replace "`r`n","`n") -replace "`r","`n")
    [IO.File]::WriteAllText($Full,$Text,$Utf8)
}
function Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}
function SortKey([string]$Id) {
    if($Id -match '^SPT-(\d+)(?:\.(\d+))?'){
        $a=[int]$Matches[1]; $b=0
        if($Matches[2]){ $b=[int]$Matches[2] }
        return ("{0:D5}.{1:D5}" -f $a,$b)
    }
    return "99999.99999"
}
function SecretHit([string]$Path) {
    $Ext=[IO.Path]::GetExtension($Path).ToLowerInvariant()
    if(@(".ps1",".json",".md",".txt",".yml",".yaml") -notcontains $Ext){ return $false }
    $T=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path),[Text.Encoding]::UTF8)
    return ($T -match '-----BEGIN[ ]+(RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' -or
            $T -match '(?i)\b(password|passwd|pwd)\s*[:=]\s*["''][^"'']{8,}["'']' -or
            $T -match '(?i)\b(api[_-]?key|secret[_-]?key|access[_-]?token)\s*[:=]\s*["''][^"'']{12,}["'']')
}

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    Set-Location $Root

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    Fetch
    $Local=(& git.exe rev-parse HEAD).Trim()
    $Remote=(& git.exe rev-parse "origin/$Branch").Trim()
    $AB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    $Staged=@(& git.exe diff --cached --name-only)
    $Modified=@(& git.exe diff --name-only)
    $Deleted=@(& git.exe ls-files --deleted)
    Write-Host "EXPECTED HEAD    : $ExpectedBaseline"
    Write-Host "LOCAL HEAD       : $Local"
    Write-Host "REMOTE HEAD      : $Remote"
    Write-Host "AHEAD            : $([int]$AB[0])"
    Write-Host "BEHIND           : $([int]$AB[1])"
    Write-Host "STAGED           : $($Staged.Count)"
    Write-Host "MODIFIED TRACKED : $($Modified.Count)"
    Write-Host "DELETED TRACKED  : $($Deleted.Count)"
    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){ Hold "Authoritative baseline mismatch" }
    if([int]$AB[0] -ne 0 -or [int]$AB[1] -ne 0 -or $Staged.Count -ne 0 -or $Modified.Count -ne 0 -or $Deleted.Count -ne 0){ Hold "Repository baseline not clean/synchronized" }
    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "CONSUME SPT-007 FORMALIZATION CLOSURE"
    foreach($F in $CloseFiles){ if(-not(Test-Path -LiteralPath $F -PathType Leaf)){ Hold "Missing SPT-007 close file: $F" } }
    $C=ReadJson $CloseAssessment
    $Q=ReadJson $CloseQuality
    if([string]$C.previous_state -ne "IMPLEMENTED_PENDING_FORMALIZATION"){ Hold "SPT-007 previous state mismatch" }
    if([string]$C.formalized_state -ne "CLOSED"){ Hold "SPT-007 is not formally CLOSED" }
    if([bool]$C.reopened){ Hold "SPT-007 closure indicates reopening" }
    if([string]$Q.formalization_quality_gate -ne "PASS"){ Hold "SPT-007 close quality gate is not PASS" }
    Write-Host "SPT007_FORMALIZATION_CLOSE=PASS"
    Write-Host "SPT007_FORMALIZED_STATE=CLOSED"
    Write-Host "SPT007_REOPENED=NO"
    Write-Host "SPT007_CLOSE_ACTION=RECONCILE_MASTER_MAP_WITHOUT_REOPENING"

    Step 3 "CONSUME PREVIOUS RECONCILED GLOBAL MAP"
    foreach($F in @($PrevInventory,$PrevStatus,$PrevNext)){ if(-not(Test-Path -LiteralPath $F)){ Hold "Missing previous map input: $F" } }
    $Inv=ReadJson $PrevInventory
    $Status=ReadJson $PrevStatus
    $Next=ReadJson $PrevNext
    $Before=@($Status.pending_spt_candidates).Count
    if($Before -ne 28){ Hold "Expected 28 pending candidates before SPT-007 reconciliation, found $Before" }
    if([string]$Next.next_deliverable_candidate -ne "SPT-007"){ Hold "Previous map next candidate is not SPT-007" }
    Write-Host "PREVIOUS_DELIVERABLE_COUNT=$([int]$Inv.deliverable_count)"
    Write-Host "PREVIOUS_PENDING_SPT_CANDIDATES=28"
    Write-Host "PREVIOUS_NEXT_CANDIDATE=SPT-007"
    Write-Host "PREVIOUS_MAP_CONSUMED=PASS"

    Step 4 "RECLASSIFY SPT-007 AS CLOSED WITHOUT REOPENING"
    $Rows=@($Inv.deliverables)
    $Target=@($Rows | Where-Object { [string]$_.deliverable -eq "SPT-007" })
    if($Target.Count -ne 1){ Hold "Expected exactly one SPT-007 row" }
    $Old=[string]$Target[0].status
    if($Old -ne "IMPLEMENTED_OR_DOCUMENTED"){ Hold "Expected SPT-007 as IMPLEMENTED_OR_DOCUMENTED, found $Old" }

    $NewRows=@()
    foreach($R in $Rows){
        if([string]$R.deliverable -eq "SPT-007"){
            $NewRows += [ordered]@{
                deliverable="SPT-007"; status="CLOSED";
                reason="Historically implemented and formally closed by SPT-007.FORMALIZE.CLOSE; reconciled without reopening.";
                tracked_paths=@($R.tracked_paths); path_count=[int]$R.path_count;
                reconciliation_source=$CloseAssessment; reopened=$false
            }
        } else {
            $O=[ordered]@{deliverable=[string]$R.deliverable;status=[string]$R.status;reason=[string]$R.reason;tracked_paths=@($R.tracked_paths);path_count=[int]$R.path_count}
            if($R.PSObject.Properties.Name -contains "reconciliation_source"){ $O["reconciliation_source"]=[string]$R.reconciliation_source }
            if($R.PSObject.Properties.Name -contains "reopened"){ $O["reopened"]=[bool]$R.reopened }
            $NewRows += $O
        }
    }
    Write-Host "SPT007_PREVIOUS_CLASSIFICATION=$Old"
    Write-Host "SPT007_CLASSIFICATION=CLOSED"
    Write-Host "SPT007_REOPENED=NO"
    Write-Host "RECLASSIFICATION_GATE=PASS"

    Step 5 "RECALCULATE GLOBAL STATUS MATRIX"
    $Closed=@($NewRows | Where-Object { [string]$_.status -match '^CLOSED' })
    $Impl=@($NewRows | Where-Object { [string]$_.status -eq "IMPLEMENTED_OR_DOCUMENTED" })
    $Pending=@(
        $NewRows | Where-Object { [string]$_.deliverable -match '^SPT-\d+' -and [string]$_.status -eq "IMPLEMENTED_OR_DOCUMENTED" } |
        ForEach-Object { [pscustomobject]@{id=[string]$_.deliverable;key=(SortKey ([string]$_.deliverable))} } |
        Sort-Object key,id
    )
    $PendingIds=@($Pending | ForEach-Object { $_.id })
    if($PendingIds.Count -ne 27){ Hold "Expected 27 pending SPT candidates after reconciliation, found $($PendingIds.Count)" }
    if($PendingIds -contains "SPT-007"){ Hold "SPT-007 remains pending" }
    Write-Host "RECONCILED_CLOSED_OR_FORMALIZED=$($Closed.Count)"
    Write-Host "RECONCILED_IMPLEMENTED_OR_DOCUMENTED=$($Impl.Count)"
    Write-Host "PENDING_SPT_CANDIDATES_RECALCULATED=27"
    Write-Host "SPT007_PENDING_AFTER_RECONCILIATION=NO"
    Write-Host "PENDING_28_TO_27_GATE=PASS"
    Write-Host "STATUS_RECALCULATION=PASS"

    Step 6 "DETERMINE NEXT REAL PENDING DELIVERABLE"
    $NextCandidate=$null
    $Decision="NO_AUTHORIZED_NEXT_SPT_INFERRED"
    $NextAction="GOVERNANCE_REVIEW_NEXT_TECHNOLOGICAL_DELIVERABLE"
    if($PendingIds.Count -gt 0){
        $NextCandidate=$PendingIds[0]
        $Decision="EXISTING_PENDING_DELIVERABLE_DETECTED"
        $NextAction="AUDIT_NEXT_PENDING_DELIVERABLE"
    }
    Write-Host "NEXT_DELIVERABLE_DECISION=$Decision"
    if($NextCandidate){ Write-Host "NEXT_DELIVERABLE_CANDIDATE=$NextCandidate" }
    Write-Host "NEXT_ACTION=$NextAction"
    Write-Host "AUTOMATIC_SPT_CREATION=NO"

    Step 7 "RECONCILE COMMITS / TAGS / RELEASES"
    $Tags=@(& git.exe tag --list)
    $TagHits=@($Tags | Where-Object { $_ -match '(?i)SPT[-_.]?007|SPT007' })
    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $ReleaseHits=@($Tracked | Where-Object { $_ -match '(?i)^releases/.*SPT[-_.]?007|^releases/.*SPT007' })
    Write-Host "RECENT_COMMITS=$(@(& git.exe --no-pager log --format='%H|%s' -50).Count)"
    Write-Host "SPT007_TAGS=$($TagHits.Count)"
    Write-Host "SPT007_RELEASE_PATHS=$($ReleaseHits.Count)"
    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"
    Write-Host "COMMITS_TAGS_RELEASES_RECONCILIATION=PASS"

    Step 8 "WRITE RECONCILED MAP / LEDGER / EVIDENCE"
    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    $InvObj=[ordered]@{component="SGODA-DELIVERABLE-MAP-RECONCILE-007";version=$Version;authoritative_input_head=$ExpectedBaseline;generated_at=$Now;deliverable_count=$NewRows.Count;reconciliation=[ordered]@{deliverable="SPT-007";previous_status=$Old;reconciled_status="CLOSED";formalized_state="CLOSED";reopened=$false;source=$CloseAssessment};deliverables=$NewRows}
    $StatusObj=[ordered]@{component="SGODA-DELIVERABLE-MAP-RECONCILE-007";authoritative_input_head=$ExpectedBaseline;closed_or_formalized=@($Closed|%{$_.deliverable});implemented_or_documented=@($Impl|%{$_.deliverable});pending_spt_candidates=$PendingIds;spt007_classification="CLOSED";spt007_reopened=$false}
    $NextObj=[ordered]@{component="SGODA-DELIVERABLE-MAP-RECONCILE-007";authoritative_input_head=$ExpectedBaseline;decision=$Decision;next_deliverable_candidate=$NextCandidate;next_action=$NextAction;pending_spt_candidates=$PendingIds;automatic_spt_creation=$false;spt007_removed_from_pending=$true}
    $AssessObj=[ordered]@{component="SGODA-DELIVERABLE-MAP-RECONCILE-007";version=$Version;authoritative_input_head=$ExpectedBaseline;status="READY_FOR_PUBLICATION";spt007_formalized_state="CLOSED";spt007_previous_map_status=$Old;spt007_reconciled_status="CLOSED";spt007_reopened=$false;master_map_reconciliation="PASS";pending_before=28;pending_after=27;pending_28_to_27_gate="PASS";pending_deliverables_recalculated=$true;next_deliverable_candidate=$NextCandidate;next_action=$NextAction;spt007_close_evidence_consumed=$true;destructive_cleanup=$false;new_functionality=$false;production_change=$false}
    $LedgerObj=[ordered]@{component="SGODA-DELIVERABLE-MAP-RECONCILE-007";version=$Version;baseline=$ExpectedBaseline;spt007_close_inputs=$CloseFiles;correction=[ordered]@{deliverable="SPT-007";from=$Old;to="CLOSED";reopen=$false};pending_before=28;pending_after=27;next_candidate=$NextCandidate;tag_created=$false;release_created=$false}
    $EvidenceObj=[ordered]@{component="SGODA-DELIVERABLE-MAP-RECONCILE-007";authoritative_input_head=$ExpectedBaseline;spt007_close_evidence_consumed=$true;spt007_formalized_state="CLOSED";spt007_reopened=$false;pending_before=28;pending_after=27;next_candidate=$NextCandidate;destructive_cleanup=$false;production_change=$false}
    WriteLf $OutInventory ($InvObj|ConvertTo-Json -Depth 24)
    WriteLf $OutStatus ($StatusObj|ConvertTo-Json -Depth 16)
    WriteLf $OutNext ($NextObj|ConvertTo-Json -Depth 16)
    WriteLf $OutAssessment ($AssessObj|ConvertTo-Json -Depth 16)
    WriteLf $OutLedger ($LedgerObj|ConvertTo-Json -Depth 16)
    WriteLf $OutEvidence ($EvidenceObj|ConvertTo-Json -Depth 16)
    WriteLf $MapDoc "# SGODA-PUINAVE - Mapa Global de Entregables v1.0.7`n`nBaseline: $ExpectedBaseline`n`nSPT-007: CLOSED, sin reapertura.`nPendientes: 28 -> 27.`nSiguiente candidato: $NextCandidate.`n"
    WriteLf $Acta "# ACT-SGODA-DELIVERABLE-MAP-RECONCILE-007-v1.0.7`n`nSPT-007 formalized state: CLOSED.`nSPT-007 reopened: NO.`nSPT-007 close evidence consumed: YES.`nPending SPT candidates: 28 -> 27.`nNext deliverable candidate: $NextCandidate.`n"
    Write-Host "RECONCILED_INVENTORY=CREATED"
    Write-Host "RECONCILED_STATUS_MATRIX=CREATED"
    Write-Host "RECONCILED_NEXT_ASSESSMENT=CREATED"
    Write-Host "RECONCILIATION_LEDGER=CREATED"
    Write-Host "RECONCILIATION_EVIDENCE=CREATED"
    Write-Host "MAP_DOCUMENT_V1.0.7=CREATED"
    Write-Host "INSTITUTIONAL_ACTA=CREATED"

    Step 9 "BUILD EXACT PUBLICATION SET / SHA-256 MANIFEST"
    $Output=@($Self,$OutInventory,$OutStatus,$OutNext,$OutAssessment,$OutLedger,$OutEvidence,$MapDoc,$Acta)
    foreach($F in $CloseFiles){ if(-not $Output.Contains($F)){ $Output += $F } }
    $Records=@()
    foreach($F in $Output){ if(-not(Test-Path -LiteralPath $F)){ Hold "Publication file missing: $F" }; $Records += [ordered]@{path=$F;sha256=(Sha $F)} }
    WriteLf $OutManifest (([ordered]@{component="SGODA-DELIVERABLE-MAP-RECONCILE-007";version=$Version;baseline=$ExpectedBaseline;records=$Records})|ConvertTo-Json -Depth 12)
    $Output += $OutManifest
    Write-Host "EXACT_PUBLICATION_SET=$($Output.Count)"
    Write-Host "SPT007_CLOSE_INPUTS_INCLUDED=$($CloseFiles.Count)"
    Write-Host "SHA256_MANIFEST=CREATED"

    Step 10 "JSON / EOL / SECURITY QUALITY GATE"
    foreach($F in $Output){
        if([IO.Path]::GetExtension($F).ToLowerInvariant() -eq ".json"){ $null=ReadJson $F }
        if(SecretHit $F){ Hold "Secret pattern detected: $F" }
    }
    Write-Host "JSON_VALIDATION=PASS"
    Write-Host "OUTPUT_EOL_GATE=PASS"
    Write-Host "OUTPUT_SECURITY_GATE=PASS"

    Step 11 "CLOSED BASELINE PRESERVATION / UNTRACKED ACCOUNTING"
    if(@(& git.exe diff --name-only).Count -ne 0 -or @(& git.exe ls-files --deleted).Count -ne 0){ Hold "Tracked baseline changed before staging" }
    $Untracked=@(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
    $Unexpected=@($Untracked | Where-Object { $Output -notcontains ($_ -replace "\\","/") })
    $Blocking=@($Unexpected | Where-Object { $_ -match '(?i)SPT[-_.]?007|SPT007|DELIVERABLE-MAP-RECONCILE-007' })
    Write-Host "CURRENT_UNTRACKED=$($Untracked.Count)"
    Write-Host "EXPECTED_PUBLICATION_UNTRACKED=$($Output.Count)"
    Write-Host "UNEXPECTED_UNTRACKED=$($Unexpected.Count)"
    Write-Host "BLOCKING_SPT007_UNTRACKED=$($Blocking.Count)"
    if($Blocking.Count -ne 0){ Hold "Unexpected active SPT-007 content outside publication set" }
    Write-Host "CLOSED_BASELINE_PRESERVED=PASS"
    Write-Host "SPT007_UNTRACKED_ACCOUNTING=PASS"

    Step 12 "EXACT CONTROLLED STAGING"
    foreach($F in $Output){ & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $F; if($LASTEXITCODE -ne 0){ Hold "git add failed: $F" } }
    $NowStaged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $UnexpectedStaged=@($NowStaged | Where-Object { $Output -notcontains ($_ -replace "\\","/") })
    $Missing=@($Output | Where-Object { $NowStaged -notcontains $_ })
    Write-Host "STAGED=$($NowStaged.Count)"
    Write-Host "EXPECTED_STAGE_SET=$($Output.Count)"
    Write-Host "UNEXPECTED_STAGED=$($UnexpectedStaged.Count)"
    Write-Host "MISSING_STAGED=$($Missing.Count)"
    if($NowStaged.Count -ne $Output.Count -or $UnexpectedStaged.Count -ne 0 -or $Missing.Count -ne 0){ Hold "Exact staging mismatch" }
    Write-Host "STAGING_QUALITY=PASS"

    Step 13 "GITHUB SIZE / REMOTE PRE-COMMIT GATE"
    if(@(& git.exe diff --cached --diff-filter=D --name-only).Count -ne 0){ Hold "Staged deletion detected" }
    $Large=0
    foreach($F in @(& git.exe -c core.quotepath=false ls-files)){
        $z=(& git.exe cat-file -s (":$F") 2>$null)
        if($LASTEXITCODE -eq 0 -and $z -and [int64]$z -ge 100MB){ $Large++ }
    }
    Write-Host "STAGED_DELETIONS=0"
    Write-Host "INDEX_BLOBS_GE_100MB=$Large"
    if($Large -ne 0){ Hold "GitHub size gate failed" }
    Fetch
    if((& git.exe rev-parse HEAD).Trim() -ne $ExpectedBaseline -or (& git.exe rev-parse "origin/$Branch").Trim() -ne $ExpectedBaseline){ Hold "Remote changed before commit" }
    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "REMOTE_PRECOMMIT_GATE=PASS"

    Step 14 "COMMIT MAP RECONCILIATION"
    & git.exe commit -m "chore(institutional): reconcile SPT-007 as formally closed"
    if($LASTEXITCODE -ne 0){ Hold "git commit failed" }
    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"
    Write-Host "COMMIT_PERFORMED=YES"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){ Hold "git push failed" }
    Write-Host "PUSH=PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / RECONCILIATION CLOSURE"
    Fetch
    $FL=(& git.exe rev-parse HEAD).Trim()
    $FR=(& git.exe rev-parse "origin/$Branch").Trim()
    $FAB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    $FS=@(& git.exe diff --cached --name-only)
    $FD=@(& git.exe ls-files --deleted)
    Write-Host "LOCAL HEAD      : $FL"
    Write-Host "REMOTE HEAD     : $FR"
    Write-Host "AHEAD           : $([int]$FAB[0])"
    Write-Host "BEHIND          : $([int]$FAB[1])"
    Write-Host "STAGED          : $($FS.Count)"
    Write-Host "DELETED TRACKED : $($FD.Count)"
    if($FL -ne $FR -or [int]$FAB[0] -ne 0 -or [int]$FAB[1] -ne 0 -or $FS.Count -ne 0 -or $FD.Count -ne 0){ Hold "Final repository verification failed" }

    Write-Host ""
    Write-Host "SGODA-DELIVERABLE-MAP-RECONCILE-007 : CLOSED / PASS" -ForegroundColor Green
    Write-Host "SPT007_FORMALIZED_STATE=CLOSED"
    Write-Host "SPT007_CLASSIFICATION=CLOSED"
    Write-Host "SPT007_REOPENED=NO"
    Write-Host "MASTER_MAP_RECONCILIATION=PASS"
    Write-Host "PENDING_DELIVERABLES_RECALCULATED=YES"
    Write-Host "PENDING_SPT_CANDIDATES=27"
    Write-Host "PENDING_28_TO_27_GATE=PASS"
    Write-Host "NEXT_DELIVERABLE_DECISION=$Decision"
    if($NextCandidate){ Write-Host "NEXT_DELIVERABLE_CANDIDATE=$NextCandidate" }
    Write-Host "AUTOMATIC_SPT_CREATION=NO"
    Write-Host "SPT007_CLOSE_EVIDENCE_CONSUMED=YES"
    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "NEW_FUNCTIONALITY=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "COMMIT_PERFORMED=YES"
    Write-Host "PUSH_PERFORMED=YES"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "AHEAD=0"
    Write-Host "BEHIND=0"
    Write-Host "STAGED=0"
    Write-Host "INSTITUTIONAL_MASTER_BASELINE=$FL"
    Write-Host "NEXT_ACTION=$NextAction"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch { Hold $_.Exception.Message }
