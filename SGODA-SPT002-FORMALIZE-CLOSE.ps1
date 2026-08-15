#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "2c661a7ec7f87516cd15a3202d2b02c954a1bfc1"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.0"
$Self = "SGODA-SPT002-FORMALIZE-CLOSE.ps1"

$PrepareScript = "SGODA-SPT002-FORMALIZE-PREPARE.ps1"
$PrepareDir = "artifacts/development/SPT-002-FORMALIZE-PREPARE-v1.0.0"
$PrepareAssessment = "$PrepareDir/spt002-real-state-assessment.json"
$PrepareCoverage = "$PrepareDir/spt002-coverage-matrix.json"
$PrepareEvidence = "$PrepareDir/spt002-evidence-inventory.json"
$PrepareGit = "$PrepareDir/spt002-commits-tags-releases.json"
$PrepareDependency = "$PrepareDir/spt002-dependency-sequence-audit.json"
$PrepareContract = "$PrepareDir/spt002-formalization-prepare.json"
$PrepareIntegrity = "$PrepareDir/spt002-prepare-sha256-manifest.json"
$PrepareImplementationEvidence = "$PrepareDir/implementation-evidence.json"
$PrepareDoc = "docs/06_Tecnologia/SPT-002/SGD-SPT002-FORMALIZE-PREPARE-Auditoria-Estado-Real.md"

$CloseDir = "artifacts/development/SPT-002-FORMALIZE-CLOSE-v1.0.0"
$CloseAssessment = "$CloseDir/spt002-formalization-close-assessment.json"
$CloseCoverage = "$CloseDir/spt002-formalization-close-coverage.json"
$CloseReleaseAudit = "$CloseDir/spt002-release-artifact-recertification.json"
$CloseTraceability = "$CloseDir/spt002-historical-traceability.json"
$CloseEvidence = "$CloseDir/implementation-evidence.json"
$CloseManifest = "$CloseDir/spt002-formalization-close-sha256-manifest.json"

$CloseDoc = "docs/06_Tecnologia/SPT-002/SGD-SPT002-FORMALIZATION-CLOSE-v1.0.0.md"
$Acta = "docs/00_Estado_Maestro/ACT-SPT-002-FORMALIZATION-CLOSE-v1.0.0.md"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SPT-002.FORMALIZE.CLOSE : HOLD" -ForegroundColor Red
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
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ Hold ("Missing JSON: "+$Path) }
    try {
        return ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8) | ConvertFrom-Json)
    } catch {
        Hold ("Invalid JSON: "+$Path)
    }
}

function Get-Sha256 {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ Hold ("Missing file: "+$Path) }
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

function Read-Text {
    param([string]$Path)
    try {
        return [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8)
    } catch {
        return ""
    }
}

function Test-AnyMarker {
    param([string]$Path,[string[]]$Markers)
    $Text = Read-Text $Path
    foreach($M in $Markers){
        if($Text -match $M){ return $true }
    }
    return $false
}

