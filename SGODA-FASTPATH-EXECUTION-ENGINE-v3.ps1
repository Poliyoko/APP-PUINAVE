#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("SIMULATE","EXECUTE")]
    [string]$Mode = "SIMULATE"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "3f99b39cb93af7167442a14481d41020a28f242d"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.0"
$Self = "SGODA-FASTPATH-EXECUTION-ENGINE-v3.ps1"

$PlanDir = "artifacts/development/SGODA-FASTPATH-ORCHESTRATOR-v1.0.0"
$PlanJson = "$PlanDir/fastpath-plan.json"
$IndexJson = "$PlanDir/institutional-index.json"
$PlanAssessment = "$PlanDir/fastpath-assessment.json"
$PlanEvidence = "$PlanDir/implementation-evidence.json"
$PlanManifest = "$PlanDir/fastpath-sha256-manifest.json"
$PlanDoc = "docs/00_Estado_Maestro/SGODA-FASTPATH-Plan-v1.0.0.md"
$PlanScript = "SGODA-FASTPATH-ORCHESTRATOR.ps1"

$PrevMapDir = "artifacts/development/SGODA-DELIVERABLE-MAP-RECONCILE-007-v1.0.7"
$PrevInventory = "$PrevMapDir/global-deliverable-inventory-reconciled.json"
$PrevStatus = "$PrevMapDir/global-deliverable-status-matrix-reconciled.json"
$PrevNext = "$PrevMapDir/next-technological-deliverable-assessment-reconciled.json"

$RunDir = "artifacts/development/SGODA-FASTPATH-EXECUTION-v1.0.0"
$FinalInventory = "$RunDir/global-deliverable-inventory-fastpath-final.json"
$FinalStatus = "$RunDir/global-deliverable-status-matrix-fastpath-final.json"
$FinalNext = "$RunDir/next-technological-deliverable-assessment-fastpath-final.json"
$RunLedger = "$RunDir/fastpath-execution-ledger.json"
$RunAssessment = "$RunDir/fastpath-execution-assessment.json"
$RunEvidence = "$RunDir/implementation-evidence.json"
$RunManifest = "$RunDir/fastpath-execution-sha256-manifest.json"
$MapDoc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Mapa-Global-Entregables-v1.1.0.md"
$RunDoc = "docs/00_Estado_Maestro/SGODA-FASTPATH-Execution-v1.0.0.md"
$RunActa = "docs/00_Estado_Maestro/ACT-SGODA-FASTPATH-EXECUTION-v1.0.0.md"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA-FASTPATH-EXECUTION-ENGINE-v3 : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "TRANSACTION : NOT PUBLISHED"
    exit 1
}

function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/12] {1}" -f $N,$Text) -ForegroundColor Cyan
}

function Fetch {
    for($I=1;$I -le 4;$I++){
        Write-Host ("GIT FETCH ATTEMPT : {0}/4" -f $I)
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){
            Write-Host "GIT FETCH : PASS"
            return
        }
        Start-Sleep -Seconds ([Math]::Min(2*$I,8))
    }
    Hold "git fetch failed"
}

