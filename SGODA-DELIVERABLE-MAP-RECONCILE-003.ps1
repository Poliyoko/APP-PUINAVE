#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "b66e8d4b68c78f9ac6d72f3f7a82b4cdef88ef66"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.3"
$Self = "SGODA-DELIVERABLE-MAP-RECONCILE-003.ps1"

$PreviousMapDir = "artifacts/development/SGODA-DELIVERABLE-MAP-RECONCILE-002-v1.0.2"
$PreviousInventory = "$PreviousMapDir/global-deliverable-inventory-reconciled.json"
$PreviousStatus = "$PreviousMapDir/global-deliverable-status-matrix-reconciled.json"
$PreviousNext = "$PreviousMapDir/next-technological-deliverable-assessment-reconciled.json"
$PreviousAssessment = "$PreviousMapDir/spt002-map-reconciliation-assessment.json"
$PreviousMapDoc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Mapa-Global-Entregables-v1.0.2.md"

$PrepareScript = "SGODA-SPT003-FORMALIZE-PREPARE.ps1"
$PrepareDir = "artifacts/development/SPT-003-FORMALIZE-PREPARE-v1.0.0"
$PrepareAssessment = "$PrepareDir/spt003-real-state-assessment.json"
$PrepareCoverage = "$PrepareDir/spt003-coverage-matrix.json"
$PrepareEvidence = "$PrepareDir/spt003-evidence-inventory.json"
$PrepareGit = "$PrepareDir/spt003-commits-tags-releases.json"
$PrepareDependency = "$PrepareDir/spt003-dependency-sequence-audit.json"
$PrepareContract = "$PrepareDir/spt003-formalization-prepare.json"
$PrepareIntegrity = "$PrepareDir/spt003-prepare-sha256-manifest.json"
$PrepareImplementationEvidence = "$PrepareDir/implementation-evidence.json"
$PrepareDoc = "docs/06_Tecnologia/SPT-003/SGD-SPT003-FORMALIZE-PREPARE-Auditoria-Estado-Real.md"

$Dev = "artifacts/development/SGODA-DELIVERABLE-MAP-RECONCILE-003-v1.0.3"
$ReconciledInventory = "$Dev/global-deliverable-inventory-reconciled.json"
$ReconciledStatus = "$Dev/global-deliverable-status-matrix-reconciled.json"
$ReconciledNext = "$Dev/next-technological-deliverable-assessment-reconciled.json"
$ReconciliationAssessment = "$Dev/spt003-map-reconciliation-assessment.json"
$ReconciliationLedger = "$Dev/deliverable-map-reconciliation-ledger.json"
$ImplementationEvidence = "$Dev/implementation-evidence.json"
$IntegrityManifest = "$Dev/reconciliation-sha256-manifest.json"

$MapDoc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Mapa-Global-Entregables-v1.0.3.md"
$Acta = "docs/00_Estado_Maestro/ACT-SGODA-DELIVERABLE-MAP-RECONCILE-003-v1.0.3.md"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA-DELIVERABLE-MAP-RECONCILE-003 : HOLD" -ForegroundColor Red
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

