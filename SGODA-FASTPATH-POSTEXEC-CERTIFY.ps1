#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "5e3fd09e8079bbaec2c38ff495049418008b2a29"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.0"
$Self = "SGODA-FASTPATH-POSTEXEC-CERTIFY.ps1"

$ExecDir = "artifacts/development/SGODA-FASTPATH-EXECUTION-v1.0.0"
$PlanDir = "artifacts/development/SGODA-FASTPATH-ORCHESTRATOR-v1.0.0"

$ExecAssessment = "$ExecDir/fastpath-execution-assessment.json"
$ExecLedger = "$ExecDir/fastpath-execution-ledger.json"
$ExecEvidence = "$ExecDir/implementation-evidence.json"
$ExecManifest = "$ExecDir/fastpath-execution-sha256-manifest.json"
$FinalInventory = "$ExecDir/global-deliverable-inventory-fastpath-final.json"
$FinalStatus = "$ExecDir/global-deliverable-status-matrix-fastpath-final.json"
$FinalNext = "$ExecDir/next-technological-deliverable-assessment-fastpath-final.json"

$PlanJson = "$PlanDir/fastpath-plan.json"
$IndexJson = "$PlanDir/institutional-index.json"
$PlanAssessment = "$PlanDir/fastpath-assessment.json"
$PlanEvidence = "$PlanDir/implementation-evidence.json"
$PlanManifest = "$PlanDir/fastpath-sha256-manifest.json"

$MapDoc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Mapa-Global-Entregables-v1.1.0.md"
$ExecDoc = "docs/00_Estado_Maestro/SGODA-FASTPATH-Execution-v1.0.0.md"
$ExecActa = "docs/00_Estado_Maestro/ACT-SGODA-FASTPATH-EXECUTION-v1.0.0.md"