function ReadJson {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){
        Hold ("Missing JSON: "+$Path)
    }
    try {
        return ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8) | ConvertFrom-Json)
    }
    catch {
        Hold ("Invalid JSON: "+$Path)
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
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){
        Hold ("Missing file for SHA256: "+$Path)
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function EnsureCleanTracked {
    $S=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $M=@(& git.exe -c core.quotepath=false diff --name-only)
    $D=@(& git.exe ls-files --deleted)
    if($S.Count -ne 0 -or $M.Count -ne 0 -or $D.Count -ne 0){
        Hold "Tracked repository is not clean"
    }
}

function VerifySync {
    Fetch
    $L=(& git.exe rev-parse HEAD).Trim()
    $R=(& git.exe rev-parse "origin/$Branch").Trim()
    $AB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    if($L -ne $R -or [int]$AB[0] -ne 0 -or [int]$AB[1] -ne 0){
        Hold "Local/remote divergence"
    }
    return $L
}

function NewCandidateFiles {
    param(
        [object]$Row,
        [int]$Sequence,
        [int]$PendingBefore,
        [int]$PendingAfter
    )

    $Id=[string]$Row.deliverable
    $Slug=$Id.ToLower().Replace("-","").Replace(".","")
    $Dir="$RunDir/candidates/$Id"
    $Assessment="$Dir/$Slug-assessment.json"
    $Evidence="$Dir/$Slug-evidence.json"
    $Acta="docs/00_Estado_Maestro/ACT-$Id-FASTPATH-v1.0.0.md"

    $Action="RECONCILE_EXISTING_CLOSED_STATE"
    if([string]$Row.real_state -eq "IMPLEMENTED_PENDING_FORMALIZATION"){
        $Action="HISTORICAL_INSTITUTIONAL_FORMALIZATION_AND_RECONCILIATION"
    }

    $TestEvidence="AVAILABLE"
    if([int]$Row.test_count -eq 0){
        $TestEvidence="NOT_AVAILABLE"
    }

    $AssessmentObj=[ordered]@{
        component="$Id.FASTPATH"
        sequence=$Sequence
        input_baseline=$ExpectedBaseline
        source_state=[string]$Row.real_state
        final_state="CLOSED"
        action=$Action
        reopened=$false
        historical_test_evidence=$TestEvidence
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

    $EvidenceObj=[ordered]@{
        deliverable=$Id
        source_plan=$PlanJson
        source_index=$IndexJson
        source_state=[string]$Row.real_state
        action=$Action
        tracked_paths=@($Row.tracked_paths)
        tests=@($Row.test_paths)
        evidence_candidates=@($Row.evidence_candidates)
        pass_evidence_files=@($Row.pass_evidence_files)
        releases=@($Row.releases)
        commit_hits=@($Row.commit_hits)
        test_policy=$(if([int]$Row.test_count -eq 0){"DO_NOT_INVENT_OR_RECREATE_HISTORICAL_TESTS"}else{"REUSE_EXISTING_HISTORICAL_TEST_EVIDENCE_ONLY"})
    }

    WriteLf $Assessment ($AssessmentObj | ConvertTo-Json -Depth 24)
    WriteLf $Evidence ($EvidenceObj | ConvertTo-Json -Depth 24)

    $ActaText=@"
# $Id FASTPATH - Acta Institucional

- Secuencia: $Sequence
- Estado fuente: $([string]$Row.real_state)
- Estado final: CLOSED
- Accion: $Action
- Reapertura: NO
- Evidencia historica de pruebas: $TestEvidence
- Recreacion de pruebas: NO
- Evidencias candidatas: $([int]$Row.evidence_count)
- Evidencias PASS: $([int]$Row.pass_evidence_count)
- Releases: $([int]$Row.release_count)
- Commits: $([int]$Row.commit_hit_count)
- Pendientes: $PendingBefore -> $PendingAfter
- Funcionalidad nueva: NO
- Cambio de produccion: NO
- Limpieza destructiva: NO
"@
    WriteLf $Acta $ActaText

    return @($Assessment,$Evidence,$Acta)
}

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root){ Hold "Not inside Git repository" }
    Set-Location $Root

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    $Current=VerifySync
    EnsureCleanTracked

    Write-Host "MODE             : $Mode"
    Write-Host "EXPECTED HEAD    : $ExpectedBaseline"
    Write-Host "CURRENT HEAD     : $Current"

    if($Current -ne $ExpectedBaseline){
        Hold "Authoritative baseline mismatch"
    }

    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "CONSUME CERTIFIED 27-CANDIDATE FASTPATH PLAN"

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
            Hold ("Certified FASTPATH plan input missing: "+$F)
        }
    }

    $Plan=ReadJson $PlanJson
    $Index=ReadJson $IndexJson

    if([string]$Plan.baseline -ne $ExpectedBaseline){ Hold "Plan baseline mismatch" }
    if([int]$Plan.pending_before -ne 27){ Hold "Plan pending_before is not 27" }
    if([int]$Plan.indexed_candidates -ne 27){ Hold "Plan candidate coverage is not 27/27" }
    if([int]$Plan.already_closed -ne 21){ Hold "Expected 21 ALREADY_CLOSED candidates" }
    if([int]$Plan.needs_formalization -ne 6){ Hold "Expected 6 formalization candidates" }
    if([int]$Plan.incomplete_or_review -ne 0){ Hold "Plan contains incomplete candidates" }

    $Rows=@($Index.candidates)
    if($Rows.Count -ne 27){ Hold "Index candidate count is not 27" }

    Write-Host "CERTIFIED_PLAN=PASS"
    Write-Host "PLAN_CANDIDATES=27"
    Write-Host "PLAN_ALREADY_CLOSED=21"
    Write-Host "PLAN_NEEDS_FORMALIZATION=6"
    Write-Host "PLAN_INCOMPLETE=0"

    Step 3 "CONSUME AUTHORITATIVE GLOBAL MAP"

    foreach($F in @($PrevInventory,$PrevStatus,$PrevNext)){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){
            Hold ("Previous map input missing: "+$F)
        }
    }

    $Inventory=ReadJson $PrevInventory
    $Status=ReadJson $PrevStatus
    $Next=ReadJson $PrevNext

    $PendingIds=@($Status.pending_spt_candidates)
    if($PendingIds.Count -ne 27){ Hold "Previous map does not contain 27 pending candidates" }
    if([string]$Next.next_deliverable_candidate -ne "SPT-008"){ Hold "Previous map next candidate is not SPT-008" }

    $IndexIds=@($Rows | ForEach-Object { [string]$_.deliverable })
    $MissingFromPlan=@($PendingIds | Where-Object { $IndexIds -notcontains $_ })
    $ExtraInPlan=@($IndexIds | Where-Object { $PendingIds -notcontains $_ })

    if($MissingFromPlan.Count -ne 0 -or $ExtraInPlan.Count -ne 0){
        Hold "Certified plan candidate set does not exactly match pending map set"
    }

    Write-Host "MAP_PENDING_BEFORE=27"
    Write-Host "MAP_NEXT_CANDIDATE=SPT-008"
    Write-Host "PLAN_MAP_SET_EQUALITY=PASS"

    Step 4 "PREVALIDATE ALL 27 CANDIDATES BEFORE ANY WRITE"

    $MapRows=@($Inventory.deliverables)
    $AlreadyClosed=0
    $Formalize=0

    foreach($Row in $Rows){
        $Id=[string]$Row.deliverable
        $State=[string]$Row.real_state

        if($State -eq "ALREADY_CLOSED"){
            $AlreadyClosed++
        }
        elseif($State -eq "IMPLEMENTED_PENDING_FORMALIZATION"){
            $Formalize++
        }
        else {
            Hold ("Unsupported state in certified plan for "+$Id+": "+$State)
        }

        $Target=@($MapRows | Where-Object { [string]$_.deliverable -eq $Id })
        if($Target.Count -ne 1){
            Hold ("Expected exactly one global-map row for "+$Id)
        }
        if([string]$Target[0].status -ne "IMPLEMENTED_OR_DOCUMENTED"){
            Hold ("Expected IMPLEMENTED_OR_DOCUMENTED in map for "+$Id)
        }

        if([int]$Row.evidence_count -lt 1){
            Hold ("No evidence candidates for "+$Id)
        }
    }

    if($AlreadyClosed -ne 21 -or $Formalize -ne 6){
        Hold "Candidate-state totals changed after certification"
    }

    Write-Host "ALL_27_PREVALIDATED=PASS"
    Write-Host "ALREADY_CLOSED=21"
    Write-Host "NEEDS_FORMALIZATION=6"
    Write-Host "INCOMPLETE=0"
    Write-Host "WRITE_NOT_STARTED=YES"

    if($Mode -eq "SIMULATE"){
        $Seq=0
        foreach($Row in $Rows){
            $Seq++
            $Action="RECONCILE"
            if([string]$Row.real_state -eq "IMPLEMENTED_PENDING_FORMALIZATION"){
                $Action="FORMALIZE_CLOSE_THEN_RECONCILE"
            }
            Write-Host ("SIMULATE {0}/27 : {1} : {2} : {3}" -f $Seq,$Row.deliverable,$Row.real_state,$Action)
        }
        Write-Host ""
        Write-Host "SGODA-FASTPATH-EXECUTION-ENGINE-v3 : SIMULATION PASS" -ForegroundColor Green
        Write-Host "MAP_RECONCILIATION_IMPLEMENTED=YES"
        Write-Host "BATCH_TRANSACTION=YES"
        Write-Host "EXPECTED_PENDING_AFTER=0"
        Write-Host "COMMIT_PERFORMED=NO"
        Write-Host "PUSH_PERFORMED=NO"
        Write-Host "FINAL_EXIT_CODE=0"
        exit 0
    }

    Step 5 "GENERATE PER-CANDIDATE FORMALIZATION / RECONCILIATION EVIDENCE"

    $Generated=@()
    $LedgerRows=@()
    $Pending=27
    $Seq=0

    foreach($Row in $Rows){
        $Seq++
        $Before=$Pending
        $After=$Pending-1
        $Files=NewCandidateFiles -Row $Row -Sequence $Seq -PendingBefore $Before -PendingAfter $After
        $Generated += $Files

        $LedgerRows += [ordered]@{
            sequence=$Seq
            deliverable=[string]$Row.deliverable
            source_state=[string]$Row.real_state
            final_state="CLOSED"
            pending_before=$Before
            pending_after=$After
            result="PASS"
        }

        $Pending=$After
    }

    if($Pending -ne 0){ Hold "Pending counter did not reach zero" }

    Write-Host "CANDIDATE_EVIDENCE_SETS=27"
    Write-Host "FORMALIZATION_CASES=6"
    Write-Host "RECONCILIATION_ONLY_CASES=21"
    Write-Host "PENDING_COUNTER=27->0"
    Write-Host "CANDIDATE_EVIDENCE_GATE=PASS"

    Step 6 "REBUILD GLOBAL DELIVERABLE MAP IN ONE TRANSACTION"

    $NewRows=@()

    foreach($R in $MapRows){
        $Id=[string]$R.deliverable
        if($PendingIds -contains $Id){
            $NewRows += [ordered]@{
                deliverable=$Id
                status="CLOSED"
                reason="FASTPATH institutional reconciliation from certified historical evidence."
                tracked_paths=@($R.tracked_paths)
                path_count=[int]$R.path_count
                reconciliation_source=$RunLedger
                reopened=$false
            }
        }
        else {
            $Obj=[ordered]@{
                deliverable=$Id
                status=[string]$R.status
                reason=[string]$R.reason
                tracked_paths=@($R.tracked_paths)
                path_count=[int]$R.path_count
            }
            if($R.PSObject.Properties.Name -contains "reconciliation_source"){
                $Obj["reconciliation_source"]=[string]$R.reconciliation_source
            }
            if($R.PSObject.Properties.Name -contains "reopened"){
                $Obj["reopened"]=[bool]$R.reopened
            }
            $NewRows += $Obj
        }
    }

    $Closed=@($NewRows | Where-Object { [string]$_.status -match '^CLOSED' })
    $Impl=@($NewRows | Where-Object { [string]$_.status -eq "IMPLEMENTED_OR_DOCUMENTED" })
    $PendingAfter=@($NewRows | Where-Object {
        [string]$_.deliverable -match '^SPT-\d+' -and [string]$_.status -eq "IMPLEMENTED_OR_DOCUMENTED"
    })

    if($PendingAfter.Count -ne 0){
        Hold ("Global map still contains pending SPT candidates: "+$PendingAfter.Count)
    }

    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

    $InvObj=[ordered]@{
        component="SGODA-FASTPATH-GLOBAL-DELIVERABLE-MAP"
        version="1.1.0"
        authoritative_input_head=$ExpectedBaseline
        generated_at=$Now
        deliverable_count=$NewRows.Count
        fastpath_processed=27
        deliverables=$NewRows
    }

    $StatusObj=[ordered]@{
        component="SGODA-FASTPATH-GLOBAL-DELIVERABLE-MAP"
        version="1.1.0"
        authoritative_input_head=$ExpectedBaseline
        closed_or_formalized=@($Closed | ForEach-Object { $_.deliverable })
        implemented_or_documented=@($Impl | ForEach-Object { $_.deliverable })
        pending_spt_candidates=@()
        fastpath_pending_before=27
        fastpath_pending_after=0
    }

    $NextObj=[ordered]@{
        component="SGODA-FASTPATH-GLOBAL-DELIVERABLE-MAP"
        version="1.1.0"
        decision="NO_EXISTING_PENDING_DELIVERABLE"
        next_deliverable_candidate=$null
        next_action="FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE"
        pending_spt_candidates=@()
        automatic_spt_creation=$false
    }

    $LedgerObj=[ordered]@{
        component="SGODA-FASTPATH-EXECUTION"
        version=$Version
        input_baseline=$ExpectedBaseline
        pending_before=27
        pending_after=0
        candidates_processed=27
        already_closed=21
        formalized=6
        rows=$LedgerRows
    }

    $AssessObj=[ordered]@{
        component="SGODA-FASTPATH-EXECUTION"
        version=$Version
        status="PASS"
        input_baseline=$ExpectedBaseline
        candidates_processed=27
        pending_before=27
        pending_after=0
        map_reconciliation="PASS"
        historical_tests_recreated=$false
        destructive_cleanup=$false
        new_functionality=$false
        production_change=$false
    }

    $EvidenceObj=[ordered]@{
        component="SGODA-FASTPATH-EXECUTION"
        certified_plan=$PlanJson
        certified_index=$IndexJson
        previous_map=$PrevInventory
        candidates_processed=27
        already_closed=21
        needs_formalization=6
        incomplete=0
        final_pending=0
    }

    WriteLf $FinalInventory ($InvObj | ConvertTo-Json -Depth 30)
    WriteLf $FinalStatus ($StatusObj | ConvertTo-Json -Depth 20)
    WriteLf $FinalNext ($NextObj | ConvertTo-Json -Depth 12)
    WriteLf $RunLedger ($LedgerObj | ConvertTo-Json -Depth 20)
    WriteLf $RunAssessment ($AssessObj | ConvertTo-Json -Depth 16)
    WriteLf $RunEvidence ($EvidenceObj | ConvertTo-Json -Depth 16)

    $MapText=@"
