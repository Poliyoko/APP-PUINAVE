#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("SIMULATE","EXECUTE")]
    [string]$Mode = "SIMULATE",

    [int]$MaxCandidates = 27,

    [int]$PushEvery = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "3f99b39cb93af7167442a14481d41020a28f242d"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.0"
$Self = "SGODA-FASTPATH-EXECUTION-ENGINE.ps1"

$PlanDir = "artifacts/development/SGODA-FASTPATH-ORCHESTRATOR-v1.0.0"
$PlanJson = "$PlanDir/fastpath-plan.json"
$IndexJson = "$PlanDir/institutional-index.json"
$PlanAssessment = "$PlanDir/fastpath-assessment.json"
$PlanEvidence = "$PlanDir/implementation-evidence.json"
$PlanManifest = "$PlanDir/fastpath-sha256-manifest.json"
$PlanDoc = "docs/00_Estado_Maestro/SGODA-FASTPATH-Plan-v1.0.0.md"
$PlanScript = "SGODA-FASTPATH-ORCHESTRATOR.ps1"

$RunDir = "artifacts/development/SGODA-FASTPATH-EXECUTION-v1.0.0"
$RunAssessment = "$RunDir/fastpath-execution-assessment.json"
$RunLedger = "$RunDir/fastpath-execution-ledger.json"
$RunEvidence = "$RunDir/implementation-evidence.json"
$RunManifest = "$RunDir/fastpath-execution-sha256-manifest.json"
$RunDoc = "docs/00_Estado_Maestro/SGODA-FASTPATH-Execution-v1.0.0.md"
$RunActa = "docs/00_Estado_Maestro/ACT-SGODA-FASTPATH-EXECUTION-v1.0.0.md"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA-FASTPATH-EXECUTION-ENGINE : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "STOP_ON_FIRST_HOLD=YES"
    exit 1
}

function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/12] {1}" -f $N,$Text) -ForegroundColor Cyan
}

function Fetch {
    for($i=1;$i -le 4;$i++){
        Write-Host "GIT FETCH ATTEMPT : $i/4"
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){
            Write-Host "GIT FETCH : PASS"
            return
        }
        Start-Sleep -Seconds ([Math]::Min(2*$i,8))
    }
    Hold "git fetch failed"
}

function ReadJson {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){
        Hold "Missing JSON: $Path"
    }
    try {
        return ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8) | ConvertFrom-Json)
    }
    catch {
        Hold "Invalid JSON: $Path"
    }
}

function WriteLf {
    param([string]$Path,[string]$Text)
    $Full=Join-Path $Root $Path
    $Parent=Split-Path -Parent $Full
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    [IO.File]::WriteAllText($Full,$Canonical,$Utf8)
}

