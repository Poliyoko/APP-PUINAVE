#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("PLAN","EXECUTE")]
    [string]$Mode = "PLAN",

    [int]$MaxCandidates = 26
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "3f99b39cb93af7167442a14481d41020a28f242d"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.0"
$Self = "SGODA-FASTPATH-ORCHESTRATOR.ps1"

$PreviousMapDir = "artifacts/development/SGODA-DELIVERABLE-MAP-RECONCILE-007-v1.0.7"
$PreviousInventory = "$PreviousMapDir/global-deliverable-inventory-reconciled.json"
$PreviousStatus = "$PreviousMapDir/global-deliverable-status-matrix-reconciled.json"
$PreviousNext = "$PreviousMapDir/next-technological-deliverable-assessment-reconciled.json"

$OutDir = "artifacts/development/SGODA-FASTPATH-ORCHESTRATOR-v1.0.0"
$PlanJson = "$OutDir/fastpath-plan.json"
$IndexJson = "$OutDir/institutional-index.json"
$AssessmentJson = "$OutDir/fastpath-assessment.json"
$EvidenceJson = "$OutDir/implementation-evidence.json"
$ManifestJson = "$OutDir/fastpath-sha256-manifest.json"
$PlanDoc = "docs/00_Estado_Maestro/SGODA-FASTPATH-Plan-v1.0.0.md"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA-FASTPATH-ORCHESTRATOR : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "COMMIT_PERFORMED=NO"
    Write-Host "PUSH_PERFORMED=NO"
    exit 1
}

function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/10] {1}" -f $N,$Text) -ForegroundColor Cyan
}

function Git-Fetch {
    for($Attempt=1;$Attempt -le 4;$Attempt++){
        Write-Host ("GIT FETCH ATTEMPT : {0}/4" -f $Attempt)
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){
            Write-Host "GIT FETCH : PASS"
            return
        }
        Start-Sleep -Seconds ([Math]::Min(2*$Attempt,8))
    }
    Hold "git fetch failed after 4 attempts"
}

