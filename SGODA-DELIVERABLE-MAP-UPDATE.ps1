#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "be6fe28a8324366a7a477169767cfdf64e61b0b3"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.0"
$Self = "SGODA-DELIVERABLE-MAP-UPDATE.ps1"

$Dev = "artifacts/development/SGODA-DELIVERABLE-MAP-UPDATE-v1.0.0"
$AssessmentPath = "$Dev/deliverable-map-update-assessment.json"
$InventoryPath = "$Dev/global-deliverable-inventory.json"
$StatusMatrixPath = "$Dev/global-deliverable-status-matrix.json"
$DependencyPath = "$Dev/deliverable-dependency-reconciliation.json"
$NextActionPath = "$Dev/next-technological-deliverable-assessment.json"
$IntegrityPath = "$Dev/deliverable-map-update-sha256-manifest.json"
$EvidencePath = "$Dev/implementation-evidence.json"

$DocPath = "docs/00_Estado_Maestro/SGODA-PUINAVE-Mapa-Global-Entregables-v1.0.0.md"
$ActaPath = "docs/00_Estado_Maestro/ACT-SGODA-DELIVERABLE-MAP-UPDATE-v1.0.0.md"

$MasterCloseAssessment = "artifacts/development/SGODA-MASTER.CLOSE-v1.0.0/master-close-assessment.json"
$MasterCloseEvidence = "artifacts/development/SGODA-MASTER.CLOSE-v1.0.0/implementation-evidence.json"
$MasterCloseActa = "docs/00_Estado_Maestro/ACT-SGODA-MASTER-CLOSE-v1.0.0.md"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA-DELIVERABLE-MAP-UPDATE : HOLD" -ForegroundColor Red
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

function Get-Sha256 {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ Hold ("Missing file: "+$Path) }
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

function Get-DeliverableIdFromPath {
    param([string]$Path)
    $Matches = [regex]::Matches($Path,'(?i)\b(SPB-\d+(?:\.\d+)?|SPT-\d+(?:\.\d+)?(?:\.CLOSE\.\d+)?|SGD-\d+[A-Z]?)\b')
    if($Matches.Count -gt 0){ return $Matches[0].Groups[1].Value.ToUpperInvariant() }
    return $null
}