function Sha {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function SptKey {
    param([string]$Id)
    if($Id -match '^SPT-(\d+)(?:\.(\d+))?'){
        $A=[int]$Matches[1]
        $B=0
        if($Matches[2]){ $B=[int]$Matches[2] }
        return ("{0:D5}.{1:D5}" -f $A,$B)
    }
    return "99999.99999"
}

function EnsureCleanTracked {
    $Staged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Modified=@(& git.exe -c core.quotepath=false diff --name-only)
    $Deleted=@(& git.exe ls-files --deleted)
    if($Staged.Count -ne 0 -or $Modified.Count -ne 0 -or $Deleted.Count -ne 0){
        Hold "Tracked repository is not clean"
    }
}

function VerifyRemoteSync {
    Fetch
    $L=(& git.exe rev-parse HEAD).Trim()
    $R=(& git.exe rev-parse "origin/$Branch").Trim()
    $AB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    if($L -ne $R -or [int]$AB[0] -ne 0 -or [int]$AB[1] -ne 0){
        Hold "Local/remote divergence"
    }
    return $L
}

function WriteCandidateEvidence {
    param(
        [object]$Row,
        [int]$Sequence,
        [int]$PendingBefore,
        [int]$PendingAfter,
        [string]$BaselineBefore
    )

    $Id=[string]$Row.deliverable
    $Safe=$Id.Replace(".","_").Replace("-","_")
    $Dir="$RunDir/candidates/$Id"
    $Assessment="$Dir/$($Id.ToLower().Replace('-','').Replace('.',''))-fastpath-assessment.json"
    $Evidence="$Dir/$($Id.ToLower().Replace('-','').Replace('.',''))-evidence.json"
    $Acta="docs/00_Estado_Maestro/ACT-$Id-FASTPATH-v1.0.0.md"

    $Formalized=([string]$Row.real_state -eq "IMPLEMENTED_PENDING_FORMALIZATION")
    $AlreadyClosed=([string]$Row.real_state -eq "ALREADY_CLOSED")

    if(-not $AlreadyClosed -and -not $Formalized){
        Hold "$Id requires manual review; execution cannot continue"
    }

    $TestEvidence = "AVAILABLE"
    if([int]$Row.test_count -eq 0){ $TestEvidence = "NOT_AVAILABLE" }

    $Obj=[ordered]@{
        component="$Id.FASTPATH"
        sequence=$Sequence
        baseline_before=$BaselineBefore
        previous_state=[string]$Row.real_state
        final_state="CLOSED"
        closure_operation= $(if($Formalized){"HISTORICAL_INSTITUTIONAL_FORMALIZATION"}else{"RECONCILE_EXISTING_CLOSED_STATE"})
        reopened=$false
        historical_tests_available=([int]$Row.test_count -gt 0)
        historical_tests_recreated=$false
        tracked_path_count=[int]$Row.tracked_path_count
        test_count=[int]$Row.test_count
        evidence_count=[int]$Row.evidence_count
        pass_evidence_count=[int]$Row.pass_evidence_count
        release_count=[int]$Row.release_count
        commit_hit_count=[int]$Row.commit_hit_count
        pending_before=$PendingBefore
        pending_after=$PendingAfter
        destructive_cleanup=$false
        new_functionality=$false
        production_change=$false
        result="PASS"
    }

    $Ev=[ordered]@{
        deliverable=$Id
        source_index=$IndexJson
        source_plan=$PlanJson
        real_state=[string]$Row.real_state
        action= $(if($Formalized){"FORMALIZE_CLOSE_THEN_RECONCILE"}else{"RECONCILE"})
        tracked_paths=@($Row.tracked_paths)
        tests=@($Row.test_paths)
        evidence_candidates=@($Row.evidence_candidates)
        pass_evidence_files=@($Row.pass_evidence_files)
        releases=@($Row.releases)
        commit_hits=@($Row.commit_hits)
        test_policy= $(if([int]$Row.test_count -eq 0){"DO_NOT_INVENT_OR_RECREATE_HISTORICAL_TESTS"}else{"REUSE_EXISTING_HISTORICAL_TEST_EVIDENCE_ONLY"})
    }

    WriteLf $Assessment ($Obj | ConvertTo-Json -Depth 20)
    WriteLf $Evidence ($Ev | ConvertTo-Json -Depth 24)

    $Text=@"
# $Id FASTPATH Institutional Acta

- Sequence: $Sequence
- Baseline before: $BaselineBefore
- Previous state: $([string]$Row.real_state)
- Final state: CLOSED
- Reopened: NO
- Historical test evidence: $TestEvidence
- Test recreation: NO
- Evidence candidates: $([int]$Row.evidence_count)
- PASS evidence: $([int]$Row.pass_evidence_count)
- Releases: $([int]$Row.release_count)
- Commit hits: $([int]$Row.commit_hit_count)
- Pending candidates: $PendingBefore -> $PendingAfter
- Destructive cleanup: NO
- New functionality: NO
- Production change: NO
"@
    WriteLf $Acta $Text

    return @($Assessment,$Evidence,$Acta)
}

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root){ Hold "Not inside Git repository" }
    Set-Location $Root

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    $CurrentBaseline=VerifyRemoteSync
    EnsureCleanTracked

    Write-Host "MODE             : $Mode"
    Write-Host "EXPECTED HEAD    : $ExpectedBaseline"
    Write-Host "CURRENT HEAD     : $CurrentBaseline"

    if($CurrentBaseline -ne $ExpectedBaseline){
        Hold "Authoritative execution baseline mismatch"
    }

    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "CONSUME CERTIFIED FASTPATH PLAN"

    $PlanFiles=@(
        $PlanScript,
        $PlanJson,
        $IndexJson,
        $PlanAssessment,
        $PlanEvidence,
        $PlanManifest,
        $PlanDoc
    )

    foreach($F in $PlanFiles){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){
            Hold "Certified plan input missing: $F"
        }
    }

    $Plan=ReadJson $PlanJson
    $Index=ReadJson $IndexJson

    if([string]$Plan.baseline -ne $ExpectedBaseline){
        Hold "Plan baseline mismatch"
    }
    if([int]$Plan.pending_before -ne 27){
        Hold "Plan pending-before is not 27"
    }
    if([int]$Plan.indexed_candidates -ne 27){
        Hold "Certified plan does not cover 27 candidates"
    }
    if([int]$Plan.incomplete_or_review -ne 0){
        Hold "Certified plan contains incomplete/review candidates"
    }

    Write-Host "CERTIFIED_PLAN=PASS"
    Write-Host "PLAN_CANDIDATES=$([int]$Plan.indexed_candidates)"
    Write-Host "PLAN_ALREADY_CLOSED=$([int]$Plan.already_closed)"
    Write-Host "PLAN_NEEDS_FORMALIZATION=$([int]$Plan.needs_formalization)"
    Write-Host "PLAN_INCOMPLETE=$([int]$Plan.incomplete_or_review)"

    Step 3 "BUILD ORDERED EXECUTION QUEUE"

    $Rows=@($Index.candidates | Sort-Object { SptKey ([string]$_.deliverable) })
    if($Rows.Count -ne 27){
        Hold "Institutional index candidate count mismatch"
    }

    $Queue=@($Rows | Select-Object -First $MaxCandidates)
    if($Queue.Count -lt 1){
        Hold "Execution queue is empty"
    }

    $First=[string]$Queue[0].deliverable
    if($First -ne "SPT-008"){
        Hold "First FASTPATH candidate must be SPT-008"
    }

    Write-Host "QUEUE_SIZE=$($Queue.Count)"
    Write-Host "FIRST_CANDIDATE=$First"
    Write-Host "STOP_ON_FIRST_HOLD=YES"
    Write-Host "QUEUE_GATE=PASS"

    Step 4 "SIMULATION / EXECUTION POLICY"

    if($Mode -eq "SIMULATE"){
        $Seq=0
        foreach($Row in $Queue){
            $Seq++
            $Action="RECONCILE"
            if([string]$Row.real_state -eq "IMPLEMENTED_PENDING_FORMALIZATION"){
                $Action="FORMALIZE_CLOSE_THEN_RECONCILE"
            }
            elseif([string]$Row.real_state -ne "ALREADY_CLOSED"){
                $Action="HOLD_FOR_REVIEW"
            }
            Write-Host ("SIMULATE {0}/{1} : {2} : {3} : {4}" -f $Seq,$Queue.Count,$Row.deliverable,$Row.real_state,$Action)
        }

        Write-Host "SIMULATION=PASS"
        Write-Host "COMMIT_PERFORMED=NO"
        Write-Host "PUSH_PERFORMED=NO"
        Write-Host "NEXT_ACTION=RUN_EXECUTE_MODE"
        Write-Host "FINAL_EXIT_CODE=0"
        exit 0
    }

    Write-Host "MODE_EXECUTE=AUTHORIZED"
    Write-Host "EXECUTION_POLICY=ONE_CANDIDATE_ONE_COMMIT"
    Write-Host "PUSH_POLICY=EVERY_$PushEvery"

    Step 5 "PUBLISH FASTPATH ENGINE / PLAN EVIDENCE"

    $BootstrapFiles=@($Self)
    foreach($F in $PlanFiles){
        $Tracked=@(& git.exe ls-files -- $F)
        if($Tracked.Count -eq 0){
            $BootstrapFiles += $F
        }
    }

    foreach($F in $BootstrapFiles){
        & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $F
        if($LASTEXITCODE -ne 0){ Hold "git add failed: $F" }
    }

    $BootstrapStaged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    if($BootstrapStaged.Count -gt 0){
        & git.exe commit -m "chore(institutional): publish FASTPATH execution engine and certified plan"
        if($LASTEXITCODE -ne 0){ Hold "FASTPATH bootstrap commit failed" }

        & git.exe push origin $Branch
        if($LASTEXITCODE -ne 0){ Hold "FASTPATH bootstrap push failed" }

        $CurrentBaseline=VerifyRemoteSync
        Write-Host "FASTPATH_BOOTSTRAP_COMMIT=PASS"
        Write-Host "FASTPATH_BOOTSTRAP_BASELINE=$CurrentBaseline"
    }
    else {
        Write-Host "FASTPATH_BOOTSTRAP_ALREADY_TRACKED=YES"
    }

    Step 6 "EXECUTE CANDIDATES"

    $LedgerRows=@()
    $Pending=27
    $Sequence=0
    $SincePush=0

    foreach($Row in $Queue){
        $Sequence++
        $Id=[string]$Row.deliverable
        $State=[string]$Row.real_state

        Write-Host ""
        Write-Host ("--- FASTPATH {0}/{1} : {2} ---" -f $Sequence,$Queue.Count,$Id) -ForegroundColor Yellow
        Write-Host "REAL_STATE=$State"

        if($State -eq "INCOMPLETE"){
            Hold "$Id classified INCOMPLETE"
        }
        if($State -ne "ALREADY_CLOSED" -and $State -ne "IMPLEMENTED_PENDING_FORMALIZATION"){
            Hold "$Id has unsupported state: $State"
        }

        $Before=$Pending
        $After=$Pending-1
        if($After -lt 0){ Hold "Pending counter underflow" }

        $BaselineBefore=(& git.exe rev-parse HEAD).Trim()
        EnsureCleanTracked

        $CandidateFiles=WriteCandidateEvidence -Row $Row -Sequence $Sequence -PendingBefore $Before -PendingAfter $After -BaselineBefore $BaselineBefore

        foreach($F in $CandidateFiles){
            & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $F
            if($LASTEXITCODE -ne 0){ Hold "git add failed for $Id: $F" }
        }

        $Staged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
        if($Staged.Count -ne $CandidateFiles.Count){
            Hold "$Id exact staging mismatch"
        }

        $Deletes=@(& git.exe diff --cached --diff-filter=D --name-only)
        if($Deletes.Count -ne 0){
            Hold "$Id staged deletion detected"
        }

        $Action="reconcile existing closed state"
        if($State -eq "IMPLEMENTED_PENDING_FORMALIZATION"){
            $Action="formalize historical closure and reconcile"
        }

        & git.exe commit -m ("chore({0}): FASTPATH {1}" -f $Id.ToLower(),$Action)
        if($LASTEXITCODE -ne 0){
            Hold "$Id commit failed"
        }

        $Commit=(& git.exe rev-parse HEAD).Trim()
        $Pending=$After
        $SincePush++

        $LedgerRows += [ordered]@{
            sequence=$Sequence
            deliverable=$Id
            source_state=$State
            action=$Action
            pending_before=$Before
            pending_after=$After
            baseline_before=$BaselineBefore
            commit=$Commit
            pushed=$false
            result="PASS"
        }

        Write-Host "CANDIDATE=$Id"
        Write-Host "ACTION=$Action"
        Write-Host "PENDING=$Before->$After"
        Write-Host "COMMIT=$Commit"
        Write-Host "CANDIDATE_GATE=PASS"

        if($SincePush -ge $PushEvery -or $Sequence -eq $Queue.Count){
            & git.exe push origin $Branch
            if($LASTEXITCODE -ne 0){
                Hold "$Id push failed"
            }
            for($i=$LedgerRows.Count-1;$i -ge 0;$i--){
                if(-not [bool]$LedgerRows[$i].pushed){
                    $LedgerRows[$i].pushed=$true
                }
                else { break }
            }
            $SincePush=0
            $CurrentBaseline=VerifyRemoteSync
            Write-Host "BATCH_PUSH=PASS"
            Write-Host "CURRENT_BASELINE=$CurrentBaseline"
        }
    }

    Step 7 "WRITE MASTER EXECUTION LEDGER"

    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    $FinalBaseline=(& git.exe rev-parse HEAD).Trim()

    $LedgerObj=[ordered]@{
        component="SGODA-FASTPATH-EXECUTION"
        version=$Version
        generated_at=$Now
        input_baseline=$ExpectedBaseline
        final_baseline=$FinalBaseline
        mode=$Mode
        queue_size=$Queue.Count
        pending_before=27
        pending_after=$Pending
        stop_on_first_hold=$true
        rows=$LedgerRows
    }

    $AssessmentObj=[ordered]@{
        component="SGODA-FASTPATH-EXECUTION"
        version=$Version
        status="PASS"
        input_baseline=$ExpectedBaseline
        final_baseline=$FinalBaseline
        candidates_processed=$LedgerRows.Count
        pending_before=27
        pending_after=$Pending
        destructive_cleanup=$false
        historical_tests_recreated=$false
        execution_policy="ONE_CANDIDATE_ONE_COMMIT"
        push_every=$PushEvery
    }

    $EvidenceObj=[ordered]@{
        component="SGODA-FASTPATH-EXECUTION"
        certified_plan=$PlanJson
        certified_index=$IndexJson
        candidates_processed=$LedgerRows.Count
        final_pending=$Pending
        all_processed_commits=@($LedgerRows | ForEach-Object { $_.commit })
    }

    WriteLf $RunLedger ($LedgerObj | ConvertTo-Json -Depth 24)
    WriteLf $RunAssessment ($AssessmentObj | ConvertTo-Json -Depth 16)
    WriteLf $RunEvidence ($EvidenceObj | ConvertTo-Json -Depth 16)

    $Doc=@"
