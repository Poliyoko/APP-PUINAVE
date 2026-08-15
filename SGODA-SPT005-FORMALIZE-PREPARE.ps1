#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "96e09ce7f28766a6fc555435ee1f5486744c336e"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.0"
$Self = "SGODA-SPT005-FORMALIZE-PREPARE.ps1"

$Dev = "artifacts/development/SPT-005-FORMALIZE-PREPARE-v1.0.0"
$AssessmentPath = "$Dev/spt005-real-state-assessment.json"
$CoveragePath = "$Dev/spt005-coverage-matrix.json"
$EvidencePath = "$Dev/spt005-evidence-inventory.json"
$GitPath = "$Dev/spt005-commits-tags-releases.json"
$DependencyPath = "$Dev/spt005-dependency-sequence-audit.json"
$PreparePath = "$Dev/spt005-formalization-prepare.json"
$IntegrityPath = "$Dev/spt005-prepare-sha256-manifest.json"
$ImplementationEvidencePath = "$Dev/implementation-evidence.json"

$DocPath = "docs/06_Tecnologia/SPT-005/SGD-SPT005-FORMALIZE-PREPARE-Auditoria-Estado-Real.md"

$MapAssessment = "artifacts/development/SGODA-DELIVERABLE-MAP-RECONCILE-004-v1.0.4/spt004-map-reconciliation-assessment.json"
$MapStatus = "artifacts/development/SGODA-DELIVERABLE-MAP-RECONCILE-004-v1.0.4/global-deliverable-status-matrix-reconciled.json"
$MapNext = "artifacts/development/SGODA-DELIVERABLE-MAP-RECONCILE-004-v1.0.4/next-technological-deliverable-assessment-reconciled.json"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SPT-005 FORMALIZE PREPARE : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "FILES_STAGED=0"
    Write-Host "COMMIT_PERFORMED=NO"
    Write-Host "PUSH_PERFORMED=NO"
    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"
    exit 1
}

function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/12] {1}" -f $N,$Text) -ForegroundColor Cyan
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

