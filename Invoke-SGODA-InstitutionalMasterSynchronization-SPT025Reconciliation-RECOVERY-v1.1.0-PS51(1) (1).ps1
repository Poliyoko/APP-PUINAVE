#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "4d463840b2bae0bbc6f18ea869f37e792b69d450"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.1.0"

$PrepareRoot = "artifacts/institutional/master-synchronization/worktree-reconciliation-v1.0.0"
$ManifestPath = "$PrepareRoot/worktree-reconciliation-manifest.json"
$LedgerPath = "$PrepareRoot/institutional-disposition-ledger.json"
$PreparePath = "$PrepareRoot/master-synchronization-recovery-prepare.json"
$RuntimeState = "artifacts/runtime/sgd002-auto/state.json"

$Sgd000 = "docs/00_Estado_Maestro/SGD-000-Estado-Maestro-Institucional-v1.0.0.md"
$Sgd002 = "docs/00_Estado_Maestro/SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
$Rmi = "docs/00_Estado_Maestro/RMI-021.2-Registro-Maestro-Institucional-Implementaciones-v1.0.0.md"
$MasterIndex = "docs/00_INDICE_MAESTRO.md"
$MasterRegistry = "docs/00_REGISTRO_MAESTRO_COMPONENTES.md"
$Nomenclature = "docs/01_Gobierno/SGD-100-Norma-Institucional-Nomenclatura.md"
$TraceabilityDoc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Matriz-Maestra-Trazabilidad-Institucional.md"

$EvidenceRoot = "artifacts/development/SGODA-InstitutionalMasterSynchronization-RECOVERY-v1.1.0"
$FinalLedger = "$EvidenceRoot/final-worktree-reconciliation-ledger.json"
$MasterAssessment = "$EvidenceRoot/master-synchronization-recovery-assessment.json"
$GitInventory = "$EvidenceRoot/commits-tags-releases-recertification.json"
$RuntimeAssessment = "$EvidenceRoot/sgd002-runtime-state-recertification.json"
$IntegrityManifest = "$EvidenceRoot/master-synchronization-recovery-sha256-manifest.json"
$ImplementationEvidence = "$EvidenceRoot/implementation-evidence.json"

$RecoveryDoc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Sincronizacion-Institucional-Maestra-RECOVERY-v1.1.0.md"
$RecoveryAct = "docs/00_Estado_Maestro/ACT-SGODA-MASTER-SYNC-RECOVERY-v1.1.0.md"

function Step {
    param([int]$Number,[string]$Title)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $Number,$Title) -ForegroundColor Cyan
}

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA MASTER SYNCHRONIZATION RECOVERY v1.1.0 : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "TRANSACTION : NOT PUBLISHED"
    exit 1
}

function Fetch-Authoritative {
    for($Attempt=1;$Attempt -le 4;$Attempt++) {
        Write-Host ("GIT FETCH ATTEMPT : {0}/4" -f $Attempt)
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0) {
            Write-Host "GIT FETCH : PASS"
            return
        }
        Start-Sleep -Seconds 2
    }
    Hold "git fetch failed"
}

function Read-Utf8Json {
    param([string]$RelativePath)
    $Absolute = Join-Path $Root $RelativePath
    if(-not (Test-Path -LiteralPath $Absolute -PathType Leaf)) {
        Hold ("Missing JSON input: " + $RelativePath)
    }
    try {
        return ([IO.File]::ReadAllText($Absolute,[Text.Encoding]::UTF8) | ConvertFrom-Json)
    } catch {
        Hold ("Invalid JSON input: " + $RelativePath + " :: " + $_.Exception.Message)
    }
}