# SGODA FASTPATH Execution v1.0.0

- Input baseline: $ExpectedBaseline
- Final baseline: $FinalBaseline
- Candidates processed: $($LedgerRows.Count)
- Pending candidates: 27 -> $Pending
- Stop on first HOLD: YES
- Historical test recreation: NO
- Destructive cleanup: NO
- Execution policy: ONE_CANDIDATE_ONE_COMMIT
- Push every: $PushEvery
"@
    WriteLf $RunDoc $Doc

    $Acta=@"
# ACT-SGODA-FASTPATH-EXECUTION-v1.0.0

Se certifica la ejecucion FASTPATH institucional.

- Baseline inicial: $ExpectedBaseline
- Baseline final: $FinalBaseline
- Candidatos procesados: $($LedgerRows.Count)
- Pendientes finales: $Pending
- STOP ON FIRST HOLD: YES
- Commit por candidato: YES
- Evidencia por candidato: YES
- Recreacion de pruebas historicas: NO
- Limpieza destructiva: NO
"@
    WriteLf $RunActa $Acta

    Step 8 "BUILD FINAL SHA-256 MANIFEST"

    $FinalOutputs=@(
        $RunLedger,
        $RunAssessment,
        $RunEvidence,
        $RunDoc,
        $RunActa
    )

    $Records=@()
    foreach($F in $FinalOutputs){
        $Records += [ordered]@{path=$F;sha256=(Sha $F)}
    }
    $ManifestObj=[ordered]@{
        component="SGODA-FASTPATH-EXECUTION"
        version=$Version
        input_baseline=$ExpectedBaseline
        final_baseline=$FinalBaseline
        records=$Records
    }
    WriteLf $RunManifest ($ManifestObj | ConvertTo-Json -Depth 12)
    $FinalOutputs += $RunManifest

    foreach($F in $FinalOutputs){
        & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $F
        if($LASTEXITCODE -ne 0){ Hold "Final evidence git add failed: $F" }
    }

    & git.exe commit -m "chore(institutional): close FASTPATH execution ledger"
    if($LASTEXITCODE -ne 0){ Hold "Final FASTPATH ledger commit failed" }

    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){ Hold "Final FASTPATH ledger push failed" }

    Step 9 "AUTHORITATIVE FINAL REMOTE VERIFICATION"

    $VerifiedBaseline=VerifyRemoteSync
    EnsureCleanTracked

    Write-Host "FINAL_BASELINE=$VerifiedBaseline"
    Write-Host "FINAL_PENDING=$Pending"
    Write-Host "CANDIDATES_PROCESSED=$($LedgerRows.Count)"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "FINAL_REMOTE_GATE=PASS"

    Step 10 "PERFORMANCE / TRACEABILITY SUMMARY"

    Write-Host "FULL_REPOSITORY_RESCAN_DURING_EXECUTION=NO"
    Write-Host "CERTIFIED_INDEX_REUSED=YES"
    Write-Host "ONE_CANDIDATE_ONE_COMMIT=YES"
    Write-Host "STOP_ON_FIRST_HOLD=YES"
    Write-Host "HISTORICAL_TEST_RECREATION=NO"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"

    Step 11 "NEXT ACTION"

    if($Pending -eq 0){
        Write-Host "NEXT_ACTION=FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE"
    }
    else {
        Write-Host "NEXT_ACTION=REBUILD_FASTPATH_PLAN_FROM_NEW_BASELINE"
    }

    Step 12 "FINAL RESULT"

    Write-Host ""
    Write-Host "SGODA-FASTPATH-EXECUTION-ENGINE : CLOSED / PASS" -ForegroundColor Green
    Write-Host "MODE=EXECUTE"
    Write-Host "CANDIDATES_PROCESSED=$($LedgerRows.Count)"
    Write-Host "PENDING_BEFORE=27"
    Write-Host "PENDING_AFTER=$Pending"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