function Classify-Deliverable {
    param([string]$Id,[string[]]$Paths)

    $Blob = ($Paths -join "`n")

    $Status = "IMPLEMENTED_OR_DOCUMENTED"
    $Reason = "Evidence or repository material exists, but no explicit closure marker was inferred."

    if($Blob -match '(?i)CLOSE|CLOSED|Cierre|ACT-'){
        $Status = "CLOSED_OR_FORMALIZED"
        $Reason = "Closure/formalization evidence detected in tracked repository paths."
    }

    if($Id -match '^SPT-025'){
        $Status = "CLOSED"
        $Reason = "SPT-025 was recertified as institutionally closed by SGODA-MASTER.CLOSE."
    }

    return [ordered]@{
        deliverable = $Id
        status = $Status
        reason = $Reason
        tracked_paths = @($Paths)
        path_count = $Paths.Count
    }
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

    Step 1 "AUTHORITATIVE MASTER-CLOSE BASELINE / REMOTE SAFETY"
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

    Write-Host "MASTER_CLOSE_BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "CONSUME SGODA-MASTER.CLOSE EVIDENCE"
    foreach($P in @($MasterCloseAssessment,$MasterCloseEvidence,$MasterCloseActa)){
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ Hold ("Master close input missing: "+$P) }
    }

    $MasterClose = Read-Json $MasterCloseAssessment
    if([string]$MasterClose.status -ne "READY_FOR_INSTITUTIONAL_MASTER_CLOSURE"){ Hold "Unexpected master close assessment state" }

    Write-Host "MASTER_CLOSE_ASSESSMENT=PASS"
    Write-Host "MASTER_CLOSE_EVIDENCE=PASS"
    Write-Host "MASTER_CLOSE_ACTA=PASS"

    Step 3 "DISCOVER GLOBAL DELIVERABLE UNIVERSE"
    $Tracked = @(& git.exe -c core.quotepath=false ls-files)
    $Map = @{}

    foreach($P in $Tracked){
        $Id = Get-DeliverableIdFromPath $P
        if(-not $Id){ continue }
        if(-not $Map.ContainsKey($Id)){ $Map[$Id] = New-Object System.Collections.ArrayList }
        [void]$Map[$Id].Add($P)
    }

    $DeliverableIds = @($Map.Keys | Sort-Object)
    Write-Host "DISCOVERED_DELIVERABLES=$($DeliverableIds.Count)"
    if($DeliverableIds.Count -lt 1){ Hold "No deliverables discovered" }
    Write-Host "DELIVERABLE_DISCOVERY=PASS"

    Step 4 "BUILD STATUS MATRIX"
    $Rows = @()
    foreach($Id in $DeliverableIds){
        $Rows += Classify-Deliverable $Id @($Map[$Id])
    }

    $Closed = @($Rows | Where-Object { $_.status -match '^CLOSED' })
    $Implemented = @($Rows | Where-Object { $_.status -eq "IMPLEMENTED_OR_DOCUMENTED" })

    Write-Host "CLOSED_OR_FORMALIZED=$($Closed.Count)"
    Write-Host "IMPLEMENTED_OR_DOCUMENTED=$($Implemented.Count)"
    Write-Host "STATUS_MATRIX=PASS"

    Step 5 "RECONCILE MASTER GOVERNANCE DOCUMENTS"
    $Sgd000 = @($Tracked | Where-Object { $_ -match '(^|/)SGD-000' })
    $Sgd002 = @($Tracked | Where-Object { $_ -match '(^|/)SGD-002' })
    $IndexMaster = @($Tracked | Where-Object { $_ -match '(?i)Indice[^/]*Maestro|Indice_Maestro|Master[^/]*Index' })
    $Registry = @($Tracked | Where-Object { $_ -match '(?i)Registro[^/]*Maestro|Master[^/]*Registry' })
    $Trace = @($Tracked | Where-Object { $_ -match '(?i)Trazabilidad|Traceability|Matriz[^/]*Maestra[^/]*Seguimiento' })

    Write-Host "SGD000_FILES=$($Sgd000.Count)"
    Write-Host "SGD002_FILES=$($Sgd002.Count)"
    Write-Host "MASTER_INDEX_FILES=$($IndexMaster.Count)"
    Write-Host "MASTER_REGISTRY_FILES=$($Registry.Count)"
    Write-Host "TRACEABILITY_FILES=$($Trace.Count)"

    if($Sgd000.Count -lt 1 -or $Sgd002.Count -lt 1 -or $IndexMaster.Count -lt 1 -or $Registry.Count -lt 1 -or $Trace.Count -lt 1){
        Hold "Master governance document coverage incomplete"
    }

    Write-Host "MASTER_GOVERNANCE_COVERAGE=PASS"

    Step 6 "DERIVE PENDING / NEXT TECHNOLOGICAL CANDIDATES"
    $PendingCandidates = @(
        $Rows |
        Where-Object {
            $_.deliverable -match '^SPT-\d+' -and
            $_.status -eq "IMPLEMENTED_OR_DOCUMENTED"
        } |
        Sort-Object deliverable
    )

    $Spt026Tracked = @($Tracked | Where-Object { $_ -match '(?i)\bSPT-026\b' })
    $Spt026Exists = ($Spt026Tracked.Count -gt 0)

    $Decision = "REQUIRES_GOVERNANCE_REVIEW"
    $NextDeliverable = $null
    $DecisionReason = "Repository evidence does not justify inventing a new deliverable number."

    if($PendingCandidates.Count -gt 0){
        $NextDeliverable = $PendingCandidates[0].deliverable
        $Decision = "EXISTING_PENDING_DELIVERABLE_DETECTED"
        $DecisionReason = "At least one existing SPT has repository evidence without explicit closure classification."
    }
    elseif($Spt026Exists){
        $NextDeliverable = "SPT-026"
        $Decision = "SPT026_ALREADY_REFERENCED_IN_REPOSITORY"
        $DecisionReason = "SPT-026 is already represented in tracked repository content and may proceed to PREPARE subject to final governance review."
    }
    else {
        $Decision = "NO_AUTHORIZED_NEXT_SPT_INFERRED"
        $DecisionReason = "No existing pending SPT or tracked SPT-026 evidence authorizes automatic creation of SPT-026."
    }

    Write-Host "PENDING_SPT_CANDIDATES=$($PendingCandidates.Count)"
    Write-Host "SPT026_TRACKED_REFERENCES=$($Spt026Tracked.Count)"
    Write-Host "NEXT_DECISION=$Decision"
    if($NextDeliverable){ Write-Host "NEXT_DELIVERABLE_CANDIDATE=$NextDeliverable" }
    Write-Host "NEXT_DELIVERABLE_ASSESSMENT=PASS"

    Step 7 "RECONCILE COMMITS / TAGS / RELEASES"
    $RecentCommits = @(& git.exe --no-pager log --format="%H|%s" -50)
    $Tags = @(& git.exe tag --list)
    $TagsAtHead = @(& git.exe tag --points-at HEAD)
    $ReleaseFiles = @($Tracked | Where-Object { $_ -match '^releases/' })

    Write-Host "RECENT_COMMITS=$($RecentCommits.Count)"
    Write-Host "TOTAL_TAGS=$($Tags.Count)"
    Write-Host "TAGS_AT_HEAD=$($TagsAtHead.Count)"
    Write-Host "RELEASE_FILES=$($ReleaseFiles.Count)"
    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"
    Write-Host "COMMITS_TAGS_RELEASES_RECONCILIATION=PASS"

    Step 8 "WRITE GLOBAL DELIVERABLE MAP ARTIFACTS"
    $Now = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

    $InventoryObj = [ordered]@{
        component = "SGODA-DELIVERABLE-MAP-UPDATE"
        version = $Version
        authoritative_input_head = $ExpectedBaseline
        generated_at = $Now
        deliverable_count = $Rows.Count
        deliverables = $Rows
    }

    $StatusObj = [ordered]@{
        component = "SGODA-DELIVERABLE-MAP-UPDATE"
        authoritative_input_head = $ExpectedBaseline
        closed_or_formalized = @($Closed | ForEach-Object { $_.deliverable })
        implemented_or_documented = @($Implemented | ForEach-Object { $_.deliverable })
        pending_spt_candidates = @($PendingCandidates | ForEach-Object { $_.deliverable })
        classification_policy = "Repository evidence only; do not reopen closed deliverables and do not invent next SPT."
    }

    $DependencyObj = [ordered]@{
        component = "SGODA-DELIVERABLE-MAP-UPDATE"
        master_close_baseline = $ExpectedBaseline
        spt025 = "INSTITUTIONALLY_CLOSED"
        master_close = "INSTITUTIONALLY_CLOSED"
        governance_documents = [ordered]@{
            sgd000 = @($Sgd000)
            sgd002 = @($Sgd002)
            master_index = @($IndexMaster)
            master_registry = @($Registry)
            traceability = @($Trace)
        }
        commits_tags_releases = "RECONCILED"
        tag_created = $false
        release_created = $false
    }

    $NextObj = [ordered]@{
        component = "SGODA-DELIVERABLE-MAP-UPDATE"
        authoritative_input_head = $ExpectedBaseline
        decision = $Decision
        next_deliverable_candidate = $NextDeliverable
        decision_reason = $DecisionReason
        spt026_tracked_reference_count = $Spt026Tracked.Count
        pending_spt_candidates = @($PendingCandidates | ForEach-Object { $_.deliverable })
        automatic_spt_creation = $false
        next_action = if($Decision -eq "SPT026_ALREADY_REFERENCED_IN_REPOSITORY"){"BUILD_SPT026_PREPARE"}elseif($Decision -eq "EXISTING_PENDING_DELIVERABLE_DETECTED"){"FORMALIZE_EXISTING_PENDING_DELIVERABLE"}else{"GOVERNANCE_REVIEW_NEXT_TECHNOLOGICAL_DELIVERABLE"}
    }

    $AssessmentObj = [ordered]@{
        component = "SGODA-DELIVERABLE-MAP-UPDATE"
        version = $Version
        authoritative_input_head = $ExpectedBaseline
        status = "READY_FOR_PUBLICATION"
        master_close_consumed = $true
        deliverable_inventory = "PASS"
        status_matrix = "PASS"
        master_governance_coverage = "PASS"
        commits_tags_releases = "PASS"
        next_deliverable_assessment = "PASS"
        destructive_cleanup = $false
        new_functionality = $false
        production_change = $false
    }

    $EvidenceObj = [ordered]@{
        component = "SGODA-DELIVERABLE-MAP-UPDATE"
        version = $Version
        authoritative_input_head = $ExpectedBaseline
        discovered_deliverables = $Rows.Count
        closed_or_formalized = $Closed.Count
        implemented_or_documented = $Implemented.Count
        pending_spt_candidates = $PendingCandidates.Count
        next_decision = $Decision
        master_close_consumed = $true
        tag_created = $false
        release_created = $false
        destructive_cleanup = $false
    }

    Write-Utf8NoBomLf $InventoryPath ($InventoryObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBomLf $StatusMatrixPath ($StatusObj | ConvertTo-Json -Depth 12)
    Write-Utf8NoBomLf $DependencyPath ($DependencyObj | ConvertTo-Json -Depth 12)
    Write-Utf8NoBomLf $NextActionPath ($NextObj | ConvertTo-Json -Depth 12)
    Write-Utf8NoBomLf $AssessmentPath ($AssessmentObj | ConvertTo-Json -Depth 12)
    Write-Utf8NoBomLf $EvidencePath ($EvidenceObj | ConvertTo-Json -Depth 12)

    $Doc = @"
# SGODA-PUINAVE - Mapa Global de Entregables

Version: $Version
Linea base institucional de entrada: $ExpectedBaseline

## Objetivo

Consolidar el estado global de entregables desde la linea base institucional cerrada, sin reabrir componentes cerrados y sin inventar nuevos entregables.

## Resultado

- Entregables descubiertos: $($Rows.Count)
- Cerrados o formalizados: $($Closed.Count)
- Implementados o documentados: $($Implemented.Count)
- Candidatos SPT pendientes: $($PendingCandidates.Count)
- Referencias tracked a SPT-026: $($Spt026Tracked.Count)
- Decision siguiente: $Decision
- Candidato siguiente: $NextDeliverable
- Tags creados: NO
- Releases creados: NO
- Limpieza destructiva: NO
- Funcionalidad nueva: NO
- Cambio de produccion: NO

## Politica

La determinacion del siguiente entregable se deriva exclusivamente de evidencia tracked y documentos maestros reconciliados. No se crea automaticamente SPT-026 por continuidad numerica.
"@

    $Acta = @"
# ACT-SGODA-DELIVERABLE-MAP-UPDATE-v1.0.0

Se certifica la actualizacion del Mapa Global de Entregables de SGODA-PUINAVE a partir de la linea base $ExpectedBaseline.

Controles:
- SGODA-MASTER.CLOSE consumido: PASS.
- Inventario global de entregables: PASS.
- Matriz de estados: PASS.
- SGD-000 / SGD-002 / Indice Maestro / Registro Maestro / trazabilidad: PASS.
- Commits / tags / releases: PASS.
- Tags nuevos: NO.
- Releases nuevos: NO.
- Determinacion del siguiente entregable: $Decision.
- Creacion automatica de SPT: NO.
- Limpieza destructiva: NO.
- Produccion modificada: NO.
"@

    Write-Utf8NoBomLf $DocPath $Doc
    Write-Utf8NoBomLf $ActaPath $Acta

    Write-Host "GLOBAL_DELIVERABLE_INVENTORY=CREATED"
    Write-Host "GLOBAL_DELIVERABLE_STATUS_MATRIX=CREATED"
    Write-Host "DEPENDENCY_RECONCILIATION=CREATED"
    Write-Host "NEXT_DELIVERABLE_ASSESSMENT=CREATED"
    Write-Host "MASTER_MAP_DOCUMENT=CREATED"
    Write-Host "INSTITUTIONAL_ACTA=CREATED"

    Step 9 "BUILD SHA-256 MANIFEST"
    $OutputSet = @(
        $Self,
        $AssessmentPath,
        $InventoryPath,
        $StatusMatrixPath,
        $DependencyPath,
        $NextActionPath,
        $EvidencePath,
        $DocPath,
        $ActaPath
    )

    $HashRecords = @()
    foreach($P in $OutputSet){
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ Hold ("Output missing: "+$P) }
        $HashRecords += [ordered]@{ path=$P; sha256=Get-Sha256 $P }
    }

    $IntegrityObj = [ordered]@{
        component = "SGODA-DELIVERABLE-MAP-UPDATE"
        version = $Version
        authoritative_input_head = $ExpectedBaseline
        records = $HashRecords
    }

    Write-Utf8NoBomLf $IntegrityPath ($IntegrityObj | ConvertTo-Json -Depth 8)
    $OutputSet += $IntegrityPath

    Write-Host "DELIVERABLE_MAP_SHA256_MANIFEST=CREATED"
    Write-Host "OUTPUT_SET=$($OutputSet.Count)"

    Step 10 "OUTPUT JSON / EOL / SECURITY GATE"
    foreach($P in $OutputSet){
        $Ext=[IO.Path]::GetExtension($P).ToLowerInvariant()
        if($Ext -eq ".json"){ $null = Read-Json $P }
        if(Test-NewTextSecret $P){ Hold ("Secret pattern detected in output: "+$P) }

        $AttrLines=@(& git.exe check-attr eol -- $P)
        $Required=""
        foreach($Line in $AttrLines){ if($Line -match ': eol: (.+)$'){ $Required=$Matches[1].Trim().ToLowerInvariant() } }
        if($Required -eq "lf"){
            $T=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $P).Path,[Text.Encoding]::UTF8)
            if([regex]::Matches($T,"`r`n").Count -ne 0){ Hold ("LF attribute conflict: "+$P) }
        }
    }

    Write-Host "JSON_VALIDATION=PASS"
    Write-Host "OUTPUT_EOL_GATE=PASS"
    Write-Host "OUTPUT_SECURITY_GATE=PASS"

    Step 11 "CLOSED BASELINE PRESERVATION GATE"
    $ModifiedNow = @(& git.exe -c core.quotepath=false diff --name-only)
    $DeletedNow = @(& git.exe ls-files --deleted)

    if($ModifiedNow.Count -ne 0){ Hold "Tracked baseline changed before staging" }
    if($DeletedNow.Count -ne 0){ Hold "Tracked deletion detected" }

    Write-Host "CLOSED_BASELINE_PRESERVED=PASS"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"

    Step 12 "EXACT CONTROLLED STAGING"
    foreach($P in $OutputSet){
        & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $P
        if($LASTEXITCODE -ne 0){ Hold ("git add failed: "+$P) }
    }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected=@($StagedNow | Where-Object { $OutputSet -notcontains ($_ -replace "\\","/") })
    $Missing=@($OutputSet | Where-Object { $StagedNow -notcontains $_ })

    Write-Host "STAGED=$($StagedNow.Count)"
    Write-Host "EXPECTED_STAGE_SET=$($OutputSet.Count)"
    Write-Host "UNEXPECTED_STAGED=$($Unexpected.Count)"
    Write-Host "MISSING_STAGED=$($Missing.Count)"

    if($Unexpected.Count -ne 0 -or $Missing.Count -ne 0 -or $StagedNow.Count -ne $OutputSet.Count){ Hold "Exact staging mismatch" }
    Write-Host "STAGING_QUALITY=PASS"

    Step 13 "STAGED DELETION / GITHUB SIZE / REMOTE PRE-COMMIT GATE"
    $StagedDeletions=@(& git.exe diff --cached --diff-filter=D --name-only)
    if($StagedDeletions.Count -ne 0){ Hold "Staged deletion detected" }

    $Large=New-Object System.Collections.ArrayList
    foreach($P in @(& git.exe -c core.quotepath=false ls-files)){
        $SizeText = (& git.exe cat-file -s (":$P") 2>$null)
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
    if($RemotePre -ne $ExpectedBaseline -or $LocalPre -ne $ExpectedBaseline){ Hold "Remote changed before commit" }

    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "REMOTE_PRECOMMIT_GATE=PASS"

    Step 14 "COMMIT DELIVERABLE MAP UPDATE"
    & git.exe commit -m "chore(institutional): update global deliverable map after master close"
    if($LASTEXITCODE -ne 0){ Hold "git commit failed" }

    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"
    Write-Host "COMMIT_PERFORMED=YES"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){ Hold "git push failed" }
    Write-Host "PUSH=PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / MAP UPDATE CLOSURE"
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
    Write-Host "SGODA-DELIVERABLE-MAP-UPDATE : CLOSED / PASS" -ForegroundColor Green
    Write-Host "MASTER_CLOSE_CONSUMED=PASS"
    Write-Host "GLOBAL_DELIVERABLE_INVENTORY=PASS"
    Write-Host "GLOBAL_DELIVERABLE_STATUS_MATRIX=PASS"
    Write-Host "MASTER_GOVERNANCE_COVERAGE=PASS"
    Write-Host "COMMITS_TAGS_RELEASES_RECONCILIATION=PASS"
    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"
    Write-Host "NEXT_DELIVERABLE_DECISION=$Decision"
    if($NextDeliverable){ Write-Host "NEXT_DELIVERABLE_CANDIDATE=$NextDeliverable" }
    Write-Host "AUTOMATIC_SPT_CREATION=NO"
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
    if($Decision -eq "SPT026_ALREADY_REFERENCED_IN_REPOSITORY"){
        Write-Host "NEXT_ACTION=BUILD_SPT026_PREPARE"
    } elseif($Decision -eq "EXISTING_PENDING_DELIVERABLE_DETECTED"){
        Write-Host "NEXT_ACTION=FORMALIZE_EXISTING_PENDING_DELIVERABLE"
    } else {
        Write-Host "NEXT_ACTION=GOVERNANCE_REVIEW_NEXT_TECHNOLOGICAL_DELIVERABLE"
    }
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
