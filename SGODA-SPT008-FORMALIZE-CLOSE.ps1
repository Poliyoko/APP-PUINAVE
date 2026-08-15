#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "fdb42c25aaf530c9d1b6a30d3baa85db88fed6f4"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.0"
$Self = "SGODA-SPT008-FORMALIZE-CLOSE.ps1"

$PrepareScript = "SGODA-SPT008-FORMALIZE-PREPARE.ps1"
$PrepareDir = "artifacts/development/SPT-008-FORMALIZE-PREPARE-v1.0.0"
$PrepareAssessment = "$PrepareDir/spt008-real-state-assessment.json"
$PrepareCoverage = "$PrepareDir/spt008-coverage-matrix.json"
$PrepareEvidence = "$PrepareDir/spt008-evidence-inventory.json"
$PrepareGit = "$PrepareDir/spt008-commits-tags-releases.json"
$PrepareDependency = "$PrepareDir/spt008-dependency-sequence-audit.json"
$PrepareContract = "$PrepareDir/spt008-formalization-prepare.json"
$PrepareIntegrity = "$PrepareDir/spt008-prepare-sha256-manifest.json"
$PrepareImplementationEvidence = "$PrepareDir/implementation-evidence.json"
$PrepareDoc = "docs/06_Tecnologia/SPT-008/SGD-SPT008-FORMALIZE-PREPARE-Auditoria-Estado-Real.md"

$Dev = "artifacts/development/SPT-008-FORMALIZE-CLOSE-v1.0.0"
$CloseAssessment = "$Dev/spt008-formalization-close-assessment.json"
$CoverageRecert = "$Dev/spt008-formalization-close-coverage.json"
$HistoricalTrace = "$Dev/spt008-historical-traceability.json"
$ReleaseRecert = "$Dev/spt008-release-artifact-recertification.json"
$EvidenceRecert = "$Dev/spt008-evidence-recertification.json"
$QualityGate = "$Dev/spt008-formalization-quality-gate.json"
$ImplementationEvidence = "$Dev/implementation-evidence.json"
$CloseIntegrity = "$Dev/spt008-formalization-close-sha256-manifest.json"

$CloseDoc = "docs/06_Tecnologia/SPT-008/SGD-SPT008-FORMALIZATION-CLOSE-v1.0.0.md"
$Acta = "docs/00_Estado_Maestro/ACT-SPT-008-FORMALIZATION-CLOSE-v1.0.0.md"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SPT-008.FORMALIZE.CLOSE : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "TRANSACTION : NOT PUBLISHED"
    exit 1
}

function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Text) -ForegroundColor Cyan
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