# SGODA-PUINAVE - Mapa Global de Entregables v1.1.0

Baseline de entrada: $ExpectedBaseline

## FASTPATH

- Candidatos procesados: 27
- Already closed reconciliados: 21
- Formalizaciones historicas: 6
- Incompletos: 0
- Pendientes antes: 27
- Pendientes despues: 0
- Reaperturas: 0
- Recreacion de pruebas historicas: NO
- Limpieza destructiva: NO
- Siguiente accion: FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE
"@
    WriteLf $MapDoc $MapText

    $RunText=@"
# SGODA FASTPATH Execution v1.0.0

- Baseline de entrada: $ExpectedBaseline
- Candidatos procesados: 27
- Reconciliaciones de ya cerrados: 21
- Formalizaciones historicas: 6
- Pendientes finales: 0
- Escaneo integral reutilizado: YES
- Unica transaccion de publicacion: YES
- Recreacion de pruebas historicas: NO
- Limpieza destructiva: NO
"@
    WriteLf $RunDoc $RunText

    $ActaText=@"
# ACT-SGODA-FASTPATH-EXECUTION-v1.0.0

Se certifica la ejecucion institucional FASTPATH sobre los 27 candidatos pendientes.

- Estado inicial: 27 pendientes.
- Estado final: 0 pendientes.
- Already closed reconciliados: 21.
- Formalizaciones historicas: 6.
- Incompletos: 0.
- Reaperturas: 0.
- Recreacion de pruebas historicas: NO.
- Funcionalidad nueva: NO.
- Cambio de produccion: NO.
- Limpieza destructiva: NO.
- Siguiente accion: FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE.
"@
    WriteLf $RunActa $ActaText

    $Generated += @(
        $FinalInventory,$FinalStatus,$FinalNext,
        $RunLedger,$RunAssessment,$RunEvidence,
        $MapDoc,$RunDoc,$RunActa
    )

    Write-Host "GLOBAL_MAP_REBUILT=PASS"
    Write-Host "PENDING_SPT_CANDIDATES=0"
    Write-Host "NEXT_DELIVERABLE_DECISION=NO_EXISTING_PENDING_DELIVERABLE"
    Write-Host "NEXT_ACTION=FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE"

    Step 7 "BUILD SHA-256 MANIFEST / PUBLICATION SET"

    $Publication=@($Self)
    foreach($F in $PlanFiles){
        $Tracked=@(& git.exe ls-files -- $F)
        if($Tracked.Count -eq 0){ $Publication += $F }
    }

    foreach($CandidateEngine in @(
        "SGODA-FASTPATH-EXECUTION-ENGINE.ps1",
        "SGODA-FASTPATH-EXECUTION-ENGINE-v2.ps1"
    )){
        if(Test-Path -LiteralPath $CandidateEngine -PathType Leaf){
            $Tracked=@(& git.exe ls-files -- $CandidateEngine)
            if($Tracked.Count -eq 0){ $Publication += $CandidateEngine }
        }
    }

    $Publication += $Generated
    $Publication=@($Publication | Select-Object -Unique)

    $Records=@()
    foreach($F in $Publication){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){
            Hold ("Publication file missing: "+$F)
        }
        $Records += [ordered]@{path=$F;sha256=(Sha $F)}
    }

    $ManifestObj=[ordered]@{
        component="SGODA-FASTPATH-EXECUTION"
        version=$Version
        input_baseline=$ExpectedBaseline
        records=$Records
    }

    WriteLf $RunManifest ($ManifestObj | ConvertTo-Json -Depth 12)
    $Publication += $RunManifest

    Write-Host "PUBLICATION_SET=$($Publication.Count)"
    Write-Host "SHA256_MANIFEST=CREATED"

    Step 8 "EXACT CONTROLLED STAGING / SAFETY GATES"

    EnsureCleanTracked

    foreach($F in $Publication){
        & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $F
        if($LASTEXITCODE -ne 0){
            Hold ("git add failed: "+$F)
        }
    }

    $Staged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected=@($Staged | Where-Object { $Publication -notcontains ($_ -replace "\\","/") })
    $Missing=@($Publication | Where-Object { $Staged -notcontains $_ })
    $Deletes=@(& git.exe diff --cached --diff-filter=D --name-only)

    Write-Host "STAGED=$($Staged.Count)"
    Write-Host "EXPECTED_STAGE_SET=$($Publication.Count)"
    Write-Host "UNEXPECTED_STAGED=$($Unexpected.Count)"
    Write-Host "MISSING_STAGED=$($Missing.Count)"
    Write-Host "STAGED_DELETIONS=$($Deletes.Count)"

    if($Unexpected.Count -ne 0 -or $Missing.Count -ne 0 -or $Staged.Count -ne $Publication.Count){
        Hold "Exact staging mismatch"
    }
    if($Deletes.Count -ne 0){ Hold "Staged deletion detected" }

    $Large=0
    foreach($F in @(& git.exe -c core.quotepath=false ls-files)){
        $SizeText=(& git.exe cat-file -s (":$F") 2>$null)
        if($LASTEXITCODE -eq 0 -and $SizeText -and [int64]$SizeText -ge 100MB){
            $Large++
        }
    }
    Write-Host "INDEX_BLOBS_GE_100MB=$Large"
    if($Large -ne 0){ Hold "GitHub size gate failed" }

    Write-Host "STAGING_QUALITY=PASS"
    Write-Host "GITHUB_SIZE_GATE=PASS"

    Step 9 "REMOTE PRE-COMMIT GATE / SINGLE COMMIT"

    Fetch
    $PreL=(& git.exe rev-parse HEAD).Trim()
    $PreR=(& git.exe rev-parse "origin/$Branch").Trim()
    if($PreL -ne $ExpectedBaseline -or $PreR -ne $ExpectedBaseline){
        Hold "Remote changed before FASTPATH commit"
    }

    Write-Host "REMOTE_PRECOMMIT_GATE=PASS"

    & git.exe commit -m "chore(institutional): FASTPATH reconcile remaining 27 deliverables"
    if($LASTEXITCODE -ne 0){ Hold "FASTPATH commit failed" }

    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"
    Write-Host "COMMIT_PERFORMED=YES"

    Step 10 "PUSH"

    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){ Hold "FASTPATH push failed" }
    Write-Host "PUSH=PASS"

    Step 11 "AUTHORITATIVE FINAL REMOTE VERIFICATION"

    $Final=VerifySync
    EnsureCleanTracked

    Write-Host "LOCAL HEAD      : $Final"
    Write-Host "REMOTE HEAD     : $Final"
    Write-Host "AHEAD           : 0"
    Write-Host "BEHIND          : 0"
    Write-Host "STAGED          : 0"
    Write-Host "FINAL_REMOTE_GATE=PASS"

    Step 12 "FINAL RESULT"

    Write-Host ""
    Write-Host "SGODA-FASTPATH-EXECUTION-ENGINE-v3 : CLOSED / PASS" -ForegroundColor Green
    Write-Host "CANDIDATES_PROCESSED=27"
    Write-Host "ALREADY_CLOSED_RECONCILED=21"
    Write-Host "FORMALIZED_AND_RECONCILED=6"
    Write-Host "INCOMPLETE=0"
    Write-Host "PENDING_BEFORE=27"
    Write-Host "PENDING_AFTER=0"
    Write-Host "MASTER_MAP_RECONCILIATION=PASS"
    Write-Host "HISTORICAL_TEST_RECREATION=NO"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "COMMIT_PERFORMED=YES"
    Write-Host "PUSH_PERFORMED=YES"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "INSTITUTIONAL_MASTER_BASELINE=$Final"
    Write-Host "NEXT_ACTION=FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