function Get-SptSortKey {
    param([string]$Id)
    if($Id -match '^SPT-(\d+)(?:\.(\d+))?'){
        $Major=[int]$Matches[1]
        $Minor=0
        if($Matches[2]){ $Minor=[int]$Matches[2] }
        return ("{0:D5}.{1:D5}" -f $Major,$Minor)
    }
    return "99999.99999"
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

    Step 2 "CONSUME SPT-003 FORMALIZE PREPARE"
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
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ Hold ("SPT-003 PREPARE output missing: "+$P) }
    }

    $PrepareState = Read-Json $PrepareAssessment
    $PrepareSpec = Read-Json $PrepareContract

    if([string]$PrepareState.real_state -ne "ALREADY_CLOSED"){ Hold "SPT-003 PREPARE does not certify ALREADY_CLOSED" }
    if([string]$PrepareState.recommended_action -ne "RECONCILE_MASTER_MAP_WITHOUT_REOPENING"){ Hold "Unexpected SPT-003 PREPARE action" }

    Write-Host "SPT003_PREPARE=PASS"
    Write-Host "SPT003_REAL_STATE=ALREADY_CLOSED"
    Write-Host "SPT003_RECOMMENDED_ACTION=RECONCILE_MASTER_MAP_WITHOUT_REOPENING"

    Step 3 "CONSUME PREVIOUS RECONCILED GLOBAL MAP"
    foreach($P in @($PreviousInventory,$PreviousStatus,$PreviousNext,$PreviousAssessment,$PreviousMapDoc)){
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ Hold ("Previous map input missing: "+$P) }
    }

    $Inventory = Read-Json $PreviousInventory
    $Status = Read-Json $PreviousStatus
    $Next = Read-Json $PreviousNext

    if([string]$Next.next_deliverable_candidate -ne "SPT-003"){
        Hold "Previous reconciled map does not identify SPT-003 as current candidate"
    }

    Write-Host "PREVIOUS_DELIVERABLE_COUNT=$([int]$Inventory.deliverable_count)"
    Write-Host "PREVIOUS_PENDING_SPT_CANDIDATES=$(@($Status.pending_spt_candidates).Count)"
    Write-Host "PREVIOUS_NEXT_CANDIDATE=SPT-003"
    Write-Host "PREVIOUS_MAP_CONSUMED=PASS"

    Step 4 "RECLASSIFY SPT-003 AS CLOSED WITHOUT REOPENING"
    $Rows = @($Inventory.deliverables)
    $Target = @($Rows | Where-Object { [string]$_.deliverable -eq "SPT-003" })
    if($Target.Count -ne 1){ Hold ("Expected exactly one SPT-003 row, found "+$Target.Count) }

    $PreviousTargetStatus = [string]$Target[0].status

    $ReconciledRows = @()
    foreach($Row in $Rows){
        $Id=[string]$Row.deliverable
        if($Id -eq "SPT-003"){
            $ReconciledRows += [ordered]@{
                deliverable = "SPT-003"
                status = "CLOSED"
                reason = "Recertified by SPT-003.FORMALIZE.PREPARE as ALREADY_CLOSED; map corrected without reopening."
                tracked_paths = @($Row.tracked_paths)
                path_count = [int]$Row.path_count
                reconciliation_source = $PrepareAssessment
                reopened = $false
            }
        } else {
            $Item=[ordered]@{
                deliverable = $Id
                status = [string]$Row.status
                reason = [string]$Row.reason
                tracked_paths = @($Row.tracked_paths)
                path_count = [int]$Row.path_count
            }
            if($Row.PSObject.Properties.Name -contains "reconciliation_source"){
                $Item["reconciliation_source"]=[string]$Row.reconciliation_source
            }
            if($Row.PSObject.Properties.Name -contains "reopened"){
                $Item["reopened"]=[bool]$Row.reopened
            }
            $ReconciledRows += $Item
        }
    }

    Write-Host "SPT003_PREVIOUS_CLASSIFICATION=$PreviousTargetStatus"
    Write-Host "SPT003_CLASSIFICATION=CLOSED"
    Write-Host "SPT003_REOPENED=NO"
    Write-Host "RECLASSIFICATION_GATE=PASS"

    Step 5 "RECALCULATE GLOBAL STATUS MATRIX"
    $Closed = @($ReconciledRows | Where-Object { [string]$_.status -match '^CLOSED' })
    $Implemented = @($ReconciledRows | Where-Object { [string]$_.status -eq "IMPLEMENTED_OR_DOCUMENTED" })

    $PendingSpt = @(
        $ReconciledRows |
        Where-Object {
            [string]$_.deliverable -match '^SPT-\d+' -and
            [string]$_.status -eq "IMPLEMENTED_OR_DOCUMENTED"
        } |
        ForEach-Object {
            [pscustomobject]@{
                id=[string]$_.deliverable
                key=(Get-SptSortKey ([string]$_.deliverable))
            }
        } |
        Sort-Object key,id
    )

    $PendingIds = @($PendingSpt | ForEach-Object { $_.id })
    if($PendingIds -contains "SPT-003"){ Hold "SPT-003 remains pending after reconciliation" }

    Write-Host "RECONCILED_CLOSED_OR_FORMALIZED=$($Closed.Count)"
    Write-Host "RECONCILED_IMPLEMENTED_OR_DOCUMENTED=$($Implemented.Count)"
    Write-Host "PENDING_SPT_CANDIDATES_RECALCULATED=$($PendingIds.Count)"
    Write-Host "SPT003_PENDING_AFTER_RECONCILIATION=NO"
    Write-Host "STATUS_RECALCULATION=PASS"

    Step 6 "DETERMINE NEXT REAL PENDING DELIVERABLE"
    $NextCandidate = $null
    $Decision = "NO_AUTHORIZED_NEXT_SPT_INFERRED"
    $NextAction = "GOVERNANCE_REVIEW_NEXT_TECHNOLOGICAL_DELIVERABLE"

    if($PendingIds.Count -gt 0){
        $NextCandidate = $PendingIds[0]
        $Decision = "EXISTING_PENDING_DELIVERABLE_DETECTED"
        $NextAction = "AUDIT_NEXT_PENDING_DELIVERABLE"
    }

    Write-Host "NEXT_DELIVERABLE_DECISION=$Decision"
    if($NextCandidate){ Write-Host "NEXT_DELIVERABLE_CANDIDATE=$NextCandidate" }
    Write-Host "NEXT_ACTION=$NextAction"
    Write-Host "AUTOMATIC_SPT_CREATION=NO"

    Step 7 "RECONCILE COMMITS / TAGS / RELEASES"
    $RecentCommits = @(& git.exe --no-pager log --format="%H|%s" -50)
    $Tags = @(& git.exe tag --list)
    $Tags003 = @($Tags | Where-Object { $_ -match '(?i)SPT[-_.]?003|SPT003' })
    $Tracked = @(& git.exe -c core.quotepath=false ls-files)
    $Release003 = @($Tracked | Where-Object { $_ -match '(?i)^releases/.*SPT[-_.]?003|^releases/.*SPT003' })

    Write-Host "RECENT_COMMITS=$($RecentCommits.Count)"
    Write-Host "SPT003_TAGS=$($Tags003.Count)"
    Write-Host "SPT003_RELEASE_PATHS=$($Release003.Count)"
    Write-Host "TAG_CREATED=NO"
    Write-Host "RELEASE_CREATED=NO"
    Write-Host "COMMITS_TAGS_RELEASES_RECONCILIATION=PASS"

    Step 8 "WRITE RECONCILED MAP / LEDGER / EVIDENCE"
    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

    $InventoryObj=[ordered]@{
        component="SGODA-DELIVERABLE-MAP-RECONCILE-003"
        version=$Version
        authoritative_input_head=$ExpectedBaseline
        generated_at=$Now
        deliverable_count=$ReconciledRows.Count
        reconciliation=[ordered]@{
            deliverable="SPT-003"
            previous_status=$PreviousTargetStatus
            reconciled_status="CLOSED"
            real_state="ALREADY_CLOSED"
            reopened=$false
            source=$PrepareAssessment
        }
        deliverables=$ReconciledRows
    }

    $StatusObj=[ordered]@{
        component="SGODA-DELIVERABLE-MAP-RECONCILE-003"
        authoritative_input_head=$ExpectedBaseline
        closed_or_formalized=@($Closed | ForEach-Object { $_.deliverable })
        implemented_or_documented=@($Implemented | ForEach-Object { $_.deliverable })
        pending_spt_candidates=$PendingIds
        spt003_classification="CLOSED"
        spt003_reopened=$false
        classification_policy="Repository evidence plus explicit SPT-003 PREPARE recertification."
    }

    $NextObj=[ordered]@{
        component="SGODA-DELIVERABLE-MAP-RECONCILE-003"
        authoritative_input_head=$ExpectedBaseline
        decision=$Decision
        next_deliverable_candidate=$NextCandidate
        next_action=$NextAction
        pending_spt_candidates=$PendingIds
        automatic_spt_creation=$false
        spt003_removed_from_pending=$true
    }

    $AssessmentObj=[ordered]@{
        component="SGODA-DELIVERABLE-MAP-RECONCILE-003"
        version=$Version
        authoritative_input_head=$ExpectedBaseline
        status="READY_FOR_PUBLICATION"
        spt003_real_state="ALREADY_CLOSED"
        spt003_previous_map_status=$PreviousTargetStatus
        spt003_reconciled_status="CLOSED"
        spt003_reopened=$false
        master_map_reconciliation="PASS"
        pending_deliverables_recalculated=$true
        next_deliverable_candidate=$NextCandidate
        next_action=$NextAction
        destructive_cleanup=$false
        new_functionality=$false
        production_change=$false
    }

    $LedgerObj=[ordered]@{
        component="SGODA-DELIVERABLE-MAP-RECONCILE-003"
        version=$Version
        baseline=$ExpectedBaseline
        spt003_prepare_inputs=$PrepareFiles
        previous_map_inputs=@($PreviousInventory,$PreviousStatus,$PreviousNext,$PreviousAssessment,$PreviousMapDoc)
        correction=[ordered]@{
            deliverable="SPT-003"
            from=$PreviousTargetStatus
            to="CLOSED"
            reopen=$false
            justification="SPT-003 certified ALREADY_CLOSED by formalization PREPARE."
        }
        next_candidate=$NextCandidate
        tag_created=$false
        release_created=$false
    }

    $EvidenceObj=[ordered]@{
        component="SGODA-DELIVERABLE-MAP-RECONCILE-003"
        authoritative_input_head=$ExpectedBaseline
        spt003_prepare_consumed=$true
        spt003_reopened=$false
        pending_before=@($Status.pending_spt_candidates).Count
        pending_after=$PendingIds.Count
        next_candidate=$NextCandidate
        destructive_cleanup=$false
        production_change=$false
    }

    Write-Utf8NoBomLf $ReconciledInventory ($InventoryObj | ConvertTo-Json -Depth 24)
    Write-Utf8NoBomLf $ReconciledStatus ($StatusObj | ConvertTo-Json -Depth 16)
    Write-Utf8NoBomLf $ReconciledNext ($NextObj | ConvertTo-Json -Depth 16)
    Write-Utf8NoBomLf $ReconciliationAssessment ($AssessmentObj | ConvertTo-Json -Depth 16)
    Write-Utf8NoBomLf $ReconciliationLedger ($LedgerObj | ConvertTo-Json -Depth 16)
    Write-Utf8NoBomLf $ImplementationEvidence ($EvidenceObj | ConvertTo-Json -Depth 16)

    $MapDocText=@"