$OutDir = "artifacts/development/SGODA-FASTPATH-POSTEXEC-CERTIFY-v1.0.0"
$CertAssessment = "$OutDir/fastpath-postexec-certification-assessment.json"
$CertLedger = "$OutDir/fastpath-postexec-certification-ledger.json"
$CertIntegrity = "$OutDir/fastpath-postexec-certification-sha256-manifest.json"
$CertEvidence = "$OutDir/implementation-evidence.json"
$CertDoc = "docs/00_Estado_Maestro/SGODA-FASTPATH-POSTEXEC-CERTIFICATION-v1.0.0.md"
$CertActa = "docs/00_Estado_Maestro/ACT-SGODA-FASTPATH-POSTEXEC-CERTIFICATION-v1.0.0.md"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA-FASTPATH-POSTEXEC-CERTIFY : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "COMMIT_PERFORMED=NO"
    Write-Host "PUSH_PERFORMED=NO"
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

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root){ Hold "Not inside Git repository" }
    Set-Location $Root

    Step 1 "AUTHORITATIVE POST-FASTPATH BASELINE / REMOTE SAFETY"
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

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){ Hold "Authoritative post-FASTPATH baseline mismatch" }
    if([int]$AB[0] -ne 0 -or [int]$AB[1] -ne 0){ Hold "Local/remote divergence" }
    if($Staged.Count -ne 0 -or $Modified.Count -ne 0 -or $Deleted.Count -ne 0){ Hold "Tracked repository is not clean" }

    Write-Host "POST_FASTPATH_BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "RECERTIFY FASTPATH COMMIT IDENTITY"
    $CommitMessage=(& git.exe log -1 --format="%s" HEAD).Trim()
    Write-Host "FASTPATH_COMMIT=$Local"
    Write-Host "FASTPATH_COMMIT_MESSAGE=$CommitMessage"
    if($CommitMessage -ne "chore(institutional): FASTPATH reconcile remaining 27 deliverables"){ Hold "HEAD is not the expected FASTPATH execution commit" }
    Write-Host "FASTPATH_COMMIT_IDENTITY=PASS"

    Step 3 "CONSUME FASTPATH PLAN / INDEX / EXECUTION ARTIFACTS"
    $Required=@(
        $PlanJson,$IndexJson,$PlanAssessment,$PlanEvidence,$PlanManifest,
        $ExecAssessment,$ExecLedger,$ExecEvidence,$ExecManifest,
        $FinalInventory,$FinalStatus,$FinalNext,$MapDoc,$ExecDoc,$ExecActa
    )
    foreach($F in $Required){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){ Hold ("Required FASTPATH artifact missing: "+$F) }
    }

    $Plan=ReadJson $PlanJson
    $Index=ReadJson $IndexJson
    $FinalStatusObj=ReadJson $FinalStatus
    $FinalNextObj=ReadJson $FinalNext

    if([int]$Plan.indexed_candidates -ne 27){ Hold "Plan candidate count is not 27" }
    if([int]$Plan.already_closed -ne 21){ Hold "Plan ALREADY_CLOSED count is not 21" }
    if([int]$Plan.needs_formalization -ne 6){ Hold "Plan formalization count is not 6" }
    if([int]$Plan.incomplete_or_review -ne 0){ Hold "Plan contains incomplete candidates" }

    Write-Host "PLAN_CANDIDATES=27"
    Write-Host "PLAN_ALREADY_CLOSED=21"
    Write-Host "PLAN_NEEDS_FORMALIZATION=6"
    Write-Host "PLAN_INCOMPLETE=0"
    Write-Host "FASTPATH_INPUT_ARTIFACTS=PASS"

    Step 4 "RECERTIFY 27 CANDIDATE EVIDENCE SETS"
    $CandidateRows=@($Index.candidates)
    if($CandidateRows.Count -ne 27){ Hold "Index candidate count mismatch" }

    $CandidateIds=@($CandidateRows | ForEach-Object { [string]$_.deliverable })
    $MissingAssessment=@()
    $MissingEvidence=@()
    $MissingActa=@()

    foreach($Id in $CandidateIds){
        $Slug=$Id.ToLower().Replace("-","").Replace(".","")
        $Assessment="$ExecDir/candidates/$Id/$Slug-assessment.json"
        $Evidence="$ExecDir/candidates/$Id/$Slug-evidence.json"
        $Acta="docs/00_Estado_Maestro/ACT-$Id-FASTPATH-v1.0.0.md"
        if(-not(Test-Path -LiteralPath $Assessment -PathType Leaf)){ $MissingAssessment += $Assessment }
        if(-not(Test-Path -LiteralPath $Evidence -PathType Leaf)){ $MissingEvidence += $Evidence }
        if(-not(Test-Path -LiteralPath $Acta -PathType Leaf)){ $MissingActa += $Acta }
    }

    Write-Host "CANDIDATE_ASSESSMENTS_EXPECTED=27"
    Write-Host "CANDIDATE_ASSESSMENTS_MISSING=$($MissingAssessment.Count)"
    Write-Host "CANDIDATE_EVIDENCE_EXPECTED=27"
    Write-Host "CANDIDATE_EVIDENCE_MISSING=$($MissingEvidence.Count)"
    Write-Host "CANDIDATE_ACTAS_EXPECTED=27"
    Write-Host "CANDIDATE_ACTAS_MISSING=$($MissingActa.Count)"

    if($MissingAssessment.Count -ne 0 -or $MissingEvidence.Count -ne 0 -or $MissingActa.Count -ne 0){ Hold "Per-candidate FASTPATH evidence coverage is incomplete" }
    Write-Host "CANDIDATE_EVIDENCE_COVERAGE=PASS"

    Step 5 "RECERTIFY 21 RECONCILIATIONS / 6 FORMALIZATIONS"
    $AlreadyClosed=@($CandidateRows | Where-Object { [string]$_.real_state -eq "ALREADY_CLOSED" })
    $NeedsFormalization=@($CandidateRows | Where-Object { [string]$_.real_state -eq "IMPLEMENTED_PENDING_FORMALIZATION" })
    $Incomplete=@($CandidateRows | Where-Object { [string]$_.real_state -eq "INCOMPLETE" })

    if($AlreadyClosed.Count -ne 21){ Hold "Expected 21 ALREADY_CLOSED candidates" }
    if($NeedsFormalization.Count -ne 6){ Hold "Expected 6 formalization candidates" }
    if($Incomplete.Count -ne 0){ Hold "Unexpected incomplete candidates" }

    foreach($Row in $CandidateRows){
        $Id=[string]$Row.deliverable
        $Slug=$Id.ToLower().Replace("-","").Replace(".","")
        $Assessment=ReadJson "$ExecDir/candidates/$Id/$Slug-assessment.json"
        if([string]$Assessment.final_state -ne "CLOSED"){ Hold ("Candidate not certified CLOSED: "+$Id) }
        if([bool]$Assessment.reopened){ Hold ("Candidate was reopened: "+$Id) }
        if([bool]$Assessment.historical_tests_recreated){ Hold ("Historical tests were recreated: "+$Id) }
    }

    Write-Host "ALREADY_CLOSED_RECONCILED=21"
    Write-Host "FORMALIZED_AND_RECONCILED=6"
    Write-Host "REOPENED_CANDIDATES=0"
    Write-Host "HISTORICAL_TEST_RECREATION=NO"
    Write-Host "CANDIDATE_STATE_RECERTIFICATION=PASS"

    Step 6 "RECERTIFY GLOBAL MAP 27 -> 0"
    $PendingFinal=@($FinalStatusObj.pending_spt_candidates)
    Write-Host "PENDING_BEFORE=27"
    Write-Host "PENDING_AFTER=$($PendingFinal.Count)"
    if($PendingFinal.Count -ne 0){ Hold "Final FASTPATH map still contains pending SPT candidates" }
    if([string]$FinalNextObj.decision -ne "NO_EXISTING_PENDING_DELIVERABLE"){ Hold "Final next-deliverable decision is not NO_EXISTING_PENDING_DELIVERABLE" }
    if([string]$FinalNextObj.next_action -ne "FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE"){ Hold "Final next action is not FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE" }

    Write-Host "MASTER_MAP_RECONCILIATION=PASS"
    Write-Host "NEXT_DELIVERABLE_DECISION=NO_EXISTING_PENDING_DELIVERABLE"
    Write-Host "NEXT_ACTION=FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE"

    Step 7 "RECERTIFY FASTPATH SHA-256 MANIFESTS"
    $PlanManifestObj=ReadJson $PlanManifest
    $ExecManifestObj=ReadJson $ExecManifest

    $PlanBad=0
    foreach($R in @($PlanManifestObj.records)){
        $Path=[string]$R.path
        $Expected=[string]$R.sha256
        if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ $PlanBad++; continue }
        if((Sha $Path) -ne $Expected.ToUpperInvariant()){ $PlanBad++ }
    }

    $ExecBad=0
    foreach($R in @($ExecManifestObj.records)){
        $Path=[string]$R.path
        $Expected=[string]$R.sha256
        if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ $ExecBad++; continue }
        if((Sha $Path) -ne $Expected.ToUpperInvariant()){ $ExecBad++ }
    }

    Write-Host "PLAN_SHA256_RECORDS=$(@($PlanManifestObj.records).Count)"
    Write-Host "PLAN_SHA256_FAILURES=$PlanBad"
    Write-Host "EXEC_SHA256_RECORDS=$(@($ExecManifestObj.records).Count)"
    Write-Host "EXEC_SHA256_FAILURES=$ExecBad"
    if($PlanBad -ne 0 -or $ExecBad -ne 0){ Hold "FASTPATH SHA-256 recertification failed" }
    Write-Host "FASTPATH_SHA256_RECERTIFICATION=PASS"

    Step 8 "NON-DESTRUCTIVE / SIZE / TRACKED SAFETY RECERTIFICATION"
    $Changed=@(& git.exe diff-tree --no-commit-id --name-status -r HEAD)
    $DeletesInCommit=@($Changed | Where-Object { $_ -match '^D\s' })

    $Large=0
    foreach($F in @(& git.exe -c core.quotepath=false ls-files)){
        $SizeText=(& git.exe cat-file -s (":$F") 2>$null)
        if($LASTEXITCODE -eq 0 -and $SizeText -and [int64]$SizeText -ge 100MB){ $Large++ }
    }

    Write-Host "FASTPATH_COMMIT_DELETIONS=$($DeletesInCommit.Count)"
    Write-Host "INDEX_BLOBS_GE_100MB=$Large"
    if($DeletesInCommit.Count -ne 0){ Hold "FASTPATH commit contains deletions" }
    if($Large -ne 0){ Hold "GitHub size gate failed" }

    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "NON_DESTRUCTIVE_GATE=PASS"

    Step 9 "DETERMINE NEXT REAL TECHNOLOGICAL ACTION"
    $NextRealAction="FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE"
    Write-Host "AUTOMATIC_SPT_CREATION=NO"
    Write-Host "NEXT_REAL_ACTION=$NextRealAction"
    Write-Host "NEXT_REAL_ACTION_GATE=PASS"

    Step 10 "WRITE POSTEXEC CERTIFICATION"
    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

    $AssessObj=[ordered]@{
        component="SGODA-FASTPATH-POSTEXEC-CERTIFY"
        version=$Version
        baseline=$ExpectedBaseline
        status="PASS"
        fastpath_commit=$Local
        candidates_processed=27
        already_closed_reconciled=21
        formalized_and_reconciled=6
        incomplete=0
        pending_before=27
        pending_after=0
        reopened_candidates=0
        historical_tests_recreated=$false
        destructive_cleanup=$false
        github_size_gate="PASS"
        next_action=$NextRealAction
        automatic_spt_creation=$false
        generated_at=$Now
    }

    $LedgerObj=[ordered]@{
        component="SGODA-FASTPATH-POSTEXEC-CERTIFY"
        baseline=$ExpectedBaseline
        candidate_ids=$CandidateIds
        candidate_count=$CandidateIds.Count
        plan_sha256_failures=$PlanBad
        execution_sha256_failures=$ExecBad
        candidate_assessment_missing=$MissingAssessment.Count
        candidate_evidence_missing=$MissingEvidence.Count
        candidate_acta_missing=$MissingActa.Count
        commit_deletions=$DeletesInCommit.Count
        index_blobs_ge_100mb=$Large
        repository_clean=$true
        local_remote_equal=$true
    }

    $EvidenceObj=[ordered]@{
        component="SGODA-FASTPATH-POSTEXEC-CERTIFY"
        baseline=$ExpectedBaseline
        source_plan=$PlanJson
        source_index=$IndexJson
        source_execution_ledger=$ExecLedger
        source_final_status=$FinalStatus
        source_final_next=$FinalNext
        source_map_document=$MapDoc
        result="PASS"
    }

    WriteLf $CertAssessment ($AssessObj | ConvertTo-Json -Depth 16)
    WriteLf $CertLedger ($LedgerObj | ConvertTo-Json -Depth 16)
    WriteLf $CertEvidence ($EvidenceObj | ConvertTo-Json -Depth 12)

    $DocText=@"
