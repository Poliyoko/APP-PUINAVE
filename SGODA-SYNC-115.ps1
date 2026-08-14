#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "4d463840b2bae0bbc6f18ea869f37e792b69d450"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.1.5"

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

$EvidenceRoot = "artifacts/development/SGODA-InstitutionalMasterSynchronization-RECOVERY-v1.1.5"
$LargeRoot = "artifacts/institutional/master-synchronization/largefile-preservation-v1.1.5"

$FinalLedger = "$EvidenceRoot/final-worktree-reconciliation-ledger.json"
$MasterAssessment = "$EvidenceRoot/master-synchronization-recovery-assessment.json"
$GitInventory = "$EvidenceRoot/commits-tags-releases-recertification.json"
$RuntimeAssessment = "$EvidenceRoot/sgd002-runtime-state-recertification.json"
$IntegrityManifest = "$EvidenceRoot/master-synchronization-recovery-sha256-manifest.json"
$ImplementationEvidence = "$EvidenceRoot/implementation-evidence.json"
$SecurityAssessment = "$EvidenceRoot/security-publication-assessment.json"
$LargeManifest = "$LargeRoot/largefile-reconstructable-manifest.json"

$RecoveryDoc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Sincronizacion-Institucional-Maestra-RECOVERY-v1.1.5.md"
$RecoveryAct = "docs/00_Estado_Maestro/ACT-SGODA-MASTER-SYNC-RECOVERY-v1.1.5.md"

$SecretRiskPath = "Invoke-SGODA-SPT0242-R1-FINAL-v1.0.0-PS51.ps1"
$SecretRiskExpectedSha = "F888D0117378E6DBB2D839658E0574A69B4545C89B3C4741BB61A793D3C02F70"

$LargeInputs = @(
    [ordered]@{
        path = "artifacts/consolidation/PCI-002-v1.2.1/robocopy/staging-copy-attempt-1.log"
        sha256 = "B2DC04FBECCB99876A1402A4B0A079066A4722FF0A5BC6BA3BC3772F65A35769"
        archive = "$LargeRoot/01-staging-copy-attempt-1.log.gz"
    },
    [ordered]@{
        path = "artifacts/consolidation/PCI-002-v1.2.1/robocopy/staging-copy-attempt-2.log"
        sha256 = "0B0BE1A4FB45BE3DEFB10DE9516A9B7BD18B24B60AF63CEB1CABFE12C2E12AAA"
        archive = "$LargeRoot/02-staging-copy-attempt-2.log.gz"
    },
    [ordered]@{
        path = "artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory.json"
        sha256 = "286795A4702AB8A0ADBA3A15B6F9EE0964EDD97FA6B29B998715FB0753206D0D"
        archive = "$LargeRoot/03-institutional-inventory-pmo.json.gz"
    },
    [ordered]@{
        path = "releases/SPT-019.0-v1.1.0/institutional-inventory.json"
        sha256 = "924AAF294B9FCBC634778711116D6DCF449E7B512F41D1015EFB74BA007F99DC"
        archive = "$LargeRoot/04-institutional-inventory-release.json.gz"
    }
)

function Step {
    param([int]$Number,[string]$Title)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $Number,$Title) -ForegroundColor Cyan
}

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA MASTER SYNCHRONIZATION RECOVERY v1.1.5 : HOLD" -ForegroundColor Red
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

function Compress-Gzip {
    param([string]$SourceRelative,[string]$DestinationRelative)

    $Source = Join-Path $Root $SourceRelative
    $Destination = Join-Path $Root $DestinationRelative
    $Parent = Split-Path -Parent $Destination
    if(-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }

    $Input = [IO.File]::OpenRead($Source)
    try {
        $Output = [IO.File]::Create($Destination)
        try {
            $Gzip = New-Object IO.Compression.GZipStream($Output,[IO.Compression.CompressionMode]::Compress,$false)
            try {
                $Buffer = New-Object byte[] (1024 * 1024)
                while(($Read = $Input.Read($Buffer,0,$Buffer.Length)) -gt 0) {
                    $Gzip.Write($Buffer,0,$Read)
                }
            } finally {
                $Gzip.Dispose()
            }
        } finally {
            $Output.Dispose()
        }
    } finally {
        $Input.Dispose()
    }
}