# SGODA-PUINAVE - Mapa Global de Entregables v1.0.3

Linea base: $ExpectedBaseline

## Reconciliacion SPT-003

- Estado real certificado: ALREADY_CLOSED.
- Clasificacion anterior del mapa: $PreviousTargetStatus.
- Clasificacion reconciliada: CLOSED.
- Reapertura de SPT-003: NO.
- PREPARE consumido: $PrepareAssessment.
- Candidatos pendientes recalculados: $($PendingIds.Count).
- Siguiente candidato real: $NextCandidate.
- Decision: $Decision.
- Accion siguiente: $NextAction.

## Politica

SPT-003 no se reabre. La correccion modifica exclusivamente la clasificacion institucional del mapa y publica la evidencia PREPARE que demuestra su estado real.
"@

    $ActaText=@"
# ACT-SGODA-DELIVERABLE-MAP-RECONCILE-003-v1.0.3

Se certifica la reconciliacion del Mapa Global de Entregables para SPT-003.

- Baseline de entrada: $ExpectedBaseline
- SPT-003 real state: ALREADY_CLOSED
- SPT-003 map classification: CLOSED
- SPT-003 reopened: NO
- Pending deliverables recalculated: YES
- Pending SPT candidates: $($PendingIds.Count)
- Next deliverable candidate: $NextCandidate
- Automatic SPT creation: NO
- Tag created: NO
- Release created: NO
- Destructive cleanup: NO
- Production change: NO
"@

    Write-Utf8NoBomLf $MapDoc $MapDocText
    Write-Utf8NoBomLf $Acta $ActaText

    Write-Host "RECONCILED_INVENTORY=CREATED"
    Write-Host "RECONCILED_STATUS_MATRIX=CREATED"
    Write-Host "RECONCILED_NEXT_ASSESSMENT=CREATED"
    Write-Host "RECONCILIATION_LEDGER=CREATED"
    Write-Host "RECONCILIATION_EVIDENCE=CREATED"
    Write-Host "MAP_DOCUMENT_V1.0.3=CREATED"
    Write-Host "INSTITUTIONAL_ACTA=CREATED"

    Step 9 "BUILD EXACT PUBLICATION SET / SHA-256 MANIFEST"
    $OutputSet=@(
        $Self,
        $ReconciledInventory,
        $ReconciledStatus,
        $ReconciledNext,
        $ReconciliationAssessment,
        $ReconciliationLedger,
        $ImplementationEvidence,
        $MapDoc,
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
        component="SGODA-DELIVERABLE-MAP-RECONCILE-003"
        version=$Version
        baseline=$ExpectedBaseline
        records=$Records
    }

    Write-Utf8NoBomLf $IntegrityManifest ($ManifestObj | ConvertTo-Json -Depth 12)
    $OutputSet += $IntegrityManifest

    Write-Host "EXACT_PUBLICATION_SET=$($OutputSet.Count)"
    Write-Host "SPT003_PREPARE_OUTPUTS_INCLUDED=$($PrepareFiles.Count)"
    Write-Host "SHA256_MANIFEST=CREATED"

    Step 10 "JSON / EOL / SECURITY QUALITY GATE"
    foreach($P in $OutputSet){
        $Ext=[IO.Path]::GetExtension($P).ToLowerInvariant()
        if($Ext -eq ".json"){ $null=Read-Json $P }
        if(Test-NewTextSecret $P){ Hold ("Secret pattern detected in publication output: "+$P) }

        $Attr=@(& git.exe check-attr eol -- $P)
        $Required=""
        foreach($Line in $Attr){
            if($Line -match ': eol: (.+)$'){ $Required=$Matches[1].Trim().ToLowerInvariant() }
        }

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

    Step 11 "CLOSED BASELINE PRESERVATION / UNTRACKED ACCOUNTING"
    $ModifiedNow=@(& git.exe -c core.quotepath=false diff --name-only)
    $DeletedNow=@(& git.exe ls-files --deleted)

    if($ModifiedNow.Count -ne 0){ Hold "Tracked baseline changed before staging" }
    if($DeletedNow.Count -ne 0){ Hold "Tracked deletion detected" }

    $CurrentUntracked=@(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
    $UnexpectedUntracked=@($CurrentUntracked | Where-Object {
        $P=($_ -replace "\\","/")
        $OutputSet -notcontains $P
    })

    $BlockingUnexpected=@($UnexpectedUntracked | Where-Object {
        $_ -match '(?i)SPT[-_.]?003|SPT003|DELIVERABLE-MAP-RECONCILE-003'
    })

    Write-Host "CURRENT_UNTRACKED=$($CurrentUntracked.Count)"
    Write-Host "EXPECTED_PUBLICATION_UNTRACKED=$($OutputSet.Count)"
    Write-Host "UNEXPECTED_UNTRACKED=$($UnexpectedUntracked.Count)"
    Write-Host "BLOCKING_SPT003_UNTRACKED=$($BlockingUnexpected.Count)"

    if($BlockingUnexpected.Count -ne 0){
        $BlockingUnexpected | ForEach-Object { Write-Host ("BLOCKING_UNTRACKED="+$_) }
        Hold "Unexpected active SPT-003 or reconciliation content outside publication set"
    }

    Write-Host "CLOSED_BASELINE_PRESERVED=PASS"
    Write-Host "SPT003_UNTRACKED_ACCOUNTING=PASS"

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
        Hold "Remote changed before reconciliation commit"
    }

    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "REMOTE_PRECOMMIT_GATE=PASS"

    Step 14 "COMMIT MAP RECONCILIATION"
    & git.exe commit -m "chore(institutional): reconcile SPT-003 as already closed"
    if($LASTEXITCODE -ne 0){ Hold "git commit failed" }

    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"
    Write-Host "COMMIT_PERFORMED=YES"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){ Hold "git push failed" }
    Write-Host "PUSH=PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / RECONCILIATION CLOSURE"
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
    Write-Host "SGODA-DELIVERABLE-MAP-RECONCILE-003 : CLOSED / PASS" -ForegroundColor Green
    Write-Host "SPT003_REAL_STATE=ALREADY_CLOSED"
    Write-Host "SPT003_CLASSIFICATION=CLOSED"
    Write-Host "SPT003_REOPENED=NO"
    Write-Host "MASTER_MAP_RECONCILIATION=PASS"
    Write-Host "PENDING_DELIVERABLES_RECALCULATED=YES"
    Write-Host "PENDING_SPT_CANDIDATES=$($PendingIds.Count)"
    Write-Host "NEXT_DELIVERABLE_DECISION=$Decision"
    if($NextCandidate){ Write-Host "NEXT_DELIVERABLE_CANDIDATE=$NextCandidate" }
    Write-Host "AUTOMATIC_SPT_CREATION=NO"
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
    Write-Host "NEXT_ACTION=$NextAction"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