function Read-Json {
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

function Write-Utf8NoBomLf {
    param([string]$Path,[string]$Text)
    $Full = Join-Path $Root $Path
    $Parent = Split-Path -Parent $Full
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Canonical = (($Text -replace "`r`n","`n") -replace "`r","`n")
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Full,$Canonical,$Utf8)
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Spt-Key {
    param([string]$Id)
    if($Id -match '^SPT-(\d+)(?:\.(\d+))?'){
        $A=[int]$Matches[1]
        $B=0
        if($Matches[2]){ $B=[int]$Matches[2] }
        return ("{0:D5}.{1:D5}" -f $A,$B)
    }
    return "99999.99999"
}

function Get-Text {
    param([string]$Path)
    try {
        return [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8)
    }
    catch {
        return ""
    }
}

function Has-Marker {
    param([string]$Path,[string[]]$Markers)
    $Text=Get-Text $Path
    foreach($M in $Markers){
        if($Text -match $M){ return $true }
    }
    return $false
}

try {
    $Root = (& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root){ Hold "Not inside Git repository" }
    Set-Location $Root

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    Git-Fetch

    $Local=(& git.exe rev-parse HEAD).Trim()
    $Remote=(& git.exe rev-parse "origin/$Branch").Trim()
    $AB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    $Staged=@(& git.exe diff --cached --name-only)
    $Modified=@(& git.exe diff --name-only)
    $Deleted=@(& git.exe ls-files --deleted)

    Write-Host "MODE             : $Mode"
    Write-Host "EXPECTED HEAD    : $ExpectedBaseline"
    Write-Host "LOCAL HEAD       : $Local"
    Write-Host "REMOTE HEAD      : $Remote"
    Write-Host "AHEAD            : $([int]$AB[0])"
    Write-Host "BEHIND           : $([int]$AB[1])"
    Write-Host "STAGED           : $($Staged.Count)"
    Write-Host "MODIFIED TRACKED : $($Modified.Count)"
    Write-Host "DELETED TRACKED  : $($Deleted.Count)"

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){
        Hold "Authoritative baseline mismatch"
    }
    if([int]$AB[0] -ne 0 -or [int]$AB[1] -ne 0){
        Hold "Local/remote divergence"
    }
    if($Staged.Count -ne 0 -or $Modified.Count -ne 0 -or $Deleted.Count -ne 0){
        Hold "Tracked baseline is not clean"
    }

    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "CONSUME CURRENT GLOBAL DELIVERABLE MAP"

    foreach($P in @($PreviousInventory,$PreviousStatus,$PreviousNext)){
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){
            Hold ("Map input missing: "+$P)
        }
    }

    $Inventory=Read-Json $PreviousInventory
    $Status=Read-Json $PreviousStatus
    $Next=Read-Json $PreviousNext

    $Pending=@($Status.pending_spt_candidates)
    if($Pending.Count -ne 27){
        Hold ("Expected 27 pending candidates before SPT-008 reconciliation, found "+$Pending.Count)
    }
    if([string]$Next.next_deliverable_candidate -ne "SPT-008"){
        Hold "Current map next candidate is not SPT-008"
    }

    Write-Host "MAP_PENDING_SPT_CANDIDATES=$($Pending.Count)"
    Write-Host "MAP_NEXT_CANDIDATE=SPT-008"
    Write-Host "MAP_CONSUMED=PASS"

    Step 3 "SINGLE REPOSITORY-WIDE INDEX BUILD"

    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Tags=@(& git.exe tag --list)
    $AllCommits=@(& git.exe --no-pager log --all --format="%H|%ad|%s" --date=iso -500)

    $ClosureMarkers=@(
        '(?i)\bCLOSED\b',
        '(?i)INSTITUTIONALLY[_ ]CLOSED',
        '(?i)\bCIERRE\b',
        '(?i)\bCERRADO\b',
        '(?i)FINAL_EXIT_CODE\s*=\s*0',
        '(?i)CLOSURE[_ ]GATE\s*=\s*PASS',
        '(?i)\bOFFICIALLY[_ ]PUBLISHED\b'
    )

    $ImplementationMarkers=@(
        '(?i)\bPASS\b',
        '(?i)\bIMPLEMENTED\b',
        '(?i)\bFINAL\b',
        '(?i)\bAPPROVED\b',
        '(?i)COMPILEALL\s*=\s*PASS'
    )

    $IndexRows=@()

    foreach($Candidate in ($Pending | Sort-Object { Spt-Key $_ })){
        if($IndexRows.Count -ge $MaxCandidates){ break }

        $Num=""
        if($Candidate -match '^SPT-(\d+)'){
            $Num=$Matches[1].PadLeft(3,'0')
        }

        $Patterns=@(
            "(?i)(^|/)SPT-$Num([^0-9]|$)",
            "(?i)(^|/)SPT$Num([^0-9]|$)",
            "(?i)\bSPT[-_.]?$Num\b"
        )

        $Paths=New-Object System.Collections.ArrayList
        foreach($P in $Tracked){
            foreach($Rx in $Patterns){
                if($P -match $Rx){
                    if(-not $Paths.Contains($P)){ [void]$Paths.Add($P) }
                    break
                }
            }
        }

        $Tests=@($Paths | Where-Object { $_ -match '(?i)(^|/)tests?/|test_|_test\.' })
        $Docs=@($Paths | Where-Object { $_ -match '(?i)(^|/)docs?/' })
        $Artifacts=@($Paths | Where-Object { $_ -match '(?i)^artifacts/' })
        $Scripts=@($Paths | Where-Object { $_ -match '(?i)\.ps1$' })
        $Source=@($Paths | Where-Object { $_ -match '(?i)^src/' })
        $Releases=@($Paths | Where-Object { $_ -match '(?i)^releases/' })
        $Actas=@($Paths | Where-Object { $_ -match '(?i)(^|/)ACT-' })

        $ClosureFiles=New-Object System.Collections.ArrayList
        $ImplementationFiles=New-Object System.Collections.ArrayList
        $EvidenceCandidates=New-Object System.Collections.ArrayList
        $PassEvidence=New-Object System.Collections.ArrayList

        foreach($P in $Paths){
            if(Has-Marker $P $ClosureMarkers){ [void]$ClosureFiles.Add($P) }
            if(Has-Marker $P $ImplementationMarkers){ [void]$ImplementationFiles.Add($P) }

            if($P -match '(?i)^artifacts/|^releases/|evidence|assessment|manifest|ledger|acta|audit|certif|result'){
                if(-not $EvidenceCandidates.Contains($P)){ [void]$EvidenceCandidates.Add($P) }
            }
        }

        foreach($P in $EvidenceCandidates){
            if(Has-Marker $P @(
                '(?i)\bPASS\b',
                '(?i)\bCLOSED\b',
                '(?i)FINAL_EXIT_CODE\s*=\s*0',
                '(?i)\bAPPROVED\b'
            )){
                [void]$PassEvidence.Add($P)
            }
        }

        $CommitHits=@($AllCommits | Where-Object {
            $_ -match ("(?i)SPT[-_.]?"+$Num+"\b")
        })

        $TagHits=@($Tags | Where-Object {
            $_ -match ("(?i)SPT[-_.]?"+$Num+"\b")
        })

        $RealState="INCOMPLETE"
        $RecommendedAction="IDENTIFY_AND_COMPLETE_MISSING_ELEMENTS"

        $HasClosure=($ClosureFiles.Count -gt 0 -or $Actas.Count -gt 0)
        $HasImplementation=($ImplementationFiles.Count -gt 0 -or $Source.Count -gt 0 -or $Scripts.Count -gt 0)
        $HasEvidence=($EvidenceCandidates.Count -gt 0 -or $PassEvidence.Count -gt 0)
        $HasHistory=($CommitHits.Count -gt 0)

        if($HasClosure -and $HasEvidence -and ($HasHistory -or $Releases.Count -gt 0)){
            $RealState="ALREADY_CLOSED"
            $RecommendedAction="RECONCILE_MASTER_MAP_WITHOUT_REOPENING"
        }
        elseif($HasImplementation -and ($HasEvidence -or $HasHistory -or $Releases.Count -gt 0)){
            $RealState="IMPLEMENTED_PENDING_FORMALIZATION"
            $RecommendedAction="BUILD_FORMALIZATION_CLOSURE_PACKAGE"
        }

        $IndexRows += [ordered]@{
            deliverable=$Candidate
            tracked_paths=@($Paths)
            tracked_path_count=$Paths.Count
            test_paths=@($Tests)
            test_count=$Tests.Count
            docs=@($Docs)
            doc_count=$Docs.Count
            artifacts=@($Artifacts)
            artifact_count=$Artifacts.Count
            scripts=@($Scripts)
            script_count=$Scripts.Count
            source=@($Source)
            source_count=$Source.Count
            releases=@($Releases)
            release_count=$Releases.Count
            actas=@($Actas)
            acta_count=$Actas.Count
            closure_marker_files=@($ClosureFiles)
            closure_marker_count=$ClosureFiles.Count
            implementation_marker_files=@($ImplementationFiles)
            implementation_marker_count=$ImplementationFiles.Count
            evidence_candidates=@($EvidenceCandidates)
            evidence_count=$EvidenceCandidates.Count
            pass_evidence_files=@($PassEvidence)
            pass_evidence_count=$PassEvidence.Count
            commit_hits=@($CommitHits)
            commit_hit_count=$CommitHits.Count
            tag_hits=@($TagHits)
            tag_hit_count=$TagHits.Count
            real_state=$RealState
            recommended_action=$RecommendedAction
        }
    }

    Write-Host "TRACKED_FILES_SCANNED=$($Tracked.Count)"
    Write-Host "PENDING_CANDIDATES_INDEXED=$($IndexRows.Count)"
    Write-Host "REPOSITORY_INDEX_BUILD=PASS"

    Step 4 "DERIVE FASTPATH PLAN"

    $PlanRows=@()
    $AlreadyClosed=0
    $NeedsFormalization=0
    $Incomplete=0

    foreach($Row in $IndexRows){
        $Action=""
        switch([string]$Row.real_state){
            "ALREADY_CLOSED" {
                $Action="RECONCILE"
                $AlreadyClosed++
            }
            "IMPLEMENTED_PENDING_FORMALIZATION" {
                $Action="FORMALIZE_CLOSE_THEN_RECONCILE"
                $NeedsFormalization++
            }
            default {
                $Action="HOLD_FOR_REVIEW"
                $Incomplete++
            }
        }

        $PlanRows += [ordered]@{
            deliverable=$Row.deliverable
            real_state=$Row.real_state
            fastpath_action=$Action
            test_count=$Row.test_count
            evidence_count=$Row.evidence_count
            pass_evidence_count=$Row.pass_evidence_count
            release_count=$Row.release_count
            commit_hit_count=$Row.commit_hit_count
        }
    }

    Write-Host "ALREADY_CLOSED=$AlreadyClosed"
    Write-Host "NEEDS_FORMALIZATION=$NeedsFormalization"
    Write-Host "INCOMPLETE_OR_REVIEW=$Incomplete"
    Write-Host "FASTPATH_PLAN=PASS"

    Step 5 "WRITE INSTITUTIONAL INDEX / PLAN"

    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

    $IndexObj=[ordered]@{
        component="SGODA-FASTPATH-INSTITUTIONAL-INDEX"
        version=$Version
        baseline=$ExpectedBaseline
        generated_at=$Now
        tracked_files_scanned=$Tracked.Count
        pending_candidates_indexed=$IndexRows.Count
        candidates=$IndexRows
    }

    $PlanObj=[ordered]@{
        component="SGODA-FASTPATH-ORCHESTRATOR"
        version=$Version
        baseline=$ExpectedBaseline
        mode=$Mode
        pending_before=27
        current_candidate="SPT-008"
        indexed_candidates=$IndexRows.Count
        already_closed=$AlreadyClosed
        needs_formalization=$NeedsFormalization
        incomplete_or_review=$Incomplete
        plan=$PlanRows
        execute_policy="STOP_ON_FIRST_HOLD"
    }

    $AssessmentObj=[ordered]@{
        component="SGODA-FASTPATH-ORCHESTRATOR"
        version=$Version
        baseline=$ExpectedBaseline
        plan_status="READY"
        mode=$Mode
        repository_scanned_once=$true
        redundant_full_scans_avoided=$true
        commit_performed=$false
        push_performed=$false
        destructive_cleanup=$false
    }

    $EvidenceObj=[ordered]@{
        component="SGODA-FASTPATH-ORCHESTRATOR"
        version=$Version
        baseline=$ExpectedBaseline
        source_map=$PreviousStatus
        tracked_files_scanned=$Tracked.Count
        candidate_count=$IndexRows.Count
        classification_summary=[ordered]@{
            already_closed=$AlreadyClosed
            needs_formalization=$NeedsFormalization
            incomplete_or_review=$Incomplete
        }
    }

    Write-Utf8NoBomLf $IndexJson ($IndexObj | ConvertTo-Json -Depth 30)
    Write-Utf8NoBomLf $PlanJson ($PlanObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $AssessmentJson ($AssessmentObj | ConvertTo-Json -Depth 12)
    Write-Utf8NoBomLf $EvidenceJson ($EvidenceObj | ConvertTo-Json -Depth 12)

    $Lines=New-Object System.Collections.ArrayList
    [void]$Lines.Add("# SGODA FASTPATH - Plan Institucional v1.0.0")
    [void]$Lines.Add("")
    [void]$Lines.Add("Baseline: $ExpectedBaseline")
    [void]$Lines.Add("")
    [void]$Lines.Add("Pendientes de entrada: 27")
    [void]$Lines.Add("Candidatos indexados: $($IndexRows.Count)")
    [void]$Lines.Add("Already closed: $AlreadyClosed")
    [void]$Lines.Add("Needs formalization: $NeedsFormalization")
    [void]$Lines.Add("Incomplete/review: $Incomplete")
    [void]$Lines.Add("")
    [void]$Lines.Add("## Plan")
    [void]$Lines.Add("")

    foreach($Row in $PlanRows){
        [void]$Lines.Add(("- {0}: {1} -> {2}" -f $Row.deliverable,$Row.real_state,$Row.fastpath_action))
    }

    Write-Utf8NoBomLf $PlanDoc ($Lines -join "`n")

    Write-Host "INSTITUTIONAL_INDEX=CREATED"
    Write-Host "FASTPATH_PLAN_JSON=CREATED"
    Write-Host "FASTPATH_ASSESSMENT=CREATED"
    Write-Host "IMPLEMENTATION_EVIDENCE=CREATED"
    Write-Host "FASTPATH_PLAN_DOCUMENT=CREATED"

    Step 6 "BUILD SHA-256 MANIFEST"

    $Outputs=@(
        $Self,
        $IndexJson,
        $PlanJson,
        $AssessmentJson,
        $EvidenceJson,
        $PlanDoc
    )

    $Records=@()
    foreach($P in $Outputs){
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){
            Hold ("Output missing: "+$P)
        }
        $Records += [ordered]@{
            path=$P
            sha256=Get-Sha256 $P
        }
    }

    $ManifestObj=[ordered]@{
        component="SGODA-FASTPATH-ORCHESTRATOR"
        version=$Version
        baseline=$ExpectedBaseline
        records=$Records
    }

    Write-Utf8NoBomLf $ManifestJson ($ManifestObj | ConvertTo-Json -Depth 12)
    Write-Host "SHA256_MANIFEST=CREATED"

    Step 7 "REPOSITORY SAFETY RECERTIFICATION"

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

    if($HeadAfter -ne $ExpectedBaseline -or $RemoteAfter -ne $ExpectedBaseline){
        Hold "Baseline changed during FASTPATH plan"
    }
    if($StagedAfter.Count -ne 0 -or $ModifiedAfter.Count -ne 0 -or $DeletedAfter.Count -ne 0){
        Hold "Tracked repository state changed during FASTPATH plan"
    }

    Write-Host "REPOSITORY_SAFETY=PASS"

    Step 8 "EXECUTION MODE POLICY"

    if($Mode -eq "PLAN"){
        Write-Host "MODE_PLAN_ONLY=YES"
        Write-Host "EXECUTION_NOT_STARTED=YES"
        Write-Host "NEXT_ACTION=REVIEW_FASTPATH_PLAN_THEN_RUN_EXECUTE"
    }
    else {
        Write-Host "MODE_EXECUTE=REQUESTED"
        Write-Host "EXECUTION_ENGINE=NOT_ENABLED_IN_V1"
        Write-Host "NEXT_ACTION=BUILD_FASTPATH_EXECUTION_ENGINE_FROM_CERTIFIED_PLAN"
    }

    Step 9 "PERFORMANCE SUMMARY"

    $EstimatedLegacyMin = 1 + ($IndexRows.Count * 2)
    $EstimatedLegacyMax = 1 + ($IndexRows.Count * 3)

    Write-Host "LEGACY_ESTIMATED_EXECUTIONS_MIN=$EstimatedLegacyMin"
    Write-Host "LEGACY_ESTIMATED_EXECUTIONS_MAX=$EstimatedLegacyMax"
    Write-Host "FULL_REPOSITORY_SCANS_THIS_RUN=1"
    Write-Host "REDUNDANT_FULL_SCANS_AVOIDED=YES"
    Write-Host "FASTPATH_INDEX_REUSABLE=YES"

    Step 10 "FINAL RESULT"

    Write-Host ""
    Write-Host "SGODA-FASTPATH-ORCHESTRATOR : PLAN READY / PASS" -ForegroundColor Green
    Write-Host "BASELINE=$ExpectedBaseline"
    Write-Host "PENDING_INPUT=27"
    Write-Host "CANDIDATES_INDEXED=$($IndexRows.Count)"
    Write-Host "ALREADY_CLOSED=$AlreadyClosed"
    Write-Host "NEEDS_FORMALIZATION=$NeedsFormalization"
    Write-Host "INCOMPLETE_OR_REVIEW=$Incomplete"
    Write-Host "REPOSITORY_SCANNED_ONCE=YES"
    Write-Host "COMMIT_PERFORMED=NO"
    Write-Host "PUSH_PERFORMED=NO"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "NEXT_ACTION=BUILD_FASTPATH_EXECUTION_ENGINE_FROM_CERTIFIED_PLAN"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