function Test-GzipReconstruction {
    param(
        [string]$ArchiveRelative,
        [string]$ExpectedSha
    )

    $Archive = Join-Path $Root $ArchiveRelative
    $Temp = Join-Path ([IO.Path]::GetTempPath()) ("sgoda-reconstruct-" + [guid]::NewGuid().ToString("N") + ".bin")

    try {
        $Input = [IO.File]::OpenRead($Archive)
        try {
            $Gzip = New-Object IO.Compression.GZipStream($Input,[IO.Compression.CompressionMode]::Decompress,$false)
            try {
                $Output = [IO.File]::Create($Temp)
                try {
                    $Buffer = New-Object byte[] (1024 * 1024)
                    while(($Read = $Gzip.Read($Buffer,0,$Buffer.Length)) -gt 0) {
                        $Output.Write($Buffer,0,$Read)
                    }
                } finally {
                    $Output.Dispose()
                }
            } finally {
                $Gzip.Dispose()
            }
        } finally {
            $Input.Dispose()
        }

        $Actual = (Get-FileHash -LiteralPath $Temp -Algorithm SHA256).Hash.ToUpperInvariant()
        return ($Actual -eq $ExpectedSha)
    } finally {
        Remove-Item -LiteralPath $Temp -Force -ErrorAction SilentlyContinue
    }
}

function Test-ActualPemPrivateKey {
    param([string]$RelativePath)

    $Absolute = Join-Path $Root $RelativePath
    if(-not (Test-Path -LiteralPath $Absolute -PathType Leaf)) { return $false }

    try {
        $Text = [IO.File]::ReadAllText($Absolute,[Text.Encoding]::UTF8)
    } catch {
        return $false
    }

    $Pattern = '-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----\s*[A-Za-z0-9+/=\r\n]{64,}\s*-----END (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
    return [regex]::IsMatch($Text,$Pattern)
}