function Test-NewTextSecret {
    param([string]$Path)
    $Ext=[IO.Path]::GetExtension($Path).ToLowerInvariant()
    if(@(".ps1",".psm1",".psd1",".py",".json",".md",".txt",".yml",".yaml",".toml",".ini",".cfg") -notcontains $Ext){ return $false }
    try {
        $T=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8)
    } catch { return $false }
    $Patterns=@(
        '-----BEGIN[ ]+(RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
        '(?i)\b(password|passwd|pwd)\s*[:=]\s*["''][^"'']{8,}["'']',
        '(?i)\b(api[_-]?key|secret[_-]?key|access[_-]?token)\s*[:=]\s*["''][^"'']{12,}["'']'
    )
    foreach($Rx in $Patterns){ if($T -match $Rx){ return $true } }
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

    Step 2 "CONSUME SPT-002 FORMALIZE PREPARE"
    $PrepareFiles = @(
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
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ Hold ("PREPARE output missing: "+$P) }
    }

    $Assessment = Read-Json $PrepareAssessment
    $Coverage = Read-Json $PrepareCoverage
    $Evidence = Read-Json $PrepareEvidence
    $PrepareSpec = Read-Json $PrepareContract

    if([string]$Assessment.real_state -ne "IMPLEMENTED_PENDING_FORMALIZATION"){
        Hold "PREPARE does not certify IMPLEMENTED_PENDING_FORMALIZATION"
    }
    if([string]$Assessment.recommended_action -ne "BUILD_FORMALIZATION_CLOSURE_PACKAGE"){
        Hold "PREPARE does not authorize formalization closure package"
    }

    Write-Host "SPT002_PREPARE=PASS"
    Write-Host "SPT002_PREPARE_STATE=IMPLEMENTED_PENDING_FORMALIZATION"
    Write-Host "SPT002_PREPARE_ACTION=BUILD_FORMALIZATION_CLOSURE_PACKAGE"

    Step 3 "RECERTIFY TRACKED FOOTPRINT / RELEASE ARTIFACTS"
    $Tracked = @(& git.exe -c core.quotepath=false ls-files)

    $Direct = @($Tracked | Where-Object {
        $_ -match '(?i)(^|/)SPT-002([^0-9]|$)|(^|/)SPT002([^0-9]|$)|\bSPT[-_.]?002\b'
    })

    $ReleasePaths = @($Direct | Where-Object { $_ -match '(?i)^releases/' })
    $ArtifactPaths = @($Direct | Where-Object { $_ -match '(?i)^artifacts/' })
    $ScriptPaths = @($Direct | Where-Object { $_ -match '(?i)\.ps1$' })
    $DocPaths = @($Direct | Where-Object { $_ -match '(?i)(^|/)docs?/' })

    Write-Host "SPT002_TRACKED_PATHS=$($Direct.Count)"
    Write-Host "SPT002_RELEASE_PATHS=$($ReleasePaths.Count)"
    Write-Host "SPT002_ARTIFACT_PATHS=$($ArtifactPaths.Count)"
    Write-Host "SPT002_SCRIPT_PATHS=$($ScriptPaths.Count)"
    Write-Host "SPT002_DOC_PATHS=$($DocPaths.Count)"

    if($Direct.Count -lt 1){ Hold "SPT-002 tracked footprint missing" }
    if($ReleasePaths.Count -lt 1){ Hold "SPT-002 release representation missing" }
    if($ArtifactPaths.Count -lt 1){ Hold "SPT-002 artifact evidence missing" }

    Write-Host "SPT002_FOOTPRINT_RECERTIFICATION=PASS"

    Step 4 "RECERTIFY HISTORICAL IMPLEMENTATION / CLOSURE MARKERS"
    $ClosureMarkers = @(
        '(?i)\bCLOSED\b',
        '(?i)\bCIERRE\b',
        '(?i)\bCERRADO\b',
        '(?i)FINAL_EXIT_CODE\s*=\s*0',
        '(?i)CLOSURE[_ ]GATE\s*=\s*PASS'
    )
    $ImplementationMarkers = @(
        '(?i)\bIMPLEMENTED\b',
        '(?i)\bAPPROVED\b',
        '(?i)\bFINAL\b',
        '(?i)\bPASS\b'
    )

    $ClosureMarkerFiles = New-Object System.Collections.ArrayList
    $ImplementationMarkerFiles = New-Object System.Collections.ArrayList

    foreach($P in $Direct){
        if(Test-AnyMarker $P $ClosureMarkers){ [void]$ClosureMarkerFiles.Add($P) }
        if(Test-AnyMarker $P $ImplementationMarkers){ [void]$ImplementationMarkerFiles.Add($P) }
    }

    Write-Host "CLOSURE_MARKER_FILES=$($ClosureMarkerFiles.Count)"
    Write-Host "IMPLEMENTATION_MARKER_FILES=$($ImplementationMarkerFiles.Count)"

    if($ClosureMarkerFiles.Count -lt 1){ Hold "No historical closure marker evidence found" }
    if($ImplementationMarkerFiles.Count -lt 1){ Hold "No implementation marker evidence found" }

    Write-Host "HISTORICAL_MARKER_RECERTIFICATION=PASS"

    Step 5 "HISTORICAL TRACEABILITY / RELEASE RECONSTRUCTION"
    $CommitHitsA = @(& git.exe --no-pager log --all --format="%H|%ad|%s" --date=iso --grep="SPT-002" -i)
    $CommitHitsB = @(& git.exe --no-pager log --all --format="%H|%ad|%s" --date=iso --grep="SPT002" -i)
    $CommitSet = New-Object System.Collections.ArrayList

    foreach($C in @($CommitHitsA + $CommitHitsB)){
        if($C -and -not $CommitSet.Contains($C)){ [void]$CommitSet.Add($C) }
    }

    $Tags = @(& git.exe tag --list)
    $TagHits = @($Tags | Where-Object { $_ -match '(?i)SPT[-_.]?002|SPT002' })

    $ReleaseRecords = @()
    foreach($P in $ReleasePaths){
        $ReleaseRecords += [ordered]@{
            path = $P
            sha256 = Get-Sha256 $P
            size_bytes = (Get-Item -LiteralPath $P).Length
        }
    }

    Write-Host "SPT002_COMMIT_HITS=$($CommitSet.Count)"
    Write-Host "SPT002_TAG_HITS=$($TagHits.Count)"
    Write-Host "SPT002_RELEASE_RECORDS=$($ReleaseRecords.Count)"
    Write-Host "TRACEABILITY_RECONSTRUCTION=PASS"

    Step 6 "FORMALIZATION QUALITY GATE"
    # Historical tests were not found by PREPARE. This is recorded, not invented.
    $PrepareTestCount = [int]$Assessment.test_path_count
    $PrepareEvidenceCount = [int]$Assessment.evidence_count
    $PrepareClosureCount = [int]$Assessment.closure_marker_count
    $PrepareReleaseCount = [int]$Assessment.release_path_count

    Write-Host "PREPARE_TEST_PATHS=$PrepareTestCount"
    Write-Host "PREPARE_EVIDENCE_COUNT=$PrepareEvidenceCount"
    Write-Host "PREPARE_CLOSURE_MARKERS=$PrepareClosureCount"
    Write-Host "PREPARE_RELEASE_PATHS=$PrepareReleaseCount"

    if($PrepareEvidenceCount -lt 1){ Hold "PREPARE evidence coverage is insufficient" }
    if($PrepareClosureCount -lt 1){ Hold "PREPARE closure marker coverage is insufficient" }
    if($PrepareReleaseCount -lt 1){ Hold "PREPARE release coverage is insufficient" }

    if($PrepareTestCount -eq 0){
        Write-Host "HISTORICAL_TEST_EVIDENCE=NOT_AVAILABLE"
        Write-Host "TEST_POLICY=DO_NOT_INVENT_OR_RECREATE_CLOSED_HISTORICAL_TESTS"
    } else {
        Write-Host "HISTORICAL_TEST_EVIDENCE=AVAILABLE"
    }

    Write-Host "FORMALIZATION_QUALITY_GATE=PASS"

    Step 7 "COMMITS / TAGS / RELEASES POLICY"
    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"
    Write-Host "TAG_RELEASE_POLICY=RECONCILE_EXISTING_ONLY"
    Write-Host "COMMITS_TAGS_RELEASES_GATE=PASS"

    Step 8 "WRITE FORMALIZATION CLOSURE ARTIFACTS"
    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

    $ReleaseAuditObj=[ordered]@{
        component="SPT-002.FORMALIZE.CLOSE"
        version=$Version
        baseline=$ExpectedBaseline
        generated_at=$Now
        release_paths=@($ReleasePaths)
        release_records=$ReleaseRecords
        artifact_paths=@($ArtifactPaths)
        release_gate="PASS"
        tag_created=$false
        release_created=$false
    }

    $TraceabilityObj=[ordered]@{
        component="SPT-002.FORMALIZE.CLOSE"
        version=$Version
        baseline=$ExpectedBaseline
        commit_hits=@($CommitSet)
        tag_hits=@($TagHits)
        release_paths=@($ReleasePaths)
        closure_marker_files=@($ClosureMarkerFiles)
        implementation_marker_files=@($ImplementationMarkerFiles)
        historical_test_evidence=if($PrepareTestCount -eq 0){"NOT_AVAILABLE"}else{"AVAILABLE"}
        reconstruction_policy="PRESERVE_EXISTING_HISTORY_WITHOUT_INVENTING_MISSING_EVIDENCE"
        gate="PASS"
    }

    $CoverageObj=[ordered]@{
        component="SPT-002.FORMALIZE.CLOSE"
        version=$Version
        baseline=$ExpectedBaseline
        tracked_paths=@($Direct)
        docs=@($DocPaths)
        artifacts=@($ArtifactPaths)
        scripts=@($ScriptPaths)
        releases=@($ReleasePaths)
        closure_marker_files=@($ClosureMarkerFiles)
        implementation_marker_files=@($ImplementationMarkerFiles)
        prepare_evidence_count=$PrepareEvidenceCount
        prepare_test_count=$PrepareTestCount
        coverage_gate="PASS"
    }

    $AssessmentObj=[ordered]@{
        component="SPT-002"
        version=$Version
        baseline=$ExpectedBaseline
        previous_real_state="IMPLEMENTED_PENDING_FORMALIZATION"
        formalized_state="CLOSED"
        closure_type="HISTORICAL_INSTITUTIONAL_FORMALIZATION"
        prepare_consumed=$true
        release_recertification="PASS"
        historical_traceability="PASS"
        formalization_quality_gate="PASS"
        historical_test_evidence=if($PrepareTestCount -eq 0){"NOT_AVAILABLE"}else{"AVAILABLE"}
        test_policy=if($PrepareTestCount -eq 0){"DO_NOT_INVENT_OR_RECREATE_CLOSED_HISTORICAL_TESTS"}else{"USE_EXISTING_EVIDENCE_ONLY"}
        tag_created=$false
        release_created=$false
        reopened=$false
        destructive_cleanup=$false
        new_functionality=$false
        production_change=$false
        next_action="RECONCILE_MASTER_MAP_WITHOUT_REOPENING"
    }

    $EvidenceObj=[ordered]@{
        component="SPT-002.FORMALIZE.CLOSE"
        version=$Version
        baseline=$ExpectedBaseline
        prepare_outputs_consumed=$PrepareFiles
        tracked_path_count=$Direct.Count
        release_path_count=$ReleasePaths.Count
        artifact_path_count=$ArtifactPaths.Count
        closure_marker_count=$ClosureMarkerFiles.Count
        implementation_marker_count=$ImplementationMarkerFiles.Count
        commit_hit_count=$CommitSet.Count
        tag_hit_count=$TagHits.Count
        historical_test_evidence=if($PrepareTestCount -eq 0){"NOT_AVAILABLE"}else{"AVAILABLE"}
        formalization_only=$true
        functional_change=$false
        destructive_cleanup=$false
    }

    Write-Utf8NoBomLf $CloseReleaseAudit ($ReleaseAuditObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $CloseTraceability ($TraceabilityObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $CloseCoverage ($CoverageObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $CloseAssessment ($AssessmentObj | ConvertTo-Json -Depth 16)
    Write-Utf8NoBomLf $CloseEvidence ($EvidenceObj | ConvertTo-Json -Depth 16)

    $CloseDocText=@"
# SPT-002.FORMALIZE.CLOSE

Version: $Version
Baseline de entrada: $ExpectedBaseline

## Objeto

Formalizar institucionalmente el cierre historico de SPT-002 sin reabrir el entregable y sin desarrollar funcionalidad nueva.

## Evidencia recertificada

- Paths tracked: $($Direct.Count)
- Releases existentes: $($ReleasePaths.Count)
- Artefactos existentes: $($ArtifactPaths.Count)
- Marcadores de cierre: $($ClosureMarkerFiles.Count)
- Marcadores de implementacion: $($ImplementationMarkerFiles.Count)
- Commits nominales encontrados: $($CommitSet.Count)
- Tags nominales encontrados: $($TagHits.Count)
- Evidencia historica de pruebas: $(if($PrepareTestCount -eq 0){"NOT_AVAILABLE"}else{"AVAILABLE"})

## Politica de pruebas historicas

Cuando la evidencia historica de pruebas no existe, el cierre no inventa ni reconstruye artificialmente pruebas de un entregable ya implementado. La formalizacion se sustenta en la evidencia tracked, artefactos, releases y marcadores historicos disponibles.

## Resultado

SPT-002 queda formalizado como CLOSED mediante cierre institucional historico.

- Reapertura: NO
- Funcionalidad nueva: NO
- Cambio de produccion: NO
- Limpieza destructiva: NO
- Tag nuevo: NO
- Release nuevo: NO
"@

    $ActaText=@"
# ACT-SPT-002-FORMALIZATION-CLOSE-v1.0.0

Se certifica la formalizacion institucional del cierre historico de SPT-002.

- Baseline de entrada: $ExpectedBaseline
- Estado PREPARE: IMPLEMENTED_PENDING_FORMALIZATION
- Estado formalizado: CLOSED
- Tipo de cierre: HISTORICAL_INSTITUTIONAL_FORMALIZATION
- Releases existentes recertificados: $($ReleasePaths.Count)
- Artefactos existentes recertificados: $($ArtifactPaths.Count)
- Marcadores de cierre: $($ClosureMarkerFiles.Count)
- Evidencia historica de pruebas: $(if($PrepareTestCount -eq 0){"NOT_AVAILABLE"}else{"AVAILABLE"})
- Reapertura de SPT-002: NO
- Funcionalidad nueva: NO
- Tag creado: NO
- Release creado: NO
- Limpieza destructiva: NO

Siguiente accion: reconciliar el Mapa Global de Entregables sin reabrir SPT-002.
"@

    Write-Utf8NoBomLf $CloseDoc $CloseDocText
    Write-Utf8NoBomLf $Acta $ActaText

    Write-Host "FORMALIZATION_CLOSE_ASSESSMENT=CREATED"
    Write-Host "RELEASE_ARTIFACT_RECERTIFICATION=CREATED"
    Write-Host "HISTORICAL_TRACEABILITY=CREATED"
    Write-Host "FORMALIZATION_COVERAGE=CREATED"
    Write-Host "IMPLEMENTATION_EVIDENCE=CREATED"
    Write-Host "FORMALIZATION_DOCUMENT=CREATED"
    Write-Host "INSTITUTIONAL_ACTA=CREATED"

    Step 9 "BUILD EXACT PUBLICATION SET / SHA-256 MANIFEST"
    $OutputSet=@(
        $Self,
        $CloseAssessment,
        $CloseCoverage,
        $CloseReleaseAudit,
        $CloseTraceability,
        $CloseEvidence,
        $CloseDoc,
        $Acta
    )

    foreach($P in $PrepareFiles){
        if(-not $OutputSet.Contains($P)){ $OutputSet += $P }
    }

    $Records=@()
    foreach($P in $OutputSet){
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ Hold ("Publication input missing: "+$P) }
        $Records += [ordered]@{path=$P;sha256=Get-Sha256 $P}
    }

    $ManifestObj=[ordered]@{
        component="SPT-002.FORMALIZE.CLOSE"
        version=$Version
        baseline=$ExpectedBaseline
        records=$Records
    }

    Write-Utf8NoBomLf $CloseManifest ($ManifestObj | ConvertTo-Json -Depth 12)
    $OutputSet += $CloseManifest

    Write-Host "EXACT_PUBLICATION_SET=$($OutputSet.Count)"
    Write-Host "PREPARE_OUTPUTS_INCLUDED=$($PrepareFiles.Count)"
    Write-Host "SHA256_MANIFEST=CREATED"

    Step 10 "JSON / EOL / SECURITY GATE"
    foreach($P in $OutputSet){
        $Ext=[IO.Path]::GetExtension($P).ToLowerInvariant()
        if($Ext -eq ".json"){ $null=Read-Json $P }
        if(Test-NewTextSecret $P){ Hold ("Secret pattern detected in publication output: "+$P) }

        $Attr=@(& git.exe check-attr eol -- $P)
        $Required=""
        foreach($Line in $Attr){ if($Line -match ': eol: (.+)$'){ $Required=$Matches[1].Trim().ToLowerInvariant() } }

        if($Required -eq "lf"){
            $T=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $P).Path,[Text.Encoding]::UTF8)
            if([regex]::Matches($T,"`r`n").Count -ne 0){ Hold ("LF attribute conflict: "+$P) }
        }
        elseif($Required -eq "crlf"){
            $T=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $P).Path,[Text.Encoding]::UTF8)
            $Bare=[regex]::Matches(($T -replace "`r`n",""),"`n").Count
            if($Bare -ne 0){ Hold ("CRLF attribute conflict: "+$P) }
        }
    }

    Write-Host "JSON_VALIDATION=PASS"
    Write-Host "OUTPUT_EOL_GATE=PASS"
    Write-Host "OUTPUT_SECURITY_GATE=PASS"

    Step 11 "CLOSED BASELINE PRESERVATION / ACTIVE UNTRACKED ACCOUNTING"
    $ModifiedNow=@(& git.exe -c core.quotepath=false diff --name-only)
    $DeletedNow=@(& git.exe ls-files --deleted)

    if($ModifiedNow.Count -ne 0){ Hold "Tracked baseline changed before staging" }
    if($DeletedNow.Count -ne 0){ Hold "Tracked deletion detected" }

    $CurrentUntracked=@(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
    $UnexpectedUntracked=@($CurrentUntracked | Where-Object {
        $P=($_ -replace "\\","/")
        $OutputSet -notcontains $P
    })

    $Blocking=@($UnexpectedUntracked | Where-Object {
        $_ -match '(?i)SPT[-_.]?002|SPT002'
    })

    Write-Host "CURRENT_UNTRACKED=$($CurrentUntracked.Count)"
    Write-Host "UNEXPECTED_UNTRACKED=$($UnexpectedUntracked.Count)"
    Write-Host "BLOCKING_SPT002_UNTRACKED=$($Blocking.Count)"

    if($Blocking.Count -ne 0){
        $Blocking | ForEach-Object { Write-Host ("BLOCKING_UNTRACKED="+$_) }
        Hold "Unexpected active SPT-002 content outside publication set"
    }

    Write-Host "CLOSED_BASELINE_PRESERVED=PASS"
    Write-Host "SPT002_UNTRACKED_ACCOUNTING=PASS"

    Step 12 "EXACT CONTROLLED STAGING"
    foreach($P in $OutputSet){
        & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $P
        if($LASTEXITCODE -ne 0){ Hold ("git add failed: "+$P) }
    }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $UnexpectedStaged=@($StagedNow | Where-Object { $OutputSet -notcontains ($_ -replace "\\","/") })
    $MissingStaged=@($OutputSet | Where-Object { $StagedNow -notcontains $_ })

    Write-Host "STAGED=$($StagedNow.Count)"
    Write-Host "EXPECTED_STAGE_SET=$($OutputSet.Count)"
    Write-Host "UNEXPECTED_STAGED=$($UnexpectedStaged.Count)"
    Write-Host "MISSING_STAGED=$($MissingStaged.Count)"

    if($UnexpectedStaged.Count -ne 0 -or $MissingStaged.Count -ne 0 -or $StagedNow.Count -ne $OutputSet.Count){
        Hold "Exact staging mismatch"
    }

    Write-Host "STAGING_QUALITY=PASS"

    Step 13 "GITHUB SIZE / REMOTE PRE-COMMIT GATE"
    $StagedDeletions=@(& git.exe diff --cached --diff-filter=D --name-only)
    if($StagedDeletions.Count -ne 0){ Hold "Staged deletion detected" }

    $Large=New-Object System.Collections.ArrayList
    foreach($P in @(& git.exe -c core.quotepath=false ls-files)){
        $SizeText=(& git.exe cat-file -s (":$P") 2>$null)
        if($LASTEXITCODE -eq 0 -and $SizeText){
            if([int64]$SizeText -ge 100MB){ [void]$Large.Add($P) }
        }
    }

    Write-Host "STAGED_DELETIONS=0"
    Write-Host "INDEX_BLOBS_GE_100MB=$($Large.Count)"
    if($Large.Count -ne 0){ Hold "GitHub size gate failed" }

    Git-Fetch
    $RemotePre=(& git.exe rev-parse "origin/$Branch").Trim()
    $LocalPre=(& git.exe rev-parse HEAD).Trim()
    if($RemotePre -ne $ExpectedBaseline -or $LocalPre -ne $ExpectedBaseline){
        Hold "Remote changed before formalization commit"
    }

    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "REMOTE_PRECOMMIT_GATE=PASS"

    Step 14 "COMMIT SPT-002 FORMALIZATION CLOSURE"
    & git.exe commit -m "chore(spt-002): formalize historical institutional closure"
    if($LASTEXITCODE -ne 0){ Hold "git commit failed" }

    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"
    Write-Host "COMMIT_PERFORMED=YES"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){ Hold "git push failed" }
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

    if($FinalLocal -ne $FinalRemote){ Hold "Final local/remote mismatch" }
    if($FinalAhead -ne 0 -or $FinalBehind -ne 0){ Hold "Final divergence detected" }
    if($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){ Hold "Final repository gate failed" }

    Write-Host ""
    Write-Host "SPT-002.FORMALIZE.CLOSE : INSTITUTIONALLY CLOSED / PASS" -ForegroundColor Green
    Write-Host "SPT002_PREVIOUS_STATE=IMPLEMENTED_PENDING_FORMALIZATION"
    Write-Host "SPT002_FORMALIZED_STATE=CLOSED"
    Write-Host "SPT002_CLOSURE_TYPE=HISTORICAL_INSTITUTIONAL_FORMALIZATION"
    Write-Host "SPT002_REOPENED=NO"
    Write-Host "RELEASE_ARTIFACT_RECERTIFICATION=PASS"
    Write-Host "HISTORICAL_TRACEABILITY=PASS"
    Write-Host "FORMALIZATION_QUALITY_GATE=PASS"
    Write-Host "HISTORICAL_TEST_EVIDENCE=$(if($PrepareTestCount -eq 0){'NOT_AVAILABLE'}else{'AVAILABLE'})"
    Write-Host "TEST_RECREATION=NO"
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