function Get-Sha256 {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){
        Hold ("Missing file: "+$Path)
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
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

function Test-NewTextSecret {
    param([string]$Path)

    $Ext=[IO.Path]::GetExtension($Path).ToLowerInvariant()
    if(@(".ps1",".psm1",".psd1",".py",".json",".md",".txt",".yml",".yaml",".toml",".ini",".cfg") -notcontains $Ext){
        return $false
    }

    try {
        $T=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8)
    }
    catch {
        return $false
    }

    $Patterns=@(
        '-----BEGIN[ ]+(RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
        '(?i)\b(password|passwd|pwd)\s*[:=]\s*["''][^"'']{8,}["'']',
        '(?i)\b(api[_-]?key|secret[_-]?key|access[_-]?token)\s*[:=]\s*["''][^"'']{12,}["'']'
    )

    foreach($Rx in $Patterns){
        if($T -match $Rx){ return $true }
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

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){
        Hold "Authoritative baseline mismatch"
    }
    if($Ahead -ne 0 -or $Behind -ne 0){
        Hold "Local/remote divergence"
    }
    if($Staged.Count -ne 0 -or $Modified.Count -ne 0 -or $Deleted.Count -ne 0){
        Hold "Tracked baseline is not clean"
    }

    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "CONSUME SPT-008 FORMALIZE PREPARE"

    $PrepareFiles=@(
        $PrepareScript,
        $PrepareAssessment,
        $PrepareCoverage,
        $PrepareEvidence,
        $PrepareGit,
        $PrepareDependency,
        $PrepareContract,
        $PrepareIntegrity,
        $PrepareImplementationEvidence,
        $PrepareDoc
    )

    foreach($P in $PrepareFiles){
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){
            Hold ("SPT-008 PREPARE output missing: "+$P)
        }
    }

    $Assessment = Read-Json $PrepareAssessment
    $Coverage = Read-Json $PrepareCoverage
    $Evidence = Read-Json $PrepareEvidence
    $GitAudit = Read-Json $PrepareGit
    $Prepare = Read-Json $PrepareContract

    if([string]$Assessment.real_state -ne "IMPLEMENTED_PENDING_FORMALIZATION"){
        Hold "SPT-008 PREPARE does not certify IMPLEMENTED_PENDING_FORMALIZATION"
    }
    if([string]$Assessment.recommended_action -ne "BUILD_FORMALIZATION_CLOSURE_PACKAGE"){
        Hold "SPT-008 PREPARE does not authorize closure package"
    }

    Write-Host "SPT008_PREPARE=PASS"
    Write-Host "SPT008_PREPARE_STATE=IMPLEMENTED_PENDING_FORMALIZATION"
    Write-Host "SPT008_PREPARE_ACTION=BUILD_FORMALIZATION_CLOSURE_PACKAGE"

    Step 3 "RECERTIFY TRACKED FOOTPRINT / HISTORICAL ASSETS"

    $TrackedPaths = @($Coverage.tracked_paths)
    $Tests = @($Coverage.tests)
    $Docs = @($Coverage.docs)
    $Artifacts = @($Coverage.artifacts)
    $Scripts = @($Coverage.scripts)
    $Source = @($Coverage.source)
    $Releases = @($Coverage.releases)
    $Actas = @($Coverage.actas)

    if($TrackedPaths.Count -ne 13){
        Hold ("Expected 13 tracked paths from PREPARE, found "+$TrackedPaths.Count)
    }
    if($Tests.Count -ne 0){
        Hold ("Expected 0 historical test paths from PREPARE, found "+$Tests.Count)
    }
    if($Docs.Count -ne 2){
        Hold ("Expected 2 docs from PREPARE, found "+$Docs.Count)
    }
    if($Artifacts.Count -ne 4){
        Hold ("Expected 4 artifact paths from PREPARE, found "+$Artifacts.Count)
    }
    if($Scripts.Count -ne 1){
        Hold ("Expected 1 script path from PREPARE, found "+$Scripts.Count)
    }
    if($Source.Count -ne 0){
        Hold ("Expected 0 source paths from PREPARE, found "+$Source.Count)
    }
    if($Releases.Count -ne 4){
        Hold ("Expected 4 release paths from PREPARE, found "+$Releases.Count)
    }
    if($Actas.Count -ne 0){
        Hold ("Expected 0 historical acta paths from PREPARE, found "+$Actas.Count)
    }

    foreach($P in $TrackedPaths){
        $TrackedCheck = @(& git.exe ls-files -- $P)
        if($TrackedCheck.Count -eq 0){
            Hold ("PREPARE tracked path no longer tracked: "+$P)
        }
    }

    Write-Host "SPT008_TRACKED_PATHS_RECERTIFIED=$($TrackedPaths.Count)"
    Write-Host "SPT008_TEST_PATHS_RECERTIFIED=$($Tests.Count)"
    Write-Host "SPT008_DOC_PATHS_RECERTIFIED=$($Docs.Count)"
    Write-Host "SPT008_ARTIFACT_PATHS_RECERTIFIED=$($Artifacts.Count)"
    Write-Host "SPT008_SCRIPT_PATHS_RECERTIFIED=$($Scripts.Count)"
    Write-Host "SPT008_SOURCE_PATHS_RECERTIFIED=$($Source.Count)"
    Write-Host "SPT008_RELEASE_PATHS_RECERTIFIED=$($Releases.Count)"
    Write-Host "SPT008_ACTA_PATHS_RECERTIFIED=$($Actas.Count)"
    Write-Host "SPT008_FOOTPRINT_RECERTIFICATION=PASS"

    Step 4 "RECERTIFY HISTORICAL IMPLEMENTATION / EVIDENCE"

    $EvidenceCandidates = @($Evidence.evidence_candidates)
    $PassEvidence = @($Evidence.pass_evidence_files)
    $ImplementationMarkers = @($Evidence.implementation_markers)
    $ClosureMarkers = @($Evidence.closure_markers)

    if($EvidenceCandidates.Count -ne 8){
        Hold ("Expected 8 evidence candidates from PREPARE, found "+$EvidenceCandidates.Count)
    }
    if($PassEvidence.Count -ne 2){
        Hold ("Expected 2 PASS evidence files from PREPARE, found "+$PassEvidence.Count)
    }
    if($ImplementationMarkers.Count -ne 6){
        Hold ("Expected 6 implementation markers from PREPARE, found "+$ImplementationMarkers.Count)
    }
    if($ClosureMarkers.Count -ne 0){
        Hold "PREPARE unexpectedly contains historical closure markers"
    }

    Write-Host "EVIDENCE_CANDIDATES_RECERTIFIED=$($EvidenceCandidates.Count)"
    Write-Host "PASS_EVIDENCE_FILES_RECERTIFIED=$($PassEvidence.Count)"
    Write-Host "IMPLEMENTATION_MARKER_FILES_RECERTIFIED=$($ImplementationMarkers.Count)"
    Write-Host "HISTORICAL_CLOSURE_MARKERS=$($ClosureMarkers.Count)"
    Write-Host "HISTORICAL_IMPLEMENTATION_RECERTIFICATION=PASS"

    Step 5 "HISTORICAL TRACEABILITY / RELEASE RECONSTRUCTION"

    $Commits = @($GitAudit.commits)
    $Tags = @($GitAudit.tags)
    $ReleasePaths = @($GitAudit.release_paths)
    $HistoricalActas = @($GitAudit.acta_paths)

    if($Commits.Count -ne 1){
        Hold ("Expected 1 SPT-008 commit hit from PREPARE, found "+$Commits.Count)
    }
    if($Tags.Count -ne 0){
        Hold ("Expected 0 SPT-008 tags from PREPARE, found "+$Tags.Count)
    }
    if($ReleasePaths.Count -ne 4){
        Hold ("Expected 4 release records from PREPARE, found "+$ReleasePaths.Count)
    }
    if($HistoricalActas.Count -ne 0){
        Hold ("Expected 0 historical actas from PREPARE, found "+$HistoricalActas.Count)
    }

    Write-Host "SPT008_COMMIT_HITS_RECERTIFIED=$($Commits.Count)"
    Write-Host "SPT008_TAG_HITS_RECERTIFIED=$($Tags.Count)"
    Write-Host "SPT008_RELEASE_RECORDS_RECERTIFIED=$($ReleasePaths.Count)"
    Write-Host "SPT008_HISTORICAL_ACTAS=$($HistoricalActas.Count)"
    Write-Host "TRACEABILITY_RECONSTRUCTION=PASS"

    Step 6 "FORMALIZATION QUALITY GATE"

    $HistoricalTestEvidence = "NOT_AVAILABLE"
    $TestRecreation = "NO"
    $TestPolicy = "DO_NOT_INVENT_OR_RECREATE_CLOSED_HISTORICAL_TESTS"

    if($Tests.Count -ne 0){
        Hold "Unexpected historical test paths appeared after PREPARE"
    }

    if($EvidenceCandidates.Count -lt 1 -or $PassEvidence.Count -lt 1 -or $Releases.Count -lt 1 -or $Commits.Count -lt 1){
        Hold "Historical implementation evidence is insufficient for formalization"
    }

    Write-Host "PREPARE_TEST_PATHS=$($Tests.Count)"
    Write-Host "PREPARE_EVIDENCE_COUNT=$($EvidenceCandidates.Count)"
    Write-Host "PREPARE_PASS_EVIDENCE_COUNT=$($PassEvidence.Count)"
    Write-Host "PREPARE_RELEASE_PATHS=$($Releases.Count)"
    Write-Host "PREPARE_COMMIT_HITS=$($Commits.Count)"
    Write-Host "HISTORICAL_TEST_EVIDENCE=$HistoricalTestEvidence"
    Write-Host "TEST_RECREATION=$TestRecreation"
    Write-Host "TEST_POLICY=$TestPolicy"
    Write-Host "FORMALIZATION_QUALITY_GATE=PASS"

    Step 7 "COMMITS / TAGS / RELEASES POLICY"

    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"
    Write-Host "TAG_RELEASE_POLICY=RECONCILE_EXISTING_ONLY"
    Write-Host "COMMITS_TAGS_RELEASES_GATE=PASS"

    Step 8 "WRITE FORMALIZATION CLOSURE ARTIFACTS"

    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

    $CloseAssessmentObj=[ordered]@{
        component="SPT-008.FORMALIZE.CLOSE"
        version=$Version
        authoritative_input_head=$ExpectedBaseline
        previous_state="IMPLEMENTED_PENDING_FORMALIZATION"
        formalized_state="CLOSED"
        closure_type="HISTORICAL_INSTITUTIONAL_FORMALIZATION"
        reopened=$false
        implementation_rewritten=$false
        historical_tests_available=$false
        historical_tests_recreated=$false
        new_functionality=$false
        production_change=$false
        destructive_cleanup=$false
        quality_gate="PASS"
        recommended_next_action="RECONCILE_MASTER_MAP_WITHOUT_REOPENING"
        generated_at=$Now
    }

    $CoverageObj=[ordered]@{
        component="SPT-008.FORMALIZE.CLOSE"
        baseline=$ExpectedBaseline
        tracked_paths=$TrackedPaths.Count
        test_paths=$Tests.Count
        docs=$Docs.Count
        artifacts=$Artifacts.Count
        scripts=$Scripts.Count
        source=$Source.Count
        releases=$Releases.Count
        evidence_candidates=$EvidenceCandidates.Count
        pass_evidence=$PassEvidence.Count
        implementation_markers=$ImplementationMarkers.Count
        historical_closure_markers=$ClosureMarkers.Count
        historical_actas=$HistoricalActas.Count
        formalization_closure_created=$true
    }

    $TraceObj=[ordered]@{
        component="SPT-008"
        baseline=$ExpectedBaseline
        commits=@($Commits)
        tags=@($Tags)
        release_paths=@($ReleasePaths)
        historical_acta_paths=@($HistoricalActas)
        prepare_assessment=$PrepareAssessment
        closure_type="HISTORICAL_INSTITUTIONAL_FORMALIZATION"
        traceability_gate="PASS"
    }

    $ReleaseObj=[ordered]@{
        component="SPT-008"
        baseline=$ExpectedBaseline
        release_paths=@($ReleasePaths)
        release_count=$ReleasePaths.Count
        tag_count=$Tags.Count
        tag_created=$false
        release_created=$false
        recertification="PASS"
    }

    $EvidenceObj=[ordered]@{
        component="SPT-008"
        baseline=$ExpectedBaseline
        evidence_candidates=@($EvidenceCandidates)
        pass_evidence_files=@($PassEvidence)
        evidence_count=$EvidenceCandidates.Count
        pass_evidence_count=$PassEvidence.Count
        historical_tests=@($Tests)
        historical_test_evidence="NOT_AVAILABLE"
        historical_tests_recreated=$false
        recertification="PASS"
    }

    $QualityObj=[ordered]@{
        component="SPT-008.FORMALIZE.CLOSE"
        baseline=$ExpectedBaseline
        prepare_state="IMPLEMENTED_PENDING_FORMALIZATION"
        historical_test_evidence="NOT_AVAILABLE"
        historical_tests_recreated=$false
        test_policy=$TestPolicy
        evidence_candidates=$EvidenceCandidates.Count
        pass_evidence=$PassEvidence.Count
        release_paths=$Releases.Count
        commit_hits=$Commits.Count
        formalization_quality_gate="PASS"
    }

    $ImplementationObj=[ordered]@{
        component="SPT-008.FORMALIZE.CLOSE"
        baseline=$ExpectedBaseline
        purpose="FORMALIZE_EXISTING_HISTORICAL_IMPLEMENTATION_ONLY"
        prepare_consumed=$true
        prepare_evidence_published=$true
        implementation_rewritten=$false
        historical_tests_recreated=$false
        destructive_cleanup=$false
        new_functionality=$false
        production_change=$false
    }

    Write-Utf8NoBomLf $CloseAssessment ($CloseAssessmentObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $CoverageRecert ($CoverageObj | ConvertTo-Json -Depth 16)
    Write-Utf8NoBomLf $HistoricalTrace ($TraceObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $ReleaseRecert ($ReleaseObj | ConvertTo-Json -Depth 16)
    Write-Utf8NoBomLf $EvidenceRecert ($EvidenceObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $QualityGate ($QualityObj | ConvertTo-Json -Depth 16)
    Write-Utf8NoBomLf $ImplementationEvidence ($ImplementationObj | ConvertTo-Json -Depth 16)

    $CloseDocText=@"
# SPT-008 - Cierre Institucional Historico v1.0.0

Baseline de entrada: $ExpectedBaseline

## Estado previo

IMPLEMENTED_PENDING_FORMALIZATION

## Estado formalizado

CLOSED

## Fundamento

El PREPARE de SPT-008 certifico una implementacion historica real con:

- 13 paths tracked.
- 0 paths de pruebas historicas.
- 2 documentos.
- 4 artefactos.
- 1 script.
- 0 source paths.
- 4 rutas de release.
- 8 evidencias candidatas.
- 2 evidencias PASS.
- 6 marcadores de implementacion.
- 1 commit relacionado.
- 0 tags.
- 0 actas historicas.
- 0 marcadores historicos explicitos de cierre.

La ausencia de pruebas historicas se registra expresamente. No se inventan ni recrean pruebas para alterar retrospectivamente el estado historico.

## Politicas aplicadas

- Reapertura: NO.
- Recreacion de pruebas historicas: NO.
- Funcionalidad nueva: NO.
- Cambio de produccion: NO.
- Limpieza destructiva: NO.
- Tag nuevo: NO.
- Release nuevo: NO.
- Siguiente accion: RECONCILE_MASTER_MAP_WITHOUT_REOPENING.
"@

    $ActaText=@"
# ACT-SPT-008-FORMALIZATION-CLOSE-v1.0.0

Se formaliza institucionalmente el cierre historico de SPT-008.

- Baseline de entrada: $ExpectedBaseline
- Estado previo: IMPLEMENTED_PENDING_FORMALIZATION
- Estado formalizado: CLOSED
- Tipo de cierre: HISTORICAL_INSTITUTIONAL_FORMALIZATION
- SPT-008 reabierto: NO
- Evidencia historica de pruebas: NOT_AVAILABLE
- Pruebas historicas recreadas: NO
- Evidencias candidatas recertificadas: $($EvidenceCandidates.Count)
- Evidencias PASS recertificadas: $($PassEvidence.Count)
- Releases recertificados: $($Releases.Count)
- Commits recertificados: $($Commits.Count)
- Tag creado: NO
- Release creado: NO
- Funcionalidad nueva: NO
- Cambio de produccion: NO
- Limpieza destructiva: NO
- Quality gate: PASS
- Siguiente accion: RECONCILE_MASTER_MAP_WITHOUT_REOPENING
"@

    Write-Utf8NoBomLf $CloseDoc $CloseDocText
    Write-Utf8NoBomLf $Acta $ActaText

    Write-Host "FORMALIZATION_CLOSE_ASSESSMENT=CREATED"
    Write-Host "FORMALIZATION_COVERAGE=CREATED"
    Write-Host "HISTORICAL_TRACEABILITY=CREATED"
    Write-Host "RELEASE_ARTIFACT_RECERTIFICATION=CREATED"
    Write-Host "EVIDENCE_RECERTIFICATION=CREATED"
    Write-Host "FORMALIZATION_QUALITY_GATE=CREATED"
    Write-Host "IMPLEMENTATION_EVIDENCE=CREATED"
    Write-Host "FORMALIZATION_DOCUMENT=CREATED"
    Write-Host "INSTITUTIONAL_ACTA=CREATED"

    Step 9 "BUILD EXACT PUBLICATION SET / SHA-256 MANIFEST"

    $OutputSet=@(
        $Self,
        $CloseAssessment,
        $CoverageRecert,
        $HistoricalTrace,
        $ReleaseRecert,
        $EvidenceRecert,
        $QualityGate,
        $ImplementationEvidence,
        $CloseDoc,
        $Acta
    )

    foreach($P in $PrepareFiles){
        if(-not $OutputSet.Contains($P)){
            $OutputSet += $P
        }
    }

    $Records=@()
    foreach($P in $OutputSet){
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){
            Hold ("Publication input missing: "+$P)
        }
        $Records += [ordered]@{
            path=$P
            sha256=Get-Sha256 $P
        }
    }

    $ManifestObj=[ordered]@{
        component="SPT-008.FORMALIZE.CLOSE"
        version=$Version
        baseline=$ExpectedBaseline
        records=$Records
    }

    Write-Utf8NoBomLf $CloseIntegrity ($ManifestObj | ConvertTo-Json -Depth 12)
    $OutputSet += $CloseIntegrity

    Write-Host "EXACT_PUBLICATION_SET=$($OutputSet.Count)"
    Write-Host "PREPARE_OUTPUTS_INCLUDED=$($PrepareFiles.Count)"
    Write-Host "SHA256_MANIFEST=CREATED"

    Step 10 "JSON / EOL / SECURITY GATE"

    foreach($P in $OutputSet){
        $Ext=[IO.Path]::GetExtension($P).ToLowerInvariant()

        if($Ext -eq ".json"){
            $null=Read-Json $P
        }

        if(Test-NewTextSecret $P){
            Hold ("Secret pattern detected in publication output: "+$P)
        }

        $Attr=@(& git.exe check-attr eol -- $P)
        $Required=""

        foreach($Line in $Attr){
            if($Line -match ': eol: (.+)$'){
                $Required=$Matches[1].Trim().ToLowerInvariant()
            }
        }

        if($Required -eq "lf"){
            $T=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $P).Path,[Text.Encoding]::UTF8)
            if([regex]::Matches($T,"`r`n").Count -ne 0){
                Hold ("LF attribute conflict: "+$P)
            }
        }
        elseif($Required -eq "crlf"){
            $T=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $P).Path,[Text.Encoding]::UTF8)
            $Bare=[regex]::Matches(($T -replace "`r`n",""),"`n").Count
            if($Bare -ne 0){
                Hold ("CRLF attribute conflict: "+$P)
            }
        }
    }

    Write-Host "JSON_VALIDATION=PASS"
    Write-Host "OUTPUT_EOL_GATE=PASS"
    Write-Host "OUTPUT_SECURITY_GATE=PASS"

    Step 11 "CLOSED BASELINE PRESERVATION / ACTIVE UNTRACKED ACCOUNTING"

    $ModifiedNow=@(& git.exe -c core.quotepath=false diff --name-only)
    $DeletedNow=@(& git.exe ls-files --deleted)

    if($ModifiedNow.Count -ne 0){
        Hold "Tracked baseline changed before staging"
    }
    if($DeletedNow.Count -ne 0){
        Hold "Tracked deletion detected"
    }

    $CurrentUntracked=@(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)

    $UnexpectedUntracked=@($CurrentUntracked | Where-Object {
        $P=($_ -replace "\\","/")
        $OutputSet -notcontains $P
    })

    $Blocking=@($UnexpectedUntracked | Where-Object {
        $_ -match '(?i)SPT[-_.]?008|SPT008|FORMALIZE-CLOSE'
    })

    Write-Host "CURRENT_UNTRACKED=$($CurrentUntracked.Count)"
    Write-Host "EXPECTED_PUBLICATION_UNTRACKED=$($OutputSet.Count)"
    Write-Host "UNEXPECTED_UNTRACKED=$($UnexpectedUntracked.Count)"
    Write-Host "BLOCKING_SPT008_UNTRACKED=$($Blocking.Count)"

    if($Blocking.Count -ne 0){
        $Blocking | ForEach-Object {
            Write-Host ("BLOCKING_UNTRACKED="+$_)
        }
        Hold "Unexpected active SPT-008 closure content outside publication set"
    }

    Write-Host "CLOSED_BASELINE_PRESERVED=PASS"
    Write-Host "SPT008_UNTRACKED_ACCOUNTING=PASS"

    Step 12 "EXACT CONTROLLED STAGING"

    foreach($P in $OutputSet){
        & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $P
        if($LASTEXITCODE -ne 0){
            Hold ("git add failed: "+$P)
        }
    }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)

    $UnexpectedStaged=@($StagedNow | Where-Object {
        $OutputSet -notcontains ($_ -replace "\\","/")
    })

    $MissingStaged=@($OutputSet | Where-Object {
        $StagedNow -notcontains $_
    })

    Write-Host "STAGED=$($StagedNow.Count)"
    Write-Host "EXPECTED_STAGE_SET=$($OutputSet.Count)"
    Write-Host "UNEXPECTED_STAGED=$($UnexpectedStaged.Count)"
    Write-Host "MISSING_STAGED=$($MissingStaged.Count)"

    if($UnexpectedStaged.Count -ne 0 -or
       $MissingStaged.Count -ne 0 -or
       $StagedNow.Count -ne $OutputSet.Count){
        Hold "Exact staging mismatch"
    }

    Write-Host "STAGING_QUALITY=PASS"

    Step 13 "GITHUB SIZE / REMOTE PRE-COMMIT GATE"

    $StagedDeletions=@(& git.exe diff --cached --diff-filter=D --name-only)

    if($StagedDeletions.Count -ne 0){
        Hold "Staged deletion detected"
    }

    $Large=New-Object System.Collections.ArrayList

    foreach($P in @(& git.exe -c core.quotepath=false ls-files)){
        $SizeText=(& git.exe cat-file -s (":$P") 2>$null)

        if($LASTEXITCODE -eq 0 -and $SizeText){
            if([int64]$SizeText -ge 100MB){
                [void]$Large.Add($P)
            }
        }
    }

    Write-Host "STAGED_DELETIONS=0"
    Write-Host "INDEX_BLOBS_GE_100MB=$($Large.Count)"

    if($Large.Count -ne 0){
        Hold "GitHub size gate failed"
    }

    Git-Fetch

    $RemotePre=(& git.exe rev-parse "origin/$Branch").Trim()
    $LocalPre=(& git.exe rev-parse HEAD).Trim()

    if($RemotePre -ne $ExpectedBaseline -or $LocalPre -ne $ExpectedBaseline){
        Hold "Remote changed before formalization commit"
    }

    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "REMOTE_PRECOMMIT_GATE=PASS"

    Step 14 "COMMIT SPT-008 FORMALIZATION CLOSURE"

    & git.exe commit -m "chore(spt-008): formalize historical institutional closure"

    if($LASTEXITCODE -ne 0){
        Hold "git commit failed"
    }

    $NewCommit=(& git.exe rev-parse HEAD).Trim()

    Write-Host "NEW COMMIT : $NewCommit"
    Write-Host "COMMIT_PERFORMED=YES"

    Step 15 "PUSH"

    & git.exe push origin $Branch

    if($LASTEXITCODE -ne 0){
        Hold "git push failed"
    }

    Write-Host "PUSH=PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / FORMALIZATION CLOSURE"

    Git-Fetch

    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse "origin/$Branch").Trim()
    $FinalAB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    $FinalAhead=[int]$FinalAB[0]
    $FinalBehind=[int]$FinalAB[1]
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "AHEAD           : $FinalAhead"
    Write-Host "BEHIND          : $FinalBehind"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if($FinalLocal -ne $FinalRemote){
        Hold "Final local/remote mismatch"
    }
    if($FinalAhead -ne 0 -or $FinalBehind -ne 0){
        Hold "Final divergence detected"
    }
    if($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){
        Hold "Final repository gate failed"
    }

    Write-Host ""
    Write-Host "SPT-008.FORMALIZE.CLOSE : INSTITUTIONALLY CLOSED / PASS" -ForegroundColor Green
    Write-Host "SPT008_PREVIOUS_STATE=IMPLEMENTED_PENDING_FORMALIZATION"
    Write-Host "SPT008_FORMALIZED_STATE=CLOSED"
    Write-Host "SPT008_CLOSURE_TYPE=HISTORICAL_INSTITUTIONAL_FORMALIZATION"
    Write-Host "SPT008_REOPENED=NO"
    Write-Host "FORMALIZATION_QUALITY_GATE=PASS"
    Write-Host "HISTORICAL_TEST_EVIDENCE=NOT_AVAILABLE"
    Write-Host "TEST_RECREATION=NO"
    Write-Host "EVIDENCE_CANDIDATES_RECERTIFIED=$($EvidenceCandidates.Count)"
    Write-Host "PASS_EVIDENCE_FILES_RECERTIFIED=$($PassEvidence.Count)"
    Write-Host "RELEASE_PATHS_RECERTIFIED=$($Releases.Count)"
    Write-Host "COMMIT_HITS_RECERTIFIED=$($Commits.Count)"
    Write-Host "PREPARE_EVIDENCE_PUBLISHED=YES"
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
    Write-Host "INSTITUTIONAL_MASTER_BASELINE=$FinalLocal"
    Write-Host "NEXT_ACTION=RECONCILE_MASTER_MAP_WITHOUT_REOPENING"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