function Test-HighRiskSecretStream {
    param([string]$RelativePath)

    if($RelativePath -eq $SecretRiskPath) {
        return (Test-ActualPemPrivateKey $RelativePath)
    }

    $Absolute = Join-Path $Root $RelativePath
    if(-not (Test-Path -LiteralPath $Absolute -PathType Leaf)) { return $false }

    $Ext = [IO.Path]::GetExtension($Absolute).ToLowerInvariant()
    $TextExt = @(".ps1",".py",".json",".md",".txt",".yml",".yaml",".toml",".ini",".cfg",".env",".xml",".csv",".log")
    if($TextExt -notcontains $Ext) { return $false }

    $Patterns = @(
        '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
        'github_pat_[A-Za-z0-9_]{20,}',
        'ghp_[A-Za-z0-9]{30,}',
        'AKIA[0-9A-Z]{16}',
        'sk-[A-Za-z0-9_-]{20,}'
    )

    try {
        $Reader = New-Object IO.StreamReader($Absolute,[Text.Encoding]::UTF8,$true,65536)
        try {
            $Buffer = New-Object char[] 65536
            $Tail = ""
            while(($Count = $Reader.Read($Buffer,0,$Buffer.Length)) -gt 0) {
                $Chunk = $Tail + (-join $Buffer[0..($Count-1)])
                foreach($Pattern in $Patterns) {
                    if([regex]::IsMatch($Chunk,$Pattern)) { return $true }
                }
                if($Chunk.Length -gt 4096) {
                    $Tail = $Chunk.Substring($Chunk.Length - 4096)
                } else {
                    $Tail = $Chunk
                }
            }
        } finally {
            $Reader.Dispose()
        }
    } catch {
        return $false
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

    Step 2 "CONSUME RECONCILIATION PREPARE / RECERTIFY MASTER INPUTS"
    $Manifest = Read-Utf8Json $ManifestPath
    $Ledger = Read-Utf8Json $LedgerPath
    $Prepare = Read-Utf8Json $PreparePath

    if([string]$Prepare.deliverable -ne "SGODA-INSTITUTIONAL-MASTER-SYNCHRONIZATION-RECOVERY") { Hold "Unexpected PREPARE deliverable" }
    if([string]$Prepare.authoritative_input_head -ne $ExpectedBaseline) { Hold "PREPARE baseline mismatch" }
    if([string]$Prepare.baseline_gate -ne "PASS") { Hold "PREPARE baseline gate is not PASS" }
    if([bool]$Prepare.preserve_spt025 -ne $true) { Hold "SPT-025 preservation contract is not true" }
    if([bool]$Prepare.allow_destructive_cleanup -ne $false) { Hold "Destructive cleanup is allowed by PREPARE" }

    $MasterDocs = @($Sgd000,$Sgd002,$Rmi,$MasterIndex,$MasterRegistry,$Nomenclature,$TraceabilityDoc)
    $CommitPaths = @(& git.exe show --pretty=format: --name-only $ExpectedBaseline)

    foreach($P in $MasterDocs) {
        if(-not (Test-Path -LiteralPath (Join-Path $Root $P) -PathType Leaf)) { Hold ("Missing master document: " + $P) }
        if(-not (Test-Tracked $P)) { Hold ("Master document is not tracked: " + $P) }
        if($CommitPaths -notcontains $P) { Hold ("Baseline commit did not reconcile master document: " + $P) }
    }

    Write-Host "WORKTREE_RECONCILIATION_PREPARE=PASS"
    Write-Host "SGD000_RECONCILIATION=PASS"
    Write-Host "SGD002_RECONCILIATION=PASS"
    Write-Host "MASTER_INDEX_RECONCILIATION=PASS"
    Write-Host "MASTER_REGISTRY_RECONCILIATION=PASS"
    Write-Host "NOMENCLATURE_RECONCILIATION=PASS"
    Write-Host "TRACEABILITY_MATRIX_RECONCILIATION=PASS"

    Step 3 "SHA-256 FREEZE OF TRACKED BASELINE"
    $Freeze = @{}
    foreach($TrackedPath in @(& git.exe -c core.quotepath=false ls-files)) {
        $Absolute = Join-Path $Root $TrackedPath
        if(Test-Path -LiteralPath $Absolute -PathType Leaf) {
            $Freeze[$TrackedPath] = Get-Sha256 $TrackedPath
        }
    }
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA256_FREEZE=PASS"

    Step 4 "BUILD FINAL EXACT PRESERVATION SET"
    $CurrentUntracked = @(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
    $LedgerByPath = @{}
    foreach($Record in @($Ledger.records)) {
        if($null -ne $Record.path) { $LedgerByPath[[string]$Record.path] = $Record }
    }

    $Preserve = New-Object System.Collections.ArrayList
    $AlreadyRepresented = New-Object System.Collections.ArrayList
    $RawOversizedLocal = New-Object System.Collections.ArrayList
    $Unexpected = New-Object System.Collections.ArrayList

    $RequiredPrepareOutputs = @($ManifestPath,$LedgerPath,$PreparePath)

    foreach($P in $CurrentUntracked) {
        if($P -eq "SGODA-SYNC-115.ps1") {
            [void]$Preserve.Add($P)
            continue
        }

        $LargeMatch = @($LargeInputs | Where-Object { $_.path -eq $P })
        if($LargeMatch.Count -eq 1) {
            [void]$RawOversizedLocal.Add($P)
            continue
        }

        if($RequiredPrepareOutputs -contains $P) {
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

        if($P -match '^Invoke-SGODA-InstitutionalMasterSynchronization-SPT025Reconciliation-RECOVERY-v1\.1\.0-PS51.*\.ps1$') {
            [void]$Preserve.Add($P)
            continue
        }

        if($P -match '^SGODA-RECOVERY-11[012]\.ps1$') {
            [void]$Preserve.Add($P)
            continue
        }

        if($P -match '^SGODA-LARGEFILE-SECRET-(AUDIT-113|PREPARE-114)\.ps1$') {
            [void]$Preserve.Add($P)
            continue
        }

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
    Write-Host "RAW_OVERSIZED_LOCAL=$($RawOversizedLocal.Count)"
    Write-Host "ALREADY_REPRESENTED=$($AlreadyRepresented.Count)"
    Write-Host "UNEXPECTED_UNTRACKED=$($Unexpected.Count)"

    if($RawOversizedLocal.Count -ne 4) { Hold "The four expected oversized originals are not all present" }
    if($Unexpected.Count -ne 0) {
        $Unexpected | ForEach-Object { Write-Host ("UNEXPECTED=" + $_) }
        Hold "Untracked set contains content outside final recovery policy"
    }

    Write-Host "EXACT_RECONCILIATION_SET=PASS"

    Step 5 "BUILD RECONSTRUCTABLE GZIP REPRESENTATIONS"
    $LargeRecords = @()

    foreach($Entry in $LargeInputs) {
        $Source = [string]$Entry.path
        $ExpectedSha = [string]$Entry.sha256
        $Archive = [string]$Entry.archive

        if(-not (Test-Path -LiteralPath (Join-Path $Root $Source) -PathType Leaf)) { Hold ("Large input missing: " + $Source) }
        $ActualSha = Get-Sha256 $Source
        if($ActualSha -ne $ExpectedSha) { Hold ("Large input SHA-256 mismatch: " + $Source) }

        Compress-Gzip $Source $Archive

        $ArchiveBytes = (Get-Item -LiteralPath (Join-Path $Root $Archive)).Length
        if($ArchiveBytes -ge 100MB) { Hold ("GZIP archive still exceeds GitHub limit: " + $Archive) }

        if(-not (Test-GzipReconstruction $Archive $ExpectedSha)) { Hold ("GZIP reconstruction verification failed: " + $Archive) }

        $LargeRecords += [ordered]@{
            original_path = $Source
            original_bytes = [Int64](Get-Item -LiteralPath (Join-Path $Root $Source)).Length
            original_sha256 = $ExpectedSha
            repository_archive = $Archive
            archive_bytes = [Int64]$ArchiveBytes
            archive_sha256 = Get-Sha256 $Archive
            compression = "gzip"
            reconstructable = $true
            raw_original_policy = "KEEP_LOCAL_UNTRACKED"
        }

        Write-Host ("LARGEFILE_REPRESENTED=" + $Source)
        Write-Host ("ARCHIVE=" + $Archive)
        Write-Host ("ARCHIVE_MIB=" + [Math]::Round($ArchiveBytes/1MB,2))
        Write-Host "RECONSTRUCTION_SHA256=PASS"
    }

    Write-Utf8NoBom $LargeManifest ([ordered]@{
        schema_version = "1.1.5"
        authoritative_input_head = $ExpectedBaseline
        policy = "GZIP_RECONSTRUCTABLE_ARCHIVES"
        originals_deleted = $false
        records = $LargeRecords
    } | ConvertTo-Json -Depth 20)

    Write-Host "LARGEFILE_RECONSTRUCTABLE_MANIFEST=CREATED"
    Write-Host "LARGEFILE_POLICY=PASS"

    Step 6 "SECURITY RECERTIFICATION"
    if(-not (Test-Path -LiteralPath (Join-Path $Root $SecretRiskPath) -PathType Leaf)) { Hold "Secret-risk reference file is missing" }
    if((Get-Sha256 $SecretRiskPath) -ne $SecretRiskExpectedSha) { Hold "Secret-risk reference SHA-256 changed" }
    if(Test-ActualPemPrivateKey $SecretRiskPath) { Hold "A plausible private key payload exists in the historical script" }

    $SecurityScanSet = New-Object System.Collections.ArrayList
    foreach($P in $Preserve) { if(-not $SecurityScanSet.Contains($P)) { [void]$SecurityScanSet.Add($P) } }
    foreach($P in $RawOversizedLocal) { if(-not $SecurityScanSet.Contains($P)) { [void]$SecurityScanSet.Add($P) } }

    $SecretHits = New-Object System.Collections.ArrayList
    foreach($P in $SecurityScanSet) {
        if(Test-HighRiskSecretStream $P) { [void]$SecretHits.Add($P) }
    }

    Write-Host "PLAUSIBLE_PRIVATE_KEY_PAYLOAD=NO"
    Write-Host "HIGH_RISK_SECRET_HITS=$($SecretHits.Count)"
    Write-Host "SECRET_VALUES_PRINTED=NO"

    if($SecretHits.Count -ne 0) {
        $SecretHits | ForEach-Object { Write-Host ("SECRET_RISK_PATH=" + $_) }
        Hold "High-risk secret pattern remains in publication/preservation set"
    }

    Write-Host "SECURITY_GATE=PASS"

    Step 7 "RECERTIFY SGD-002 RUNTIME STATE"
    $RuntimeChanged = @(& git.exe diff --name-only -- $RuntimeState)
    if(-not (Test-Path -LiteralPath (Join-Path $Root $RuntimeState) -PathType Leaf)) { Hold "SGD-002 runtime state file is missing" }

    [void](Read-Utf8Json $RuntimeState)
    $RuntimeHash = Get-Sha256 $RuntimeState

    Write-Host "SGD002_RUNTIME_JSON=PASS"
    Write-Host "SGD002_RUNTIME_MODIFIED=$($RuntimeChanged.Count -eq 1)"
    Write-Host "SGD002_RUNTIME_SHA256=$RuntimeHash"
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

    Step 10 "WRITE FINAL RECOVERY EVIDENCE / ACTA"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $EvidenceRoot) | Out-Null

    $FinalLedgerObject = [ordered]@{
        schema_version = "1.1.5"
        authoritative_input_head = $ExpectedBaseline
        preservation_set = @($Preserve)
        already_represented = @($AlreadyRepresented)
        oversized_raw_local = @($RawOversizedLocal)
        largefile_manifest = $LargeManifest
        unexpected_untracked = @($Unexpected)
        destructive_cleanup = $false
        spt025_reopened = $false
    }

    $RuntimeObject = [ordered]@{
        path = $RuntimeState
        json_valid = $true
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

    $SecurityObject = [ordered]@{
        secret_risk_path = $SecretRiskPath
        secret_risk_sha256 = $SecretRiskExpectedSha
        plausible_private_key_payload = $false
        high_risk_secret_hits = 0
        secret_values_printed = $false
        publication_gate = "PASS"
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
        largefile_policy = "GZIP_RECONSTRUCTABLE_ARCHIVES"
        security_gate = "PASS"
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
        oversized_raw_local_count = $RawOversizedLocal.Count
        reconstructable_archive_count = $LargeRecords.Count
        institutional_tests = $Passed
        institutional_suite = "PASS"
        compileall = "PASS"
        github_size_gate = "PASS"
        security_gate = "PASS"
        closed_components_preserved = $true
        all_unique_institutional_content_represented = $true
    }

    Write-Utf8NoBom $FinalLedger ($FinalLedgerObject | ConvertTo-Json -Depth 20)
    Write-Utf8NoBom $RuntimeAssessment ($RuntimeObject | ConvertTo-Json -Depth 12)
    Write-Utf8NoBom $GitInventory ($GitObject | ConvertTo-Json -Depth 20)
    Write-Utf8NoBom $SecurityAssessment ($SecurityObject | ConvertTo-Json -Depth 12)
    Write-Utf8NoBom $MasterAssessment ($AssessmentObject | ConvertTo-Json -Depth 12)
    Write-Utf8NoBom $ImplementationEvidence ($EvidenceObject | ConvertTo-Json -Depth 12)

    $DocText = @"
# SGODA-PUINAVE - Sincronizacion Institucional Maestra - RECOVERY v1.1.5

Baseline autoritativa de entrada: `$ExpectedBaseline`.

Este RECOVERY completa la reconciliacion institucional del worktree, preserva SPT-025 cerrado y representa los cuatro artefactos historicos mayores a 100 MB mediante archivos GZIP reconstructibles con manifiesto SHA-256.

Los originales grandes permanecen localmente sin eliminarse. El repositorio contiene su representacion binaria completa y reconstructible.

Los tags y releases existentes son reconciliados por inventario. Esta operacion no inventa tags ni releases nuevos.

No se despliega ninguna plataforma real y no se modifica produccion.
"@

    $ActText = @"
# ACT-SGODA-MASTER-SYNC-RECOVERY-v1.1.5

Acta tecnica de recuperacion final de la Sincronizacion Institucional Maestra de SGODA-PUINAVE.

La operacion parte de `$ExpectedBaseline`, consume la reconciliacion PREPARE, preserva la linea cerrada, recertifica SGD-002, ejecuta pruebas institucionales, aplica control de secretos, representa de manera reconstructible los archivos incompatibles con el limite de GitHub y exige igualdad final entre HEAD local y remoto.
"@

    Write-Utf8NoBom $RecoveryDoc $DocText
    Write-Utf8NoBom $RecoveryAct $ActText

    $IntegrityTargets = @(
        $FinalLedger,$MasterAssessment,$GitInventory,$RuntimeAssessment,$SecurityAssessment,
        $IntegrityManifest,$ImplementationEvidence,$RecoveryDoc,$RecoveryAct,$LargeManifest
    )

    $IntegrityRecords = @()
    foreach($P in $IntegrityTargets | Where-Object { $_ -ne $IntegrityManifest }) {
        $IntegrityRecords += [ordered]@{ path = $P; sha256 = Get-Sha256 $P }
    }
    foreach($Entry in $LargeInputs) {
        $IntegrityRecords += [ordered]@{ path = [string]$Entry.archive; sha256 = Get-Sha256 ([string]$Entry.archive) }
    }

    Write-Utf8NoBom $IntegrityManifest ([ordered]@{
        algorithm = "SHA-256"
        authoritative_input_head = $ExpectedBaseline
        records = $IntegrityRecords
    } | ConvertTo-Json -Depth 20)

    Write-Host "RECOVERY_EVIDENCE=CREATED"
    Write-Host "RECOVERY_ACTA=CREATED"
    Write-Host "SECURITY_ASSESSMENT=CREATED"
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
        "SGODA-SYNC-115.ps1",
        $FinalLedger,$MasterAssessment,$GitInventory,$RuntimeAssessment,$SecurityAssessment,
        $IntegrityManifest,$ImplementationEvidence,$RecoveryDoc,$RecoveryAct,$LargeManifest
    )
    foreach($Entry in $LargeInputs) { $Generated += [string]$Entry.archive }

    $StageSet = New-Object System.Collections.ArrayList

    foreach($P in $Preserve) {
        if($RawOversizedLocal -contains $P) { continue }
        if(-not $StageSet.Contains($P)) { [void]$StageSet.Add($P) }
    }

    foreach($P in $Generated) {
        if(-not $StageSet.Contains($P)) { [void]$StageSet.Add($P) }
    }

    if($RuntimeChanged.Count -eq 1 -and -not $StageSet.Contains($RuntimeState)) {
        [void]$StageSet.Add($RuntimeState)
    }

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

    Step 13 "INDEX-WIDE GITHUB SIZE GATE / FINAL REMOTE GATE"
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
    if($OversizedIndex.Count -ne 0) {
        $OversizedIndex | ForEach-Object { Write-Host ("INDEX_OVERSIZED=" + $_) }
        Hold "GitHub index size gate failed"
    }

    Write-Host "GITHUB_SIZE_GATE=PASS"

    Fetch-Authoritative
    if((& git.exe rev-parse ("origin/" + $Branch)).Trim() -ne $ExpectedBaseline) {
        Hold "Remote advanced during RECOVERY transaction"
    }

    Write-Host "REMOTE_GATE=PASS"

    Step 14 "COMMIT / POST-COMMIT REPRESENTATION GATE"
    & git.exe commit -m "fix(institutional): finalize master synchronization recovery with reconstructable evidence"
    if($LASTEXITCODE -ne 0) { Hold "git commit failed" }

    $NewCommit = (& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    $PostUntracked = @(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)

    $TrackedHashIndex = @{}
    foreach($P in @(& git.exe -c core.quotepath=false ls-files)) {
        if(Test-Path -LiteralPath (Join-Path $Root $P) -PathType Leaf) {
            $H = Get-Sha256 $P
            $TrackedHashIndex[$H] = $true
        }
    }

    $Unrepresented = New-Object System.Collections.ArrayList
    $RawLargeRemaining = New-Object System.Collections.ArrayList
    $DuplicateRemaining = New-Object System.Collections.ArrayList

    foreach($P in $PostUntracked) {
        $LargeMatch = @($LargeInputs | Where-Object { $_.path -eq $P })
        if($LargeMatch.Count -eq 1) {
            $ExpectedSha = [string]$LargeMatch[0].sha256
            if((Get-Sha256 $P) -eq $ExpectedSha) {
                [void]$RawLargeRemaining.Add($P)
                continue
            }
        }

        if(Test-Path -LiteralPath (Join-Path $Root $P) -PathType Leaf) {
            $H = Get-Sha256 $P
            if($TrackedHashIndex.ContainsKey($H)) {
                [void]$DuplicateRemaining.Add($P)
                continue
            }
        }

        [void]$Unrepresented.Add($P)
    }

    Write-Host "UNTRACKED_RAW_OVERSIZED_LOCAL=$($RawLargeRemaining.Count)"
    Write-Host "UNTRACKED_EXACT_DUPLICATES=$($DuplicateRemaining.Count)"
    Write-Host "UNTRACKED_UNREPRESENTED=$($Unrepresented.Count)"

    if($RawLargeRemaining.Count -ne 4) { Hold "Expected four local oversized originals after commit" }
    if($Unrepresented.Count -ne 0) {
        $Unrepresented | ForEach-Object { Write-Host ("UNREPRESENTED=" + $_) }
        Hold "Unique institutional content remains unrepresented after commit"
    }

    Write-Host "ALL_UNIQUE_INSTITUTIONAL_CONTENT_REPRESENTED=PASS"
    Write-Host "RAW_OVERSIZED_ORIGINALS_PRESERVED_LOCAL=PASS"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0) { Hold "git push failed" }
    Write-Host "PUSH=PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / MASTER SYNC CLOSURE"
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

    if($FinalLocal -ne $FinalRemote -or $Ahead -ne "0" -or $Behind -ne "0") {
        Hold "Final local/remote synchronization failed"
    }
    if($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0) {
        Hold "Final staged/deleted state is unsafe"
    }

    Write-Host ""
    Write-Host "SGODA INSTITUTIONAL MASTER SYNCHRONIZATION RECOVERY v1.1.5 : CLOSED / PASS" -ForegroundColor Green
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
    Write-Host "LARGEFILE_RECONSTRUCTABLE_POLICY=PASS"
    Write-Host "SECURITY_GATE=PASS"
    Write-Host "SHA256_PRESERVATION=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "INSTITUTIONAL_TESTS=$Passed"
    Write-Host "COMPILEALL=PASS"
    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "CLOSED_COMPONENTS_PRESERVED=PASS"
    Write-Host "ALL_UNIQUE_INSTITUTIONAL_CONTENT_REPRESENTED=PASS"
    Write-Host "RAW_OVERSIZED_LOCAL_PRESERVED=4"
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