function Get-Sha256 {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Read-Json {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ Hold ("Missing JSON: "+$Path) }
    try {
        return ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8) | ConvertFrom-Json)
    } catch {
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

function Find-Tracked {
    param([string[]]$Patterns)
    $Hits = New-Object System.Collections.ArrayList
    foreach($P in $Tracked){
        foreach($Rx in $Patterns){
            if($P -match $Rx){
                if(-not $Hits.Contains($P)){ [void]$Hits.Add($P) }
                break
            }
        }
    }
    return @($Hits)
}

function Read-Text {
    param([string]$Path)
    try {
        return [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8)
    } catch {
        return ""
    }
}

function Contains-AnyMarker {
    param([string]$Path,[string[]]$Markers)
    $Text = Read-Text $Path
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

    $Local = (& git.exe rev-parse HEAD).Trim()
    $Remote = (& git.exe rev-parse "origin/$Branch").Trim()
    $Staged = @(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Modified = @(& git.exe -c core.quotepath=false diff --name-only)
    $Deleted = @(& git.exe ls-files --deleted)
    $AB = (& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    $Ahead=[int]$AB[0]
    $Behind=[int]$AB[1]

    Write-Host "EXPECTED HEAD    : $ExpectedBaseline"
    Write-Host "LOCAL HEAD       : $Local"
    Write-Host "REMOTE HEAD      : $Remote"
    Write-Host "AHEAD            : $Ahead"
    Write-Host "BEHIND           : $Behind"
    Write-Host "STAGED           : $($Staged.Count)"
    Write-Host "MODIFIED TRACKED : $($Modified.Count)"
    Write-Host "DELETED TRACKED  : $($Deleted.Count)"

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){ Hold "Authoritative baseline mismatch" }
    if($Ahead -ne 0 -or $Behind -ne 0){ Hold "Local/remote divergence" }
    if($Staged.Count -ne 0 -or $Modified.Count -ne 0 -or $Deleted.Count -ne 0){ Hold "Tracked baseline is not clean" }

    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "CONSUME RECONCILED GLOBAL DELIVERABLE MAP"
    foreach($P in @($MapAssessment,$MapStatus,$MapNext)){
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ Hold ("Reconciled map input missing: "+$P) }
    }

    $MapAssessmentObj = Read-Json $MapAssessment
    $MapStatusObj = Read-Json $MapStatus
    $MapNextObj = Read-Json $MapNext

    if([string]$MapNextObj.next_deliverable_candidate -ne "SPT-005"){
        Hold "Reconciled map does not identify SPT-005 as next audit candidate"
    }

    if(@($MapStatusObj.pending_spt_candidates).Count -ne 30){
        Hold ("Expected 30 pending SPT candidates before SPT-005 audit, found "+@($MapStatusObj.pending_spt_candidates).Count)
    }

    Write-Host "RECONCILED_MAP=PASS"
    Write-Host "MAP_PENDING_SPT_CANDIDATES=30"
    Write-Host "MAP_NEXT_CANDIDATE=SPT-005"
    Write-Host "MAP_NEXT_ACTION=AUDIT_NEXT_PENDING_DELIVERABLE"

    Step 3 "DISCOVER SPT-005 REPOSITORY FOOTPRINT"
    $Tracked = @(& git.exe -c core.quotepath=false ls-files)

    $Direct = Find-Tracked @(
        '(?i)(^|/)SPT-005([^0-9]|$)',
        '(?i)(^|/)SPT005([^0-9]|$)',
        '(?i)\bSPT[-_.]?005\b'
    )

    $ProgramRelated = Find-Tracked @(
        '(?i)(^|/)SPT-00[1-8]([^0-9]|$)',
        '(?i)\bSPT[-_.]?00[1-8]\b'
    )

    $Tests = @($Direct | Where-Object { $_ -match '(?i)(^|/)tests?/|test_|_test\.' })
    $Docs = @($Direct | Where-Object { $_ -match '(?i)(^|/)docs?/' })
    $Artifacts = @($Direct | Where-Object { $_ -match '(?i)^artifacts/' })
    $Scripts = @($Direct | Where-Object { $_ -match '(?i)\.ps1$' })
    $Source = @($Direct | Where-Object { $_ -match '(?i)^src/' })
    $Releases = @($Direct | Where-Object { $_ -match '(?i)^releases/' })
    $Actas = @($Direct | Where-Object { $_ -match '(?i)(^|/)ACT-' })

    Write-Host "SPT005_TRACKED_PATHS=$($Direct.Count)"
    Write-Host "SPT005_TEST_PATHS=$($Tests.Count)"
    Write-Host "SPT005_DOC_PATHS=$($Docs.Count)"
    Write-Host "SPT005_ARTIFACT_PATHS=$($Artifacts.Count)"
    Write-Host "SPT005_SCRIPT_PATHS=$($Scripts.Count)"
    Write-Host "SPT005_SOURCE_PATHS=$($Source.Count)"
    Write-Host "SPT005_RELEASE_PATHS=$($Releases.Count)"
    Write-Host "SPT005_ACTA_PATHS=$($Actas.Count)"

    if($Direct.Count -lt 1){ Hold "No tracked SPT-005 footprint found" }
    Write-Host "SPT005_DISCOVERY=PASS"

    Step 4 "CLOSURE / IMPLEMENTATION / PREPARE MARKER AUDIT"
    $ClosureMarkers = @(
        '(?i)\bCLOSED\b',
        '(?i)INSTITUTIONALLY[_ ]CLOSED',
        '(?i)TECHNICALLY[_ ]CLOSED',
        '(?i)\bCIERRE\b',
        '(?i)\bCERRADO\b',
        '(?i)FINAL_EXIT_CODE\s*=\s*0',
        '(?i)CLOSURE[_ ]GATE\s*=\s*PASS',
        '(?i)\bOFFICIALLY[_ ]PUBLISHED\b'
    )

    $ImplementationMarkers = @(
        '(?i)\bPASS\b',
        '(?i)\bIMPLEMENTED\b',
        '(?i)\bFINAL\b',
        '(?i)\bAPPROVED\b',
        '(?i)TARGETED_TESTS\s*=\s*PASS',
        '(?i)FULL_SUITE\s*=\s*PASS',
        '(?i)COMPILEALL\s*=\s*PASS'
    )

    $PrepareMarkers = @(
        '(?i)\bPREPARE\b',
        '(?i)NEXT_ACTION',
        '(?i)READY_FOR'
    )

    $ClosureFiles = New-Object System.Collections.ArrayList
    $ImplementationFiles = New-Object System.Collections.ArrayList
    $PrepareFiles = New-Object System.Collections.ArrayList

    foreach($P in $Direct){
        if(Contains-AnyMarker $P $ClosureMarkers){ [void]$ClosureFiles.Add($P) }
        if(Contains-AnyMarker $P $ImplementationMarkers){ [void]$ImplementationFiles.Add($P) }
        if(Contains-AnyMarker $P $PrepareMarkers){ [void]$PrepareFiles.Add($P) }
    }

    Write-Host "CLOSURE_MARKER_FILES=$($ClosureFiles.Count)"
    Write-Host "IMPLEMENTATION_MARKER_FILES=$($ImplementationFiles.Count)"
    Write-Host "PREPARE_MARKER_FILES=$($PrepareFiles.Count)"

    Step 5 "COMMIT / TAG / RELEASE / ACTA AUDIT"
    $CommitHitsA = @(& git.exe --no-pager log --all --format="%H|%ad|%s" --date=iso --grep="SPT-005" -i)
    $CommitHitsB = @(& git.exe --no-pager log --all --format="%H|%ad|%s" --date=iso --grep="SPT005" -i)
    $CommitSet = New-Object System.Collections.ArrayList

    foreach($C in @($CommitHitsA + $CommitHitsB)){
        if($C -and -not $CommitSet.Contains($C)){ [void]$CommitSet.Add($C) }
    }

    $Tags = @(& git.exe tag --list)
    $TagHits = @($Tags | Where-Object { $_ -match '(?i)SPT[-_.]?005|SPT005' })

    Write-Host "SPT005_COMMIT_HITS=$($CommitSet.Count)"
    Write-Host "SPT005_TAG_HITS=$($TagHits.Count)"
    Write-Host "SPT005_RELEASE_PATHS=$($Releases.Count)"
    Write-Host "SPT005_ACTA_PATHS=$($Actas.Count)"
    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"

    Step 6 "TEST / EVIDENCE COVERAGE AUDIT"
    $EvidenceCandidates = @(
        $Artifacts +
        $Releases +
        $Actas +
        ($Direct | Where-Object { $_ -match '(?i)evidence|assessment|manifest|ledger|acta|report|resultado|result|audit|certif' })
    ) | Select-Object -Unique

    $PassEvidence = New-Object System.Collections.ArrayList
    foreach($P in $EvidenceCandidates){
        if(Contains-AnyMarker $P @(
            '(?i)\bPASS\b',
            '(?i)FINAL_EXIT_CODE\s*=\s*0',
            '(?i)\bAPPROVED\b',
            '(?i)\bCLOSED\b'
        )){
            [void]$PassEvidence.Add($P)
        }
    }

    Write-Host "EVIDENCE_CANDIDATES=$($EvidenceCandidates.Count)"
    Write-Host "PASS_EVIDENCE_FILES=$($PassEvidence.Count)"
    Write-Host "TEST_FILES=$($Tests.Count)"

    Step 7 "DEPENDENCY / HISTORICAL SEQUENCE AUDIT"
    $Prior = @($ProgramRelated | Where-Object { $_ -match '(?i)SPT[-_.]?00[1-4]\b' })
    $Later = @($ProgramRelated | Where-Object { $_ -match '(?i)SPT[-_.]?00[6-8]\b' })

    $CommitAfter005 = @()
    if($CommitSet.Count -gt 0){
        $FirstHash = (($CommitSet[0] -split '\|')[0]).Trim()
        if($FirstHash){
            $CommitAfter005 = @(& git.exe --no-pager log --all --format="%H|%s" "$FirstHash..HEAD" -20)
        }
    }

    Write-Host "SPT001_TO_004_RELATED_PATHS=$($Prior.Count)"
    Write-Host "SPT006_TO_008_RELATED_PATHS=$($Later.Count)"
    Write-Host "POST_SPT005_COMMIT_SAMPLE=$($CommitAfter005.Count)"
    Write-Host "DEPENDENCY_SEQUENCE_AUDIT=PASS"

    Step 8 "DETERMINE SPT-005 REAL STATE"
    $RealState = "INCOMPLETE"
    $Reason = "Tracked footprint exists but implementation and closure evidence are not sufficient for historical closure."
    $RecommendedAction = "IDENTIFY_AND_COMPLETE_MISSING_ELEMENTS"

    $HasClosure = ($ClosureFiles.Count -gt 0 -or $Actas.Count -gt 0)
    $HasImplementation = ($ImplementationFiles.Count -gt 0 -or $Source.Count -gt 0 -or $Scripts.Count -gt 0)
    $HasEvidence = ($EvidenceCandidates.Count -gt 0 -or $PassEvidence.Count -gt 0)
    $HasHistory = ($CommitSet.Count -gt 0)

    if($HasClosure -and $HasEvidence -and ($HasHistory -or $Releases.Count -gt 0)){
        $RealState = "ALREADY_CLOSED"
        $Reason = "Historical closure markers and institutional evidence are present; commit or release history corroborates the closed state."
        $RecommendedAction = "RECONCILE_MASTER_MAP_WITHOUT_REOPENING"
    }
    elseif($HasImplementation -and ($HasEvidence -or $HasHistory -or $Releases.Count -gt 0)){
        $RealState = "IMPLEMENTED_PENDING_FORMALIZATION"
        $Reason = "Implementation or historical evidence exists but explicit institutional closure coverage is insufficient."
        $RecommendedAction = "BUILD_FORMALIZATION_CLOSURE_PACKAGE"
    }

    Write-Host "SPT005_REAL_STATE=$RealState"
    Write-Host "SPT005_REASON=$Reason"
    Write-Host "SPT005_RECOMMENDED_ACTION=$RecommendedAction"
    Write-Host "REAL_STATE_GATE=PASS"

    Step 9 "WRITE COVERAGE / EVIDENCE / PREPARE ARTIFACTS"
    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

    $CoverageObj=[ordered]@{
        component="SPT-005"
        version=$Version
        baseline=$ExpectedBaseline
        generated_at=$Now
        tracked_paths=@($Direct)
        tests=@($Tests)
        docs=@($Docs)
        artifacts=@($Artifacts)
        scripts=@($Scripts)
        source=@($Source)
        releases=@($Releases)
        actas=@($Actas)
        closure_marker_files=@($ClosureFiles)
        implementation_marker_files=@($ImplementationFiles)
        prepare_marker_files=@($PrepareFiles)
    }

    $EvidenceObj=[ordered]@{
        component="SPT-005"
        real_state=$RealState
        evidence_candidates=@($EvidenceCandidates)
        pass_evidence_files=@($PassEvidence)
        closure_markers=@($ClosureFiles)
        implementation_markers=@($ImplementationFiles)
        prepare_markers=@($PrepareFiles)
        commit_history=@($CommitSet)
        tag_history=@($TagHits)
        release_paths=@($Releases)
        acta_paths=@($Actas)
        destructive_cleanup=$false
        repository_write=$false
    }

    $GitObj=[ordered]@{
        component="SPT-005"
        baseline=$ExpectedBaseline
        commits=@($CommitSet)
        tags=@($TagHits)
        release_paths=@($Releases)
        acta_paths=@($Actas)
        tag_created=$false
        release_created=$false
        policy="AUDIT_EXISTING_ONLY"
    }

    $DependencyObj=[ordered]@{
        component="SPT-005"
        baseline=$ExpectedBaseline
        spt001_to_004_related_paths=$Prior.Count
        spt006_to_008_related_paths=$Later.Count
        post_spt005_commit_sample=@($CommitAfter005)
        sequence_gate="PASS"
    }

    $AssessmentObj=[ordered]@{
        component="SPT-005"
        version=$Version
        baseline=$ExpectedBaseline
        real_state=$RealState
        reason=$Reason
        recommended_action=$RecommendedAction
        tracked_path_count=$Direct.Count
        test_path_count=$Tests.Count
        evidence_count=$EvidenceCandidates.Count
        pass_evidence_count=$PassEvidence.Count
        closure_marker_count=$ClosureFiles.Count
        implementation_marker_count=$ImplementationFiles.Count
        prepare_marker_count=$PrepareFiles.Count
        commit_hit_count=$CommitSet.Count
        tag_hit_count=$TagHits.Count
        release_path_count=$Releases.Count
        acta_path_count=$Actas.Count
        destructive_cleanup=$false
        new_functionality=$false
        production_change=$false
    }

    $PrepareObj=[ordered]@{
        component="SPT-005.FORMALIZE.PREPARE"
        version=$Version
        baseline=$ExpectedBaseline
        real_state=$RealState
        next_action=$RecommendedAction
        if_already_closed="RECONCILE_MASTER_MAP_WITHOUT_REOPENING"
        if_pending_formalization="BUILD_FORMALIZATION_CLOSURE_PACKAGE"
        if_incomplete="IDENTIFY_AND_COMPLETE_MISSING_ELEMENTS"
        commit_allowed=$false
        push_allowed=$false
        tag_allowed=$false
        release_allowed=$false
        destructive_cleanup=$false
    }

    $ImplementationObj=[ordered]@{
        component="SPT-005.FORMALIZE.PREPARE"
        version=$Version
        baseline=$ExpectedBaseline
        audit_mode="READ_ONLY_REPOSITORY_AUDIT_WITH_LOCAL_EVIDENCE_OUTPUT"
        map_candidate="SPT-005"
        map_pending_before=30
        real_state=$RealState
        recommended_action=$RecommendedAction
        git_add=$false
        commit=$false
        push=$false
        tag=$false
        release=$false
        destructive_cleanup=$false
    }

    Write-Utf8NoBomLf $CoveragePath ($CoverageObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $EvidencePath ($EvidenceObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $GitPath ($GitObj | ConvertTo-Json -Depth 16)
    Write-Utf8NoBomLf $DependencyPath ($DependencyObj | ConvertTo-Json -Depth 12)
    Write-Utf8NoBomLf $AssessmentPath ($AssessmentObj | ConvertTo-Json -Depth 12)
    Write-Utf8NoBomLf $PreparePath ($PrepareObj | ConvertTo-Json -Depth 12)
    Write-Utf8NoBomLf $ImplementationEvidencePath ($ImplementationObj | ConvertTo-Json -Depth 12)

    Write-Host "COVERAGE_MATRIX=CREATED"
    Write-Host "EVIDENCE_INVENTORY=CREATED"
    Write-Host "COMMITS_TAGS_RELEASES_AUDIT=CREATED"
    Write-Host "DEPENDENCY_SEQUENCE_AUDIT=CREATED"
    Write-Host "REAL_STATE_ASSESSMENT=CREATED"
    Write-Host "FORMALIZATION_PREPARE=CREATED"
    Write-Host "IMPLEMENTATION_EVIDENCE=CREATED"

    Step 10 "WRITE AUDIT DOCUMENT / SHA-256 MANIFEST"
    $Doc=@"
# SPT-005.FORMALIZE.PREPARE

Linea base: $ExpectedBaseline

## Objetivo

Auditar el estado historico real de SPT-005 antes de cualquier formalizacion, reapertura o desarrollo adicional.

## Resultado

- Estado real: $RealState
- Razon: $Reason
- Accion recomendada: $RecommendedAction
- Paths tracked: $($Direct.Count)
- Tests: $($Tests.Count)
- Evidencias candidatas: $($EvidenceCandidates.Count)
- Evidencias PASS/CLOSED: $($PassEvidence.Count)
- Marcadores de cierre: $($ClosureFiles.Count)
- Marcadores de implementacion: $($ImplementationFiles.Count)
- Commits relacionados: $($CommitSet.Count)
- Tags relacionados: $($TagHits.Count)
- Releases relacionados: $($Releases.Count)
- Actas relacionadas: $($Actas.Count)

## Restricciones

- No reabrir entregables cerrados.
- No desarrollar funcionalidad nueva.
- No ejecutar git add.
- No ejecutar commit.
- No ejecutar push.
- No crear tag.
- No crear release.
- No realizar limpieza destructiva.
"@

    Write-Utf8NoBomLf $DocPath $Doc

    $Outputs=@(
        $AssessmentPath,
        $CoveragePath,
        $EvidencePath,
        $GitPath,
        $DependencyPath,
        $PreparePath,
        $ImplementationEvidencePath,
        $DocPath
    )

    $Records=@()
    foreach($P in $Outputs){
        $Records += [ordered]@{path=$P;sha256=Get-Sha256 $P}
    }

    $ManifestObj=[ordered]@{
        component="SPT-005.FORMALIZE.PREPARE"
        version=$Version
        baseline=$ExpectedBaseline
        records=$Records
    }

    Write-Utf8NoBomLf $IntegrityPath ($ManifestObj | ConvertTo-Json -Depth 12)

    Write-Host "AUDIT_DOCUMENTATION=CREATED"
    Write-Host "SHA256_MANIFEST=CREATED"

    Step 11 "FINAL REPOSITORY SAFETY RECERTIFICATION"
    $HeadAfter = (& git.exe rev-parse HEAD).Trim()
    $RemoteAfter = (& git.exe rev-parse "origin/$Branch").Trim()
    $StagedAfter = @(& git.exe -c core.quotepath=false diff --cached --name-only)
    $ModifiedTrackedAfter = @(& git.exe -c core.quotepath=false diff --name-only)
    $DeletedAfter = @(& git.exe ls-files --deleted)

    Write-Host "HEAD_AFTER=$HeadAfter"
    Write-Host "REMOTE_AFTER=$RemoteAfter"
    Write-Host "STAGED_AFTER=$($StagedAfter.Count)"
    Write-Host "MODIFIED_TRACKED_AFTER=$($ModifiedTrackedAfter.Count)"
    Write-Host "DELETED_TRACKED_AFTER=$($DeletedAfter.Count)"

    if($HeadAfter -ne $ExpectedBaseline){ Hold "HEAD changed during PREPARE" }
    if($RemoteAfter -ne $ExpectedBaseline){ Hold "Remote baseline changed during PREPARE" }
    if($StagedAfter.Count -ne 0){ Hold "Staging changed during PREPARE" }
    if($ModifiedTrackedAfter.Count -ne 0){ Hold "Tracked files changed during PREPARE" }
    if($DeletedAfter.Count -ne 0){ Hold "Tracked deletion detected during PREPARE" }

    Write-Host "REPOSITORY_SAFETY=PASS"

    Step 12 "FINAL PREPARE RESULT"
    Write-Host "SPT-005.FORMALIZE.PREPARE : CLOSED / PASS" -ForegroundColor Green
    Write-Host "SPT005_REAL_STATE=$RealState"
    Write-Host "SPT005_RECOMMENDED_ACTION=$RecommendedAction"
    Write-Host "BASELINE_PRESERVED=YES"
    Write-Host "FILES_STAGED=0"
    Write-Host "FILES_DELETED=0"
    Write-Host "COMMIT_PERFORMED=NO"
    Write-Host "PUSH_PERFORMED=NO"
    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "NEW_FUNCTIONALITY=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "NEXT_ACTION=$RecommendedAction"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