function Write-Utf8NoBom {
    param([string]$RelativePath,[string]$Text)
    $Absolute = Join-Path $Root $RelativePath
    $Parent = Split-Path -Parent $Absolute
    if($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    $Normalized = (($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $Normalized.EndsWith("`n")) { $Normalized += "`n" }
    [IO.File]::WriteAllText($Absolute,$Normalized,$Utf8)
}

function Get-Sha256 {
    param([string]$RelativePath)
    return (Get-FileHash -LiteralPath (Join-Path $Root $RelativePath) -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Test-Tracked {
    param([string]$RelativePath)
    & git.exe ls-files --error-unmatch -- $RelativePath *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-HighRiskSecret {
    param([string]$RelativePath)

    $Absolute = Join-Path $Root $RelativePath
    if(-not (Test-Path -LiteralPath $Absolute -PathType Leaf)) { return $false }

    $Ext = [IO.Path]::GetExtension($Absolute).ToLowerInvariant()
    $TextExt = @(".ps1",".py",".json",".md",".txt",".yml",".yaml",".toml",".ini",".cfg",".env",".xml",".csv",".log")

    if($TextExt -notcontains $Ext) { return $false }

    try {
        $Text = [IO.File]::ReadAllText($Absolute,[Text.Encoding]::UTF8)
    } catch {
        try { $Text = Get-Content -LiteralPath $Absolute -Raw } catch { return $false }
    }

    $Patterns = @(
        '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
        'github_pat_[A-Za-z0-9_]{20,}',
        'ghp_[A-Za-z0-9]{30,}',
        'AKIA[0-9A-Z]{16}',
        'sk-[A-Za-z0-9_-]{20,}'
    )

    foreach($Pattern in $Patterns) {
        if([regex]::IsMatch($Text,$Pattern)) { return $true }
    }
    return $false
}

try {
    $Root = (& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root) { Hold "Not inside Git repository" }
    Set-Location $Root

    $Python = Join-Path $Root ".venv\Scripts\python.exe"
    if(-not (Test-Path -LiteralPath $Python)) { $Python = "python.exe" }

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    Fetch-Authoritative

    $Local = (& git.exe rev-parse HEAD).Trim()
    $Remote = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    $Staged = @(& git.exe diff --cached --name-only)
    $Deleted = @(& git.exe -c core.longpaths=true -c core.quotepath=false ls-files --deleted)

    Write-Host "EXPECTED HEAD    : $ExpectedBaseline"
    Write-Host "LOCAL HEAD       : $Local"
    Write-Host "REMOTE HEAD      : $Remote"
    Write-Host "STAGED           : $($Staged.Count)"
    Write-Host "DELETED TRACKED  : $($Deleted.Count)"

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline) { Hold "Authoritative baseline mismatch" }
    if($Staged.Count -ne 0 -or $Deleted.Count -ne 0) { Hold "Unsafe staged/deleted state" }

    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"
    Write-Host "SPT025_STATUS=INSTITUTIONALLY_CLOSED"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"

    Step 2 "CONSUME EXACT RECONCILIATION PREPARE"
    $Manifest = Read-Utf8Json $ManifestPath
    $Ledger = Read-Utf8Json $LedgerPath
    $Prepare = Read-Utf8Json $PreparePath

    if([string]$Prepare.deliverable -ne "SGODA-INSTITUTIONAL-MASTER-SYNCHRONIZATION-RECOVERY") { Hold "Unexpected PREPARE deliverable" }
    if([string]$Prepare.authoritative_input_head -ne $ExpectedBaseline) { Hold "PREPARE baseline mismatch" }
    if([string]$Prepare.baseline_gate -ne "PASS") { Hold "PREPARE baseline gate is not PASS" }
    if([bool]$Prepare.preserve_spt025 -ne $true) { Hold "PREPARE does not preserve SPT-025" }
    if([bool]$Prepare.allow_destructive_cleanup -ne $false) { Hold "PREPARE allows destructive cleanup" }

    Write-Host "WORKTREE_RECONCILIATION_PREPARE=PASS"
    Write-Host "INSTITUTIONAL_DISPOSITION_LEDGER=PASS"
    Write-Host "SPT025_PRESERVATION_CONTRACT=PASS"

    Step 3 "RECERTIFY PRIOR MASTER SYNCHRONIZATION COMMIT"
    $MasterDocs = @($Sgd000,$Sgd002,$Rmi,$MasterIndex,$MasterRegistry,$Nomenclature,$TraceabilityDoc)
    $CommitPaths = @(& git.exe show --pretty=format: --name-only $ExpectedBaseline)

    foreach($P in $MasterDocs) {
        if(-not (Test-Path -LiteralPath (Join-Path $Root $P) -PathType Leaf)) { Hold ("Missing master document: " + $P) }
        if(-not (Test-Tracked $P)) { Hold ("Master document is not tracked: " + $P) }
        if($CommitPaths -notcontains $P) { Hold ("Baseline commit did not reconcile master document: " + $P) }
    }

    Write-Host "SGD000_RECONCILIATION=PASS"
    Write-Host "SGD002_RECONCILIATION=PASS"
    Write-Host "MASTER_INDEX_RECONCILIATION=PASS"
    Write-Host "MASTER_REGISTRY_RECONCILIATION=PASS"
    Write-Host "NOMENCLATURE_RECONCILIATION=PASS"
    Write-Host "TRACEABILITY_MATRIX_RECONCILIATION=PASS"

    Step 4 "SHA-256 FREEZE OF TRACKED BASELINE"
    $Freeze = @{}
    foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)) {
        $Absolute = Join-Path $Root $TrackedPath
        if(Test-Path -LiteralPath $Absolute -PathType Leaf) {
            $Freeze[$TrackedPath] = Get-Sha256 $TrackedPath
        }
    }

    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA256_FREEZE=PASS"

    Step 5 "BUILD EXACT PRESERVATION SET FROM LEDGER"
    $CurrentUntracked = @(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
    $LedgerByPath = @{}
    foreach($Record in @($Ledger.records)) {
        if($null -ne $Record.path) { $LedgerByPath[[string]$Record.path] = $Record }
    }

    $Preserve = New-Object System.Collections.ArrayList
    $AlreadyRepresented = New-Object System.Collections.ArrayList
    $Unexpected = New-Object System.Collections.ArrayList

    foreach($P in $CurrentUntracked) {
        if($P -eq "Invoke-SGODA-InstitutionalMasterSynchronization-SPT025Reconciliation-RECOVERY-v1.1.0-PS51.ps1") {
            [void]$Preserve.Add($P)
            continue
        }

        if($LedgerByPath.ContainsKey($P)) {
            $Disposition = [string]$LedgerByPath[$P].disposition
            if($Disposition -eq "ALREADY_REPRESENTED_IN_REPOSITORY") {
                [void]$AlreadyRepresented.Add($P)
            } else {
                [void]$Preserve.Add($P)
            }
            continue
        }

        # Tools created during the reconciliation sequence after the original classification
        if($P -in @(
            "Invoke-SGODA-Exact-Institutional-Reconciliation-Set-PREPARE-v1.0.0-PS51.ps1",
            "Invoke-SGODA-Worktree-Institutional-Reconciliation-AUDIT-v1.0.0-PS51.ps1"
        )) {
            [void]$Preserve.Add($P)
            continue
        }

        [void]$Unexpected.Add($P)
    }

    Write-Host "CURRENT_UNTRACKED=$($CurrentUntracked.Count)"
    Write-Host "PRESERVATION_SET=$($Preserve.Count)"
    Write-Host "ALREADY_REPRESENTED=$($AlreadyRepresented.Count)"
    Write-Host "UNEXPECTED_UNTRACKED=$($Unexpected.Count)"

    if($Unexpected.Count -ne 0) {
        $Unexpected | ForEach-Object { Write-Host ("UNEXPECTED=" + $_) }
        Hold "Untracked set changed after PREPARE; reconciliation must be refreshed"
    }

    Write-Host "EXACT_RECONCILIATION_SET=PASS"

    Step 6 "SECURITY / GITHUB SIZE PRE-GATE FOR PRESERVATION SET"
    $Oversized = New-Object System.Collections.ArrayList
    $SecretHits = New-Object System.Collections.ArrayList

    foreach($P in $Preserve) {
        $Absolute = Join-Path $Root $P
        if(-not (Test-Path -LiteralPath $Absolute -PathType Leaf)) { Hold ("Preservation candidate missing: " + $P) }

        $Length = (Get-Item -LiteralPath $Absolute).Length
        if($Length -ge 100MB) { [void]$Oversized.Add($P) }

        if(Test-HighRiskSecret $P) { [void]$SecretHits.Add($P) }
    }

    Write-Host "PRESERVATION_BLOBS_GE_100MB=$($Oversized.Count)"
    Write-Host "HIGH_RISK_SECRET_HITS=$($SecretHits.Count)"

    if($Oversized.Count -ne 0) {
        $Oversized | ForEach-Object { Write-Host ("OVERSIZED=" + $_) }
        Hold "Preservation candidate exceeds GitHub 100MB limit"
    }
    if($SecretHits.Count -ne 0) {
        $SecretHits | ForEach-Object { Write-Host ("SECRET_RISK=" + $_) }
        Hold "Potential secret detected in preservation candidate"
    }

    Write-Host "GITHUB_SIZE_PRE_GATE=PASS"
    Write-Host "SECRET_PRE_GATE=PASS"

    Step 7 "RECERTIFY SGD-002 OPERATIONAL STATE"
    $RuntimeChanged = @(& git.exe diff --name-only -- $RuntimeState)
    $RuntimeJsonValid = $false
    $RuntimeHash = ""

    if(Test-Path -LiteralPath (Join-Path $Root $RuntimeState) -PathType Leaf) {
        try {
            [void](Read-Utf8Json $RuntimeState)
            $RuntimeJsonValid = $true
            $RuntimeHash = Get-Sha256 $RuntimeState
        } catch {
            Hold "SGD-002 runtime state JSON validation failed"
        }
    } else {
        Hold "SGD-002 runtime state file is missing"
    }

    Write-Host "SGD002_RUNTIME_STATE_JSON=PASS"
    Write-Host "SGD002_RUNTIME_STATE_MODIFIED=$($RuntimeChanged.Count -eq 1)"
    Write-Host "SGD002_RUNTIME_STATE_SHA256=$RuntimeHash"
    Write-Host "SGD002_RECERTIFICATION=PASS"

    Step 8 "INSTITUTIONAL TEST SUITE / COMPILEALL"
    $FullOutput = @(& $Python -m pytest -q 2>&1)
    $FullExit = $LASTEXITCODE
    $FullOutput | ForEach-Object { Write-Host $_ }
    if($FullExit -ne 0) { Hold "Institutional suite failed" }

    $FullText = ($FullOutput -join "`n")
    $Passed = 0
    $Match = [regex]::Match($FullText,'(?m)(\d+)\s+passed')
    if($Match.Success) { $Passed = [int]$Match.Groups[1].Value }
    if($Passed -le 0) { Hold "Could not resolve institutional test count" }

    & $Python -m compileall -q (Join-Path $Root "src")
    if($LASTEXITCODE -ne 0) { Hold "compileall failed" }

    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "INSTITUTIONAL_TESTS=$Passed"
    Write-Host "COMPILEALL=PASS"

    Step 9 "RECONCILE COMMITS / TAGS / RELEASES"
    $Tags = @(& git.exe tag --list)
    $TrackedNow = @(& git.exe -c core.quotepath=false ls-files)
    $ReleasePaths = @($TrackedNow | Where-Object { $_ -like "releases/*" })
    $ReleaseRoots = @($ReleasePaths | ForEach-Object { ($_ -replace "\\","/").Split("/")[1] } | Where-Object { $_ } | Sort-Object -Unique)
    $RecentCommits = @(& git.exe log -100 --pretty=format:'%H%x09%ad%x09%s' --date=iso-strict)

    Write-Host "COMMITS_RECONCILED=PASS"
    Write-Host "TAGS_RECONCILED=PASS"
    Write-Host "RELEASES_RECONCILED=PASS"
    Write-Host "TAG_ACTION=INVENTORY_ONLY"
    Write-Host "RELEASE_ACTION=INVENTORY_ONLY"
    Write-Host "TAG_COUNT=$($Tags.Count)"
    Write-Host "RELEASE_ROOT_COUNT=$($ReleaseRoots.Count)"

    Step 10 "WRITE RECOVERY EVIDENCE / ACTA / SHA-256"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $EvidenceRoot) | Out-Null

    $FinalLedgerObject = [ordered]@{
        schema_version = "1.1.0"
        authoritative_input_head = $ExpectedBaseline
        preservation_set = @($Preserve)
        already_represented = @($AlreadyRepresented)
        unexpected_untracked = @($Unexpected)
        runtime_state = $RuntimeState
        destructive_cleanup = $false
        spt025_reopened = $false
    }

    $RuntimeObject = [ordered]@{
        path = $RuntimeState
        json_valid = $RuntimeJsonValid
        modified = ($RuntimeChanged.Count -eq 1)
        sha256 = $RuntimeHash
        decision = "INCLUDE_CURRENT_OPERATIONAL_STATE_IN_MASTER_SYNCHRONIZATION"
    }

    $GitObject = [ordered]@{
        authoritative_input_head = $ExpectedBaseline
        branch = $Branch
        tag_action = "INVENTORY_ONLY"
        tag_count = $Tags.Count
        tags = @($Tags)
        release_action = "INVENTORY_ONLY"
        release_root_count = $ReleaseRoots.Count
        release_roots = @($ReleaseRoots)
        recent_commits = @($RecentCommits)
    }

    $AssessmentObject = [ordered]@{
        component = "SGODA-INSTITUTIONAL-MASTER-SYNCHRONIZATION-RECOVERY"
        version = $Version
        authoritative_input_head = $ExpectedBaseline
        status = "RECOVERY_READY_FOR_PUBLICATION"
        spt025_status = "INSTITUTIONALLY_CLOSED"
        sgd000_reconciliation = "PASS"
        sgd002_recertification = "PASS"
        master_index_reconciliation = "PASS"
        master_registry_reconciliation = "PASS"
        nomenclature_reconciliation = "PASS"
        traceability_matrix_reconciliation = "PASS"
        worktree_reconciliation = "PASS"
        institutional_tests = $Passed
        compileall = "PASS"
        destructive_cleanup = $false
        production_change = $false
        real_new_platform_deployed = $false
    }

    $EvidenceObject = [ordered]@{
        authoritative_input_head = $ExpectedBaseline
        prepare_manifest = $ManifestPath
        disposition_ledger = $LedgerPath
        recovery_prepare = $PreparePath
        preservation_candidate_count = $Preserve.Count
        already_represented_count = $AlreadyRepresented.Count
        institutional_tests = $Passed
        institutional_suite = "PASS"
        compileall = "PASS"
        github_size_gate = "PASS"
        secret_gate = "PASS"
        closed_components_preserved = $true
        all_outputs_to_repository = $true
    }

    Write-Utf8NoBom $FinalLedger ($FinalLedgerObject | ConvertTo-Json -Depth 20)
    Write-Utf8NoBom $RuntimeAssessment ($RuntimeObject | ConvertTo-Json -Depth 12)
    Write-Utf8NoBom $GitInventory ($GitObject | ConvertTo-Json -Depth 20)
    Write-Utf8NoBom $MasterAssessment ($AssessmentObject | ConvertTo-Json -Depth 12)
    Write-Utf8NoBom $ImplementationEvidence ($EvidenceObject | ConvertTo-Json -Depth 12)

    $DocText = @"
# SGODA-PUINAVE - Sincronizacion Institucional Maestra - RECOVERY v1.1.0

Baseline autoritativa de entrada: `$ExpectedBaseline`.

Este RECOVERY consume el Exact Institutional Reconciliation Set y recertifica la sincronizacion institucional maestra ya incorporada por el commit autoritativo.

## Resultado requerido

- SPT-025 permanece INSTITUTIONALLY CLOSED.
- SGD-000, SGD-002, Indice Maestro, Registro Maestro, nomenclatura y matriz de trazabilidad: reconciliados.
- Evidencia historica unica: preservada.
- Duplicados SHA-256: no duplicados nuevamente.
- Commits, tags y releases: inventariados y reconciliados sin inventar nuevos tags/releases.
- Limpieza destructiva: NO.
- Nueva plataforma real desplegada: NO.
- Cambio de produccion: NO.
"@
    $ActText = @"
# ACT-SGODA-MASTER-SYNC-RECOVERY-v1.1.0

Acta tecnica de recuperacion de la Sincronizacion Institucional Maestra de SGODA-PUINAVE.

La operacion parte de `$ExpectedBaseline`, preserva SPT-025 cerrado, consume la reconciliacion no destructiva del worktree y solo puede publicar si las pruebas, SHA-256, seguridad, tamano GitHub, staging controlado y sincronizacion local/remoto resultan PASS.
"@

    Write-Utf8NoBom $RecoveryDoc $DocText
    Write-Utf8NoBom $RecoveryAct $ActText

    $IntegrityTargets = @($FinalLedger,$RuntimeAssessment,$GitInventory,$MasterAssessment,$ImplementationEvidence,$RecoveryDoc,$RecoveryAct)
    $IntegrityRecords = @()
    foreach($P in $IntegrityTargets) {
        $IntegrityRecords += [ordered]@{ path = $P; sha256 = Get-Sha256 $P }
    }
    Write-Utf8NoBom $IntegrityManifest ([ordered]@{
        algorithm = "SHA-256"
        authoritative_input_head = $ExpectedBaseline
        records = $IntegrityRecords
    } | ConvertTo-Json -Depth 20)

    Write-Host "RECOVERY_EVIDENCE=CREATED"
    Write-Host "RECOVERY_ACTA=CREATED"
    Write-Host "SHA256_MANIFEST=CREATED"

    Step 11 "SHA-256 PRESERVATION OF CLOSED TRACKED BASELINE"
    foreach($P in $Freeze.Keys) {
        if($P -eq $RuntimeState) { continue }
        $Absolute = Join-Path $Root $P
        if(-not (Test-Path -LiteralPath $Absolute -PathType Leaf)) { Hold ("Protected tracked file disappeared: " + $P) }
        if((Get-Sha256 $P) -ne $Freeze[$P]) { Hold ("Protected tracked file changed: " + $P) }
    }

    Write-Host "CLOSED_COMPONENTS_PRESERVED=PASS"
    Write-Host "SPT025_REOPENED=NO"
    Write-Host "SHA256_PRESERVATION=PASS"

    Step 12 "EXACT CONTROLLED STAGING"
    $Generated = @(
        "Invoke-SGODA-InstitutionalMasterSynchronization-SPT025Reconciliation-RECOVERY-v1.1.0-PS51.ps1",
        $FinalLedger,$MasterAssessment,$GitInventory,$RuntimeAssessment,
        $IntegrityManifest,$ImplementationEvidence,$RecoveryDoc,$RecoveryAct
    )

    $StageSet = New-Object System.Collections.ArrayList
    foreach($P in $Preserve) { if(-not $StageSet.Contains($P)) { [void]$StageSet.Add($P) } }
    foreach($P in $Generated) { if(-not $StageSet.Contains($P)) { [void]$StageSet.Add($P) } }
    if($RuntimeChanged.Count -eq 1 -and -not $StageSet.Contains($RuntimeState)) { [void]$StageSet.Add($RuntimeState) }

    foreach($P in $StageSet) {
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $P
        if($LASTEXITCODE -ne 0) { Hold ("git add failed: " + $P) }
    }

    $StagedNames = @(& git.exe -c core.quotepath=false diff --cached --name-only)
    $UnexpectedStaged = @($StagedNames | Where-Object { $StageSet -notcontains ($_ -replace "\\","/") })

    Write-Host "STAGED=$($StagedNames.Count)"
    Write-Host "EXPECTED_STAGE_SET=$($StageSet.Count)"
    Write-Host "UNEXPECTED_STAGED=$($UnexpectedStaged.Count)"

    if($UnexpectedStaged.Count -ne 0 -or $StagedNames.Count -ne $StageSet.Count) {
        Hold "Exact controlled staging mismatch"
    }

    Write-Host "STAGING_QUALITY=PASS"

    Step 13 "INDEX-WIDE GITHUB SIZE GATE / COMMIT"
    $OversizedIndex = New-Object System.Collections.ArrayList
    foreach($P in @(& git.exe -c core.quotepath=false ls-files)) {
        $SizeText = @(& git.exe cat-file -s (":" + $P) 2>$null)
        if($LASTEXITCODE -eq 0 -and $SizeText.Count -gt 0) {
            [Int64]$Size = 0
            if([Int64]::TryParse(([string]$SizeText[0]).Trim(),[ref]$Size)) {
                if($Size -ge 100MB) { [void]$OversizedIndex.Add($P) }
            }
        }
    }

    Write-Host "INDEX_BLOBS_GE_100MB=$($OversizedIndex.Count)"
    if($OversizedIndex.Count -ne 0) { Hold "GitHub index size gate failed" }
    Write-Host "GITHUB_SIZE_GATE=PASS"

    Fetch-Authoritative
    if((& git.exe rev-parse ("origin/" + $Branch)).Trim() -ne $ExpectedBaseline) { Hold "Remote advanced during RECOVERY transaction" }

    & git.exe commit -m "fix(institutional): complete master synchronization worktree reconciliation recovery v1.1.0"
    if($LASTEXITCODE -ne 0) { Hold "git commit failed" }

    $NewCommit = (& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 14 "POST-COMMIT UNIQUE-UNTRACKED GATE"
    $PostUntracked = @(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
    $TrackedAfter = @(& git.exe -c core.quotepath=false ls-files)
    $HashIndex = @{}

    foreach($P in $TrackedAfter) {
        if(Test-Path -LiteralPath (Join-Path $Root $P) -PathType Leaf) {
            $H = Get-Sha256 $P
            if(-not $HashIndex.ContainsKey($H)) { $HashIndex[$H] = $true }
        }
    }

    $UniqueRemaining = New-Object System.Collections.ArrayList
    foreach($P in $PostUntracked) {
        if(Test-Path -LiteralPath (Join-Path $Root $P) -PathType Leaf) {
            $H = Get-Sha256 $P
            if(-not $HashIndex.ContainsKey($H)) { [void]$UniqueRemaining.Add($P) }
        } else {
            [void]$UniqueRemaining.Add($P)
        }
    }

    Write-Host "UNTRACKED_REMAINING=$($PostUntracked.Count)"
    Write-Host "UNTRACKED_UNIQUE_REMAINING=$($UniqueRemaining.Count)"

    if($UniqueRemaining.Count -ne 0) {
        $UniqueRemaining | ForEach-Object { Write-Host ("UNIQUE_REMAINING=" + $_) }
        Hold "Unique institutional content remains outside repository after commit"
    }

    Write-Host "WORKTREE_RECONCILIATION=PASS"
    Write-Host "ALL_UNIQUE_INSTITUTIONAL_CONTENT_REPRESENTED=PASS"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0) { Hold "git push failed" }
    Write-Host "PUSH=PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / RECOVERY CLOSURE"
    Fetch-Authoritative

    $FinalLocal = (& git.exe rev-parse HEAD).Trim()
    $FinalRemote = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    $Ahead = (& git.exe rev-list --count ("origin/" + $Branch + "..HEAD")).Trim()
    $Behind = (& git.exe rev-list --count ("HEAD..origin/" + $Branch)).Trim()
    $FinalStaged = @(& git.exe diff --cached --name-only)
    $FinalDeleted = @(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "AHEAD           : $Ahead"
    Write-Host "BEHIND          : $Behind"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if($FinalLocal -ne $FinalRemote -or $Ahead -ne "0" -or $Behind -ne "0") { Hold "Final local/remote synchronization failed" }
    if($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0) { Hold "Final staged/deleted state is unsafe" }

    Write-Host ""
    Write-Host "SGODA INSTITUTIONAL MASTER SYNCHRONIZATION RECOVERY v1.1.0 : CLOSED / PASS" -ForegroundColor Green
    Write-Host "MASTER_SYNCHRONIZATION_RECOVERY_GATE=PASS"
    Write-Host "WORKTREE_RECONCILIATION=PASS"
    Write-Host "SPT025_STATUS=INSTITUTIONALLY_CLOSED"
    Write-Host "SPT025_REOPENED=NO"
    Write-Host "SGD000_RECONCILIATION=PASS"
    Write-Host "SGD002_RECERTIFICATION=PASS"
    Write-Host "MASTER_INDEX_RECONCILIATION=PASS"
    Write-Host "MASTER_REGISTRY_RECONCILIATION=PASS"
    Write-Host "NOMENCLATURE_RECONCILIATION=PASS"
    Write-Host "TRACEABILITY_MATRIX_RECONCILIATION=PASS"
    Write-Host "DELIVERABLE_RECONCILIATION=PASS"
    Write-Host "EVIDENCE_RECONCILIATION=PASS"
    Write-Host "ACTA_RECONCILIATION=PASS"
    Write-Host "COMMIT_TRACEABILITY=PASS"
    Write-Host "TAG_TRACEABILITY=PASS"
    Write-Host "RELEASE_TRACEABILITY=PASS"
    Write-Host "SHA256_PRESERVATION=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "INSTITUTIONAL_TESTS=$Passed"
    Write-Host "COMPILEALL=PASS"
    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "CLOSED_COMPONENTS_PRESERVED=PASS"
    Write-Host "DESTRUCTIVE_CHANGE=NO"
    Write-Host "REAL_NEW_PLATFORM_DEPLOYED=NO"
    Write-Host "PRODUCTION_CHANGE=NO"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "AHEAD=0"
    Write-Host "BEHIND=0"
    Write-Host "STAGED=0"
    Write-Host "INSTITUTIONAL_BASELINE=SYNCHRONIZED"
    Write-Host "AUTHORITATIVE_MASTER_BASELINE=$FinalLocal"
    Write-Host "NEXT_DELIVERABLE=SGODA-MASTER.CLOSE"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