# SGODA FASTPATH - Post-Execution Certification v1.0.0

Baseline certificada: $ExpectedBaseline

- FASTPATH commit: $Local
- Candidatos procesados: 27
- Already closed reconciliados: 21
- Formalizados y reconciliados: 6
- Incompletos: 0
- Pendientes: 27 -> 0
- Reaperturas: 0
- Recreacion de pruebas historicas: NO
- Borrados en commit FASTPATH: 0
- Blobs >=100 MB en indice Git: 0
- Local = remoto: YES
- Repositorio tracked limpio: YES
- Siguiente accion: FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE
- Creacion automatica de nuevo SPT: NO
"@
    WriteLf $CertDoc $DocText

    $ActaText=@"
# ACT-SGODA-FASTPATH-POSTEXEC-CERTIFICATION-v1.0.0

Se recertifica la ejecucion FASTPATH institucional en la baseline $ExpectedBaseline.

- 27 candidatos procesados.
- 21 entregables ya cerrados reconciliados sin reapertura.
- 6 entregables formalizados historicamente y reconciliados.
- 0 candidatos incompletos.
- 0 pendientes en el mapa global FASTPATH.
- 0 recreaciones de pruebas historicas.
- 0 operaciones destructivas.
- 0 borrados en el commit FASTPATH.
- Local y remoto sincronizados.
- Siguiente accion: FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE.
"@
    WriteLf $CertActa $ActaText

    $Outputs=@($Self,$CertAssessment,$CertLedger,$CertEvidence,$CertDoc,$CertActa)
    $Records=@()
    foreach($F in $Outputs){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){ Hold ("Certification output missing: "+$F) }
        $Records += [ordered]@{path=$F;sha256=(Sha $F)}
    }

    $ManifestObj=[ordered]@{
        component="SGODA-FASTPATH-POSTEXEC-CERTIFY"
        version=$Version
        baseline=$ExpectedBaseline
        records=$Records
    }
    WriteLf $CertIntegrity ($ManifestObj | ConvertTo-Json -Depth 12)

    Write-Host "POSTEXEC_CERT_ASSESSMENT=CREATED"
    Write-Host "POSTEXEC_CERT_LEDGER=CREATED"
    Write-Host "POSTEXEC_CERT_EVIDENCE=CREATED"
    Write-Host "POSTEXEC_CERT_DOCUMENT=CREATED"
    Write-Host "POSTEXEC_CERT_ACTA=CREATED"
    Write-Host "POSTEXEC_CERT_SHA256_MANIFEST=CREATED"

    Step 11 "FINAL REPOSITORY SAFETY RECERTIFICATION"
    $HeadAfter=(& git.exe rev-parse HEAD).Trim()
    $RemoteAfter=(& git.exe rev-parse "origin/$Branch").Trim()
    $StagedAfter=@(& git.exe diff --cached --name-only)
    $ModifiedAfter=@(& git.exe diff --name-only)
    $DeletedAfter=@(& git.exe ls-files --deleted)

    Write-Host "HEAD_AFTER=$HeadAfter"
    Write-Host "REMOTE_AFTER=$RemoteAfter"
    Write-Host "STAGED_AFTER=$($StagedAfter.Count)"
    Write-Host "MODIFIED_TRACKED_AFTER=$($ModifiedAfter.Count)"
    Write-Host "DELETED_TRACKED_AFTER=$($DeletedAfter.Count)"

    if($HeadAfter -ne $ExpectedBaseline -or $RemoteAfter -ne $ExpectedBaseline){ Hold "Baseline changed during post-execution certification" }
    if($StagedAfter.Count -ne 0 -or $ModifiedAfter.Count -ne 0 -or $DeletedAfter.Count -ne 0){ Hold "Tracked repository changed during post-execution certification" }
    Write-Host "REPOSITORY_SAFETY=PASS"

    Step 12 "FINAL POSTEXEC CERTIFICATION RESULT"
    Write-Host ""
    Write-Host "SGODA-FASTPATH-POSTEXEC-CERTIFY : CLOSED / PASS" -ForegroundColor Green
    Write-Host "FASTPATH_EXECUTION_RECERTIFIED=YES"
    Write-Host "CANDIDATES_PROCESSED=27"
    Write-Host "ALREADY_CLOSED_RECONCILED=21"
    Write-Host "FORMALIZED_AND_RECONCILED=6"
    Write-Host "INCOMPLETE=0"
    Write-Host "PENDING_BEFORE=27"
    Write-Host "PENDING_AFTER=0"
    Write-Host "MASTER_MAP_RECONCILIATION=PASS"
    Write-Host "HISTORICAL_TEST_RECREATION=NO"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "COMMIT_PERFORMED=NO"
    Write-Host "PUSH_PERFORMED=NO"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "INSTITUTIONAL_MASTER_BASELINE=$ExpectedBaseline"
    Write-Host "NEXT_ACTION=FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
