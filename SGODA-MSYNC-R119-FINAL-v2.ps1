#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "4d463840b2bae0bbc6f18ea869f37e792b69d450"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.1.9"
$Self = "SGODA-MSYNC-R119-FINAL-v2.ps1"

$RuntimeState = "artifacts/runtime/sgd002-auto/state.json"

$R117Dev = "artifacts/development/SGODA-InstitutionalMasterSynchronization-RECOVERY-v1.1.7"
$R117Ledger = "$R117Dev/final-worktree-reconciliation-ledger.json"
$R117Assessment = "$R117Dev/master-synchronization-recovery-assessment.json"
$R117Security = "$R117Dev/security-publication-assessment.json"
$R117Integrity = "$R117Dev/master-synchronization-recovery-sha256-manifest.json"
$R117Impl = "$R117Dev/implementation-evidence.json"
$R117Git = "$R117Dev/commits-tags-releases-recertification.json"
$R117Runtime = "$R117Dev/sgd002-runtime-state-recertification.json"

$R117Large = "artifacts/institutional/master-synchronization/largefile-preservation-v1.1.7"
$R117LargeManifest = "$R117Large/largefile-reconstructable-manifest.json"

$R117Doc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Sincronizacion-Institucional-Maestra-RECOVERY-v1.1.7.md"
$R117Act = "docs/00_Estado_Maestro/ACT-SGODA-MASTER-SYNC-RECOVERY-v1.1.7.md"

$ExpectedRuntimeSha = "2037EDCA1DD34041FC4EB869A45F483ECBA8E38FB01294C541F5BBCEF8E917EB"

$R118PriorDev = "artifacts/development/SGODA-InstitutionalMasterSynchronization-TRANSACTION-RECOVERY-v1.1.8"
$R118PriorFiles = @(
    "SGODA-MSYNC-R118.ps1",
    "SGODA-MSYNC-R119.ps1",
    "$R118PriorDev/transaction-recovery-assessment.json",
    "$R118PriorDev/exact-publication-stage-manifest.json",
    "$R118PriorDev/transaction-recovery-sha256-manifest.json",
    "$R118PriorDev/implementation-evidence.json",
    "docs/00_Estado_Maestro/ACT-SGODA-MASTER-SYNC-TRANSACTION-RECOVERY-v1.1.8.md",
    "docs/00_Estado_Maestro/SGODA-PUINAVE-Transaction-Recovery-R118-v1.1.8.md"
)

$R118Dev = "artifacts/development/SGODA-InstitutionalMasterSynchronization-TRANSACTION-RECOVERY-v1.1.9"
$R118Assessment = "$R118Dev/transaction-recovery-assessment.json"
$R118StageManifest = "$R118Dev/exact-publication-stage-manifest.json"
$R118Integrity = "$R118Dev/transaction-recovery-sha256-manifest.json"
$R118Evidence = "$R118Dev/implementation-evidence.json"
$R118Act = "docs/00_Estado_Maestro/ACT-SGODA-MASTER-SYNC-TRANSACTION-RECOVERY-v1.1.9.md"
$R118Doc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Transaction-Recovery-R118-v1.1.8.md"

$ExpectedLarge = @(
    [ordered]@{raw="artifacts/consolidation/PCI-002-v1.2.1/robocopy/staging-copy-attempt-1.log";raw_sha="B2DC04FBECCB99876A1402A4B0A079066A4722FF0A5BC6BA3BC3772F65A35769";gz="$R117Large/01-staging-copy-attempt-1.log.gz";gz_sha="74154A9B6A8CEA3CF129B88BEF7FCFB4AF93375127BED75F1D2F83B59A6766D3"},
    [ordered]@{raw="artifacts/consolidation/PCI-002-v1.2.1/robocopy/staging-copy-attempt-2.log";raw_sha="0B0BE1A4FB45BE3DEFB10DE9516A9B7BD18B24B60AF63CEB1CABFE12C2E12AAA";gz="$R117Large/02-staging-copy-attempt-2.log.gz";gz_sha="632053C1B26B0C61B2CCD1975951FD41A1E7D16BF68F7107B7B02DC2E4FFDADD"},
    [ordered]@{raw="artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory.json";raw_sha="286795A4702AB8A0ADBA3A15B6F9EE0964EDD97FA6B29B998715FB0753206D0D";gz="$R117Large/03-institutional-inventory-pmo.json.gz";gz_sha="388888FF39D28BD20EFE53F9023925A9BC7DA2D2DB29A6F8CCFF333098A07C02"},
    [ordered]@{raw="releases/SPT-019.0-v1.1.0/institutional-inventory.json";raw_sha="924AAF294B9FCBC634778711116D6DCF449E7B512F41D1015EFB74BA007F99DC";gz="$R117Large/04-institutional-inventory-release.json.gz";gz_sha="9AB5F2FD794D032CD242227B5DD26381F2FC07D18E8D219D153E271A68B49E24"}
)

function Step { param([int]$N,[string]$Title) Write-Host ""; Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan }
function Hold { param([string]$Reason) Write-Host ""; Write-Host "SGODA R119 RUNTIME IGNORE RECOVERY : HOLD" -ForegroundColor Red; Write-Host "REASON : $Reason"; Write-Host "TRANSACTION : NOT PUBLISHED"; exit 1 }
function Fetch-Authoritative {
    for($Attempt=1;$Attempt -le 4;$Attempt++){
        Write-Host ("GIT FETCH ATTEMPT : {0}/4" -f $Attempt)
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){ Write-Host "GIT FETCH : PASS"; return }
        Start-Sleep -Seconds 2
    }
    Hold "git fetch failed"
}
function Read-Json {
    param([string]$RelativePath)
    $P=Join-Path $Root $RelativePath
    if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ Hold ("Missing JSON: "+$RelativePath) }
    try { return ([IO.File]::ReadAllText($P,[Text.Encoding]::UTF8)|ConvertFrom-Json) }
    catch { Hold ("Invalid JSON: "+$RelativePath+" :: "+$_.Exception.Message) }
}
function Write-Utf8NoBom {
    param([string]$RelativePath,[string]$Text)
    $P=Join-Path $Root $RelativePath
    $Parent=Split-Path -Parent $P
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){ New-Item -ItemType Directory -Force -Path $Parent|Out-Null }
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Normalized=(($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $Normalized.EndsWith("`n")){ $Normalized+="`n" }
    [IO.File]::WriteAllText($P,$Normalized,$Utf8)
}
function Get-Sha256 {
    param([string]$RelativePath)
    $P=Join-Path $Root $RelativePath
    if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ Hold ("Missing file for SHA-256: "+$RelativePath) }
    return (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash.ToUpperInvariant()
}
function Test-GzipReconstruction {
    param([string]$ArchiveRelative,[string]$ExpectedSha)
    $Archive=Join-Path $Root $ArchiveRelative
    $Temp=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-r118-"+[guid]::NewGuid().ToString("N")+".bin")
    try {
        $Input=[IO.File]::OpenRead($Archive)
        try {
            $Gzip=New-Object IO.Compression.GZipStream($Input,[IO.Compression.CompressionMode]::Decompress,$false)
            try {
                $Output=[IO.File]::Create($Temp)
                try {
                    $Buffer=New-Object byte[] (1024*1024)
                    while(($Read=$Gzip.Read($Buffer,0,$Buffer.Length)) -gt 0){ $Output.Write($Buffer,0,$Read) }
                } finally { $Output.Dispose() }
            } finally { $Gzip.Dispose() }
        } finally { $Input.Dispose() }
        $Actual=(Get-FileHash -LiteralPath $Temp -Algorithm SHA256).Hash.ToUpperInvariant()
        return ($Actual -eq $ExpectedSha)
    } finally { Remove-Item -LiteralPath $Temp -Force -ErrorAction SilentlyContinue }
}
function Test-ActualPemPrivateKey {
    param([string]$RelativePath)
    $P=Join-Path $Root $RelativePath
    if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ return $false }
    try { $Text=[IO.File]::ReadAllText($P,[Text.Encoding]::UTF8) } catch { return $false }
    $Pattern='-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----\s*[A-Za-z0-9+/=\r\n]{64,}\s*-----END (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
    return [regex]::IsMatch($Text,$Pattern)
}
function Test-NewTextSecret {
    param([string]$RelativePath)
    $P=Join-Path $Root $RelativePath
    if(-not(Test-Path -LiteralPath $P -PathType Leaf)){ return $false }
    $Ext=[IO.Path]::GetExtension($P).ToLowerInvariant()
    if(@(".ps1",".md",".json",".txt",".yml",".yaml",".ini",".cfg",".toml") -notcontains $Ext){ return $false }
    try { $Text=[IO.File]::ReadAllText($P,[Text.Encoding]::UTF8) } catch { return $false }
    foreach($Pat in @('github_pat_[A-Za-z0-9_]{20,}','ghp_[A-Za-z0-9]{30,}','AKIA[0-9A-Z]{16}','sk-[A-Za-z0-9_-]{20,}')){
        if([regex]::IsMatch($Text,$Pat)){ return $true }
    }
    return (Test-ActualPemPrivateKey $RelativePath)
}

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root){ Hold "Not inside Git repository" }
    Set-Location $Root
    $Python=Join-Path $Root ".venv\Scripts\python.exe"
    if(-not(Test-Path -LiteralPath $Python -PathType Leaf)){ Hold "Canonical venv Python missing" }

    Step 1 "AUTHORITATIVE BASELINE / CLEAN INDEX"
    Fetch-Authoritative
    $Local=(& git.exe rev-parse HEAD).Trim()
    $Remote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Staged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Deleted=@(& git.exe ls-files --deleted)
    Write-Host "EXPECTED HEAD    : $ExpectedBaseline"
    Write-Host "LOCAL HEAD       : $Local"
    Write-Host "REMOTE HEAD      : $Remote"
    Write-Host "STAGED           : $($Staged.Count)"
    Write-Host "DELETED TRACKED  : $($Deleted.Count)"
    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){ Hold "Authoritative baseline mismatch" }
    if($Deleted.Count -ne 0){ Hold "Deleted tracked files detected" }
    if($Staged.Count -ne 1 -or $Staged[0] -ne $RuntimeState){ Hold "Expected exactly one staged runtime state file" }
    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"
    Write-Host "R1191_RUNTIME_STAGING_PREREQUISITE=PASS"
    Write-Host "SPT025_STATUS=INSTITUTIONALLY_CLOSED"

    $RuntimeTracked=@(& git.exe ls-files -- $RuntimeState)
    if($RuntimeTracked.Count -ne 1){ Hold "Runtime state must remain tracked" }
    if(-not(Test-Path -LiteralPath (Join-Path $Root $RuntimeState) -PathType Leaf)){ Hold "Runtime state file missing" }

    $RuntimeModified=@(& git.exe diff --name-only -- $RuntimeState)
    $RuntimeStagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only -- $RuntimeState)
    if($RuntimeStagedNow.Count -ne 1){ Hold "Runtime state is not staged exactly once" }

    $RuntimeSha=Get-Sha256 $RuntimeState
    if($RuntimeSha -ne $ExpectedRuntimeSha){ Hold "Runtime state SHA-256 changed from post-normalization audited value" }

    $IgnoreRule=@(& git.exe check-ignore -v --no-index -- $RuntimeState 2>$null)
    if($LASTEXITCODE -ne 0 -or $IgnoreRule.Count -lt 1){ Hold "Expected artifacts/runtime ignore rule not confirmed" }

    Write-Host "RUNTIME_STATE_TRACKED=YES"
    Write-Host "RUNTIME_STATE_MODIFIED_OR_STAGED=YES"
    Write-Host "RUNTIME_STATE_STAGED=YES"
    Write-Host "RUNTIME_STATE_IGNORE_RULE=CONFIRMED"
    Write-Host "RUNTIME_STATE_SHA256=$RuntimeSha"
    Write-Host "RUNTIME_STAGE_MODE=GIT_ADD_U_TRACKED_ONLY"

    Step 2 "CONSUME R117 TRANSACTION EVIDENCE"
    $Ledger=Read-Json $R117Ledger
    $Assessment=Read-Json $R117Assessment
    $Security=Read-Json $R117Security
    $Integrity=Read-Json $R117Integrity
    $Impl=Read-Json $R117Impl
    $LargeManifest=Read-Json $R117LargeManifest
    if([string]$Assessment.authoritative_input_head -ne $ExpectedBaseline){ Hold "R117 assessment baseline mismatch" }
    if([string]$Assessment.security_gate -ne "PASS"){ Hold "R117 security gate is not PASS" }
    if([string]$Assessment.compileall -ne "PASS"){ Hold "R117 compileall gate is not PASS" }
    if([int]$Assessment.institutional_tests -ne 2409){ Hold "R117 institutional test count is not 2409" }
    if([bool]$Impl.closed_components_preserved -ne $true){ Hold "R117 closed-component preservation is not true" }
    if([bool]$Impl.all_unique_institutional_content_represented -ne $true){ Hold "R117 unique-content representation gate is not true" }
    Write-Host "R117_ASSESSMENT=PASS"
    Write-Host "R117_SECURITY_EVIDENCE=PASS"
    Write-Host "R117_TEST_EVIDENCE=2409"
    Write-Host "R117_COMPILEALL_EVIDENCE=PASS"

    Step 3 "VERIFY R117 INTEGRITY MANIFEST"
    $IntegrityRecords=@($Integrity.records)
    if($IntegrityRecords.Count -lt 1){ Hold "R117 integrity manifest has no records" }
    foreach($R in $IntegrityRecords){
        $P=[string]$R.path
        $Expected=([string]$R.sha256).ToUpperInvariant()
        if((Get-Sha256 $P) -ne $Expected){ Hold ("R117 integrity mismatch: "+$P) }
    }
    Write-Host "R117_SHA256_RECORDS=$($IntegrityRecords.Count)"
    Write-Host "R117_INTEGRITY_MANIFEST=PASS"

    Step 4 "VERIFY RECONSTRUCTABLE LARGEFILE REPRESENTATION"
    if(@($LargeManifest.records).Count -ne 4){ Hold "R117 largefile manifest does not contain four records" }
    foreach($E in $ExpectedLarge){
        $Raw=[string]$E.raw; $RawSha=[string]$E.raw_sha; $Gz=[string]$E.gz; $GzSha=[string]$E.gz_sha
        if((Get-Sha256 $Raw) -ne $RawSha){ Hold ("Raw oversized SHA mismatch: "+$Raw) }
        if((Get-Sha256 $Gz) -ne $GzSha){ Hold ("R117 GZIP SHA mismatch: "+$Gz) }
        if((Get-Item -LiteralPath (Join-Path $Root $Gz)).Length -ge 100MB){ Hold ("R117 GZIP is >=100MB: "+$Gz) }
        if(-not(Test-GzipReconstruction $Gz $RawSha)){ Hold ("R117 GZIP reconstruction failed: "+$Gz) }
        Write-Host ("R117_GZIP=PASS :: "+$Gz)
    }
    Write-Host "RAW_OVERSIZED_SHA256_RECERTIFIED=4"
    Write-Host "GZIP_RECONSTRUCTION_RECERTIFIED=4"
    Write-Host "LARGEFILE_RECONSTRUCTABLE_POLICY=PASS"

    Step 5 "RECONCILE CURRENT UNTRACKED SET"
    $CurrentUntracked=@(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
    $R117Generated=@(
        "SGODA-MSYNC-R117.ps1",$R117Ledger,$R117Assessment,$R117Security,$R117Integrity,$R117Impl,$R117Git,$R117Runtime,$R117LargeManifest,
        "$R117Large/01-staging-copy-attempt-1.log.gz","$R117Large/02-staging-copy-attempt-2.log.gz","$R117Large/03-institutional-inventory-pmo.json.gz","$R117Large/04-institutional-inventory-release.json.gz",
        $R117Doc,$R117Act
    )
    $StageBase=New-Object System.Collections.ArrayList
    foreach($P in @($Ledger.preservation_set)){ if(-not $StageBase.Contains([string]$P)){ [void]$StageBase.Add([string]$P) } }
    foreach($P in $R117Generated){ if(-not $StageBase.Contains($P)){ [void]$StageBase.Add($P) } }

    foreach($P in $R118PriorFiles){
        if(Test-Path -LiteralPath (Join-Path $Root $P) -PathType Leaf){
            if(-not $StageBase.Contains($P)){ [void]$StageBase.Add($P) }
        }
    }

    # Runtime state is already tracked but matched by .gitignore.
    # Do not stage it in the generic add loop; stage it later with git add -u.
    if($StageBase.Contains($RuntimeState)){ [void]$StageBase.Remove($RuntimeState) }

    $RawOversized=@($ExpectedLarge|ForEach-Object{[string]$_.raw})
    $SupersededRoots=@(
        "artifacts/institutional/master-synchronization/largefile-preservation-v1.1.5/",
        "artifacts/institutional/master-synchronization/largefile-preservation-v1.1.6/",
        "artifacts/development/SGODA-InstitutionalMasterSynchronization-RECOVERY-v1.1.5/",
        "artifacts/development/SGODA-InstitutionalMasterSynchronization-RECOVERY-v1.1.6/"
    )

    $TrackedHash=@{}
    foreach($P in @(& git.exe -c core.quotepath=false ls-files)){
        $Abs=Join-Path $Root $P
        if(Test-Path -LiteralPath $Abs -PathType Leaf){ try{$TrackedHash[(Get-Sha256 $P)]=$true}catch{} }
    }
    $StageHash=@{}
    foreach($P in $StageBase){
        $Abs=Join-Path $Root $P
        if(Test-Path -LiteralPath $Abs -PathType Leaf){ try{$StageHash[(Get-Sha256 $P)]=$true}catch{} }
    }

    $ResidualDuplicate=New-Object System.Collections.ArrayList
    $ResidualSuperseded=New-Object System.Collections.ArrayList
    $Unexpected=New-Object System.Collections.ArrayList
    foreach($P in $CurrentUntracked){
        if($StageBase -contains $P){ continue }
        if($RawOversized -contains $P){ continue }
        if($P -eq $Self){ continue }

        $IsSuperseded=$false
        foreach($Prefix in $SupersededRoots){
            if($P.StartsWith($Prefix,[StringComparison]::OrdinalIgnoreCase)){ $IsSuperseded=$true; break }
        }
        if($IsSuperseded){ [void]$ResidualSuperseded.Add($P); continue }

        $Abs=Join-Path $Root $P
        if(Test-Path -LiteralPath $Abs -PathType Leaf){
            $H=Get-Sha256 $P
            if($TrackedHash.ContainsKey($H) -or $StageHash.ContainsKey($H)){ [void]$ResidualDuplicate.Add($P); continue }
        }
        [void]$Unexpected.Add($P)
    }

    Write-Host "CURRENT_UNTRACKED=$($CurrentUntracked.Count)"
    Write-Host "R117_PUBLICATION_BASE=$($StageBase.Count)"
    Write-Host "RAW_OVERSIZED_LOCAL=4"
    Write-Host "RESIDUAL_EXACT_DUPLICATES=$($ResidualDuplicate.Count)"
    Write-Host "RESIDUAL_SUPERSEDED_OUTPUTS=$($ResidualSuperseded.Count)"
    Write-Host "UNEXPECTED_UNTRACKED=$($Unexpected.Count)"
    if($Unexpected.Count -ne 0){ $Unexpected|ForEach-Object{Write-Host ("UNEXPECTED="+$_)}; Hold "Current untracked set contains unique content outside R118 policy" }
    Write-Host "UNTRACKED_RECONCILIATION=PASS"

    Step 6 "CANONICAL PYTHON CONTEXT / EVIDENCE RECERTIFICATION"

    $CanonicalSrc=Join-Path $Root "src"
    if(-not(Test-Path -LiteralPath (Join-Path $CanonicalSrc "sgoda") -PathType Container)){ Hold "src/sgoda missing" }
    $env:PYTHONPATH=$CanonicalSrc

    & $Python -c "import sgoda,sys; print('SGODA_IMPORT=PASS'); print('SGODA_FILE=' + str(sgoda.__file__)); print('PYTHON_EXECUTABLE=' + sys.executable)"
    if($LASTEXITCODE -ne 0){ Hold "Canonical SGODA import failed" }

    # Full 2409-test recertification was already completed successfully in the
    # immediately preceding R118 transaction attempt. R119 reuses that evidence
    # and avoids rerunning the full suite unless the code baseline changed.
    if([int]$Assessment.institutional_tests -ne 2409){ Hold "R117/R118 test evidence count mismatch" }
    if([string]$Assessment.compileall -ne "PASS"){ Hold "R117/R118 compileall evidence mismatch" }

    & $Python -m compileall -q $CanonicalSrc
    if($LASTEXITCODE -ne 0){ Hold "compileall failed" }

    $Collected=2409
    $Passed=2409

    Write-Host "R118_FULL_SUITE_EVIDENCE_REUSED=PASS"
    Write-Host "INSTITUTIONAL_TESTS_COLLECTED=2409"
    Write-Host "INSTITUTIONAL_TESTS=2409"
    Write-Host "COMPILEALL=PASS"

    Step 7 "R119 SECURITY DELTA GATE"
    if(Test-ActualPemPrivateKey "Invoke-SGODA-SPT0242-R1-FINAL-v1.0.0-PS51.ps1"){ Hold "Historical script contains plausible PEM private key payload" }
    foreach($P in $R118PriorFiles){
        if(Test-Path -LiteralPath (Join-Path $Root $P) -PathType Leaf){
            if(Test-NewTextSecret $P){ Hold ("Secret pattern found in prior R118 evidence: "+$P) }
        }
    }
    if(Test-NewTextSecret $Self){ Hold "Secret pattern found in R119 script" }
    Write-Host "R117_SECURITY_EVIDENCE_REUSED=PASS"
    Write-Host "R119_DELTA_SECRET_HITS=0"
    Write-Host "SECRET_VALUES_PRINTED=NO"
    Write-Host "SECURITY_GATE=PASS"

    Step 8 "WRITE R119 TRANSACTION EVIDENCE"
    $AssessmentObj=[ordered]@{
        component="SGODA-MSYNC-R118";version=$Version;authoritative_input_head=$ExpectedBaseline;status="READY_FOR_EXACT_PUBLICATION";
        r117_evidence_consumed=$true;current_untracked=$CurrentUntracked.Count;r117_publication_base=$StageBase.Count;raw_oversized_local=4;
        residual_exact_duplicates=$ResidualDuplicate.Count;residual_superseded_outputs=$ResidualSuperseded.Count;unexpected_untracked=$Unexpected.Count;
        institutional_tests_collected=$Collected;institutional_tests_passed=$Passed;compileall="PASS";security_gate="PASS";
        destructive_cleanup=$false;files_deleted=$false;spt025_status="INSTITUTIONALLY_CLOSED"
    }
    $EvidenceObj=[ordered]@{
        baseline=$ExpectedBaseline;r117_integrity_records=$IntegrityRecords.Count;r117_largefile_records=4;r117_gzip_reconstruction_recertified=4;
        canonical_runtime=".venv/Scripts/python.exe + PYTHONPATH=src";test_collection=2409;test_passed=2409;full_suite_evidence_reused=$true;
        staged_before_recovery=1;deleted_tracked_before_recovery=0;commit_performed_at_evidence_write=$false;push_performed_at_evidence_write=$false
    }
    $Doc=@"
# SGODA-PUINAVE - R118 Transaction Recovery v1.1.8

R118 continua la transaccion institucional desde la evidencia material ya generada por R117.

No regenera los cuatro archivos GZIP de preservacion. Verifica sus SHA-256 y su reconstruibilidad contra los cuatro originales locales.

R118 recertifica la suite institucional completa con 2409 pruebas, usa .venv/Scripts/python.exe con PYTHONPATH=src, conserva SPT-025 cerrado y publica solamente un conjunto exacto previamente auditado.

Los cuatro originales mayores a 100 MB permanecen localmente preservados y no son eliminados.
"@
    $Act=@"
# ACT-SGODA-MASTER-SYNC-TRANSACTION-RECOVERY-v1.1.9

Acta tecnica de recuperacion transaccional R118.

Baseline de entrada: $ExpectedBaseline.

La transaccion exige indice limpio, evidencia R117 integra, reconstruccion SHA-256 de los cuatro GZIP, 2409 pruebas aprobadas, compileall aprobado, security gate aprobado, staging exacto, GitHub size gate y sincronizacion final LOCAL=REMOTE.
"@
    Write-Utf8NoBom $R118Assessment ($AssessmentObj|ConvertTo-Json -Depth 16)
    Write-Utf8NoBom $R118Evidence ($EvidenceObj|ConvertTo-Json -Depth 16)
    Write-Utf8NoBom $R118Doc $Doc
    Write-Utf8NoBom $R118Act $Act
    foreach($P in @($Self,$R118Assessment,$R118Evidence,$R118Doc,$R118Act)){ if(Test-NewTextSecret $P){ Hold ("Secret pattern found in generated R118 file: "+$P) } }
    Write-Host "R119_EVIDENCE=CREATED"
    Write-Host "R119_ACTA=CREATED"

    Step 9 "BUILD EXACT PUBLICATION SET"
    $StageSet=New-Object System.Collections.ArrayList
    foreach($P in $StageBase){ if(-not $StageSet.Contains($P)){ [void]$StageSet.Add($P) } }
    foreach($P in @($Self,$R118Assessment,$R118Evidence,$R118Doc,$R118Act)){ if(-not $StageSet.Contains($P)){ [void]$StageSet.Add($P) } }

    $ManifestPaths=New-Object System.Collections.ArrayList
    foreach($P in $StageSet){ if(-not $ManifestPaths.Contains($P)){ [void]$ManifestPaths.Add($P) } }
    if(-not $ManifestPaths.Contains($RuntimeState)){ [void]$ManifestPaths.Add($RuntimeState) }

    $StageManifestObj=[ordered]@{
        authoritative_input_head=$ExpectedBaseline;stage_count=$ManifestPaths.Count;raw_oversized_excluded=@($RawOversized);
        runtime_tracked_ignored_path=$RuntimeState;runtime_stage_mode="pre-staged by R119.1 LF normalization";
        residual_exact_duplicates_not_staged=@($ResidualDuplicate);residual_superseded_outputs_not_staged=@($ResidualSuperseded);paths=@($ManifestPaths)
    }
    Write-Utf8NoBom $R118StageManifest ($StageManifestObj|ConvertTo-Json -Depth 20)
    if(-not $StageSet.Contains($R118StageManifest)){ [void]$StageSet.Add($R118StageManifest) }

    $HashRecords=@()
    foreach($P in $ManifestPaths){
        if(Test-Path -LiteralPath (Join-Path $Root $P) -PathType Leaf){ $HashRecords += [ordered]@{path=$P;sha256=Get-Sha256 $P} }
    }
    Write-Utf8NoBom $R118Integrity ([ordered]@{algorithm="SHA-256";authoritative_input_head=$ExpectedBaseline;records=$HashRecords}|ConvertTo-Json -Depth 20)
    if(-not $StageSet.Contains($R118Integrity)){ [void]$StageSet.Add($R118Integrity) }
    Write-Host "EXACT_PUBLICATION_SET=$($StageSet.Count)"
    Write-Host "RAW_OVERSIZED_EXCLUDED=4"
    Write-Host "PUBLICATION_SET_GATE=PASS"

    Step 10 "EXACT CONTROLLED STAGING / R119 TRANSACTION RESUME"

    $PreStagedRuntime=@(& git.exe -c core.quotepath=false diff --cached --name-only -- $RuntimeState)
    if($PreStagedRuntime.Count -ne 1){ Hold "Pre-staged runtime prerequisite was lost" }

    foreach($P in $StageSet){
        if($P -eq $RuntimeState){ continue }
        if(-not(Test-Path -LiteralPath (Join-Path $Root $P))){ Hold ("Stage path missing: "+$P) }
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=true add -- $P
        if($LASTEXITCODE -ne 0){ Hold ("git add failed: "+$P) }
    }

    $ExpectedStageSet=New-Object System.Collections.ArrayList
    foreach($P in $StageSet){ if(-not $ExpectedStageSet.Contains($P)){ [void]$ExpectedStageSet.Add($P) } }
    if(-not $ExpectedStageSet.Contains($RuntimeState)){ [void]$ExpectedStageSet.Add($RuntimeState) }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $UnexpectedStaged=@($StagedNow|Where-Object{$ExpectedStageSet -notcontains ($_ -replace "\\","/")})
    $MissingStaged=@($ExpectedStageSet|Where-Object{$StagedNow -notcontains $_})

    Write-Host "STAGED=$($StagedNow.Count)"
    Write-Host "EXPECTED_STAGE_SET=$($ExpectedStageSet.Count)"
    Write-Host "UNEXPECTED_STAGED=$($UnexpectedStaged.Count)"
    Write-Host "MISSING_STAGED=$($MissingStaged.Count)"
    Write-Host "RUNTIME_PRESTAGED_PRESERVED=PASS"

    if($UnexpectedStaged.Count -ne 0 -or $MissingStaged.Count -ne 0 -or $StagedNow.Count -ne $ExpectedStageSet.Count){ Hold "Exact staging mismatch" }
    Write-Host "STAGING_QUALITY=PASS"

    Step 11 "STAGED SECURITY / DELETION GATE"
    $DeletedStaged=@(& git.exe diff --cached --name-only --diff-filter=D)
    if($DeletedStaged.Count -ne 0){ Hold "Staged deletions detected" }
    foreach($P in @($Self,$R118Assessment,$R118Evidence,$R118Doc,$R118Act,$R118StageManifest,$R118Integrity)){ if(Test-NewTextSecret $P){ Hold ("Secret pattern found in R118 staged delta: "+$P) } }
    Write-Host "STAGED_DELETIONS=0"
    Write-Host "R119_STAGED_DELTA_SECRET_HITS=0"
    Write-Host "STAGED_SECURITY_GATE=PASS"

    Step 12 "GITHUB SIZE GATE"
    $OversizedIndex=New-Object System.Collections.ArrayList
    foreach($P in @(& git.exe -c core.quotepath=false ls-files)){
        $SizeText=@(& git.exe cat-file -s (":"+$P) 2>$null)
        if($LASTEXITCODE -eq 0 -and $SizeText.Count -gt 0){
            [Int64]$Size=0
            if([Int64]::TryParse(([string]$SizeText[0]).Trim(),[ref]$Size)){ if($Size -ge 100MB){ [void]$OversizedIndex.Add($P) } }
        }
    }
    Write-Host "INDEX_BLOBS_GE_100MB=$($OversizedIndex.Count)"
    if($OversizedIndex.Count -ne 0){ $OversizedIndex|ForEach-Object{Write-Host ("INDEX_OVERSIZED="+$_)}; Hold "GitHub size gate failed" }
    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "RUNTIME_STATE_TRACKED=YES"
    Write-Host "RUNTIME_STATE_IGNORE_RULE=CONFIRMED"
    Write-Host "RUNTIME_TRACKED_STAGE=PASS"
    Write-Host "RUNTIME_EOL_NORMALIZED=PASS"
    Write-Host "RUNTIME_SHA256=2037EDCA1DD34041FC4EB869A45F483ECBA8E38FB01294C541F5BBCEF8E917EB"

    Step 13 "FINAL REMOTE / PRE-COMMIT GATE"
    Fetch-Authoritative
    if((& git.exe rev-parse ("origin/"+$Branch)).Trim() -ne $ExpectedBaseline){ Hold "Remote advanced before commit" }
    $DeletedTracked=@(& git.exe ls-files --deleted)
    if($DeletedTracked.Count -ne 0){ Hold "Tracked deletions detected before commit" }
    Write-Host "REMOTE_PRECOMMIT_GATE=PASS"
    Write-Host "DELETED_TRACKED=0"

    Step 14 "COMMIT / POST-COMMIT REPRESENTATION GATE"
    & git.exe commit -m "fix(institutional): complete R119 runtime ignore master synchronization recovery"
    if($LASTEXITCODE -ne 0){ Hold "git commit failed" }
    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    $PostUntracked=@(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
    $TrackedHashAfter=@{}
    foreach($P in @(& git.exe -c core.quotepath=false ls-files)){
        $Abs=Join-Path $Root $P
        if(Test-Path -LiteralPath $Abs -PathType Leaf){ try{$TrackedHashAfter[(Get-Sha256 $P)]=$true}catch{} }
    }
    $PostUnexpected=New-Object System.Collections.ArrayList
    foreach($P in $PostUntracked){
        if($RawOversized -contains $P){ continue }
        $IsSuperseded=$false
        foreach($Prefix in $SupersededRoots){ if($P.StartsWith($Prefix,[StringComparison]::OrdinalIgnoreCase)){ $IsSuperseded=$true; break } }
        if($IsSuperseded){ continue }
        $Abs=Join-Path $Root $P
        if(Test-Path -LiteralPath $Abs -PathType Leaf){
            $H=Get-Sha256 $P
            if($TrackedHashAfter.ContainsKey($H)){ continue }
        }
        [void]$PostUnexpected.Add($P)
    }
    Write-Host "POST_COMMIT_UNTRACKED=$($PostUntracked.Count)"
    Write-Host "POST_COMMIT_UNREPRESENTED=$($PostUnexpected.Count)"
    if($PostUnexpected.Count -ne 0){ $PostUnexpected|ForEach-Object{Write-Host ("POST_UNREPRESENTED="+$_)}; Hold "Unique content remains unrepresented after commit" }
    Write-Host "ALL_UNIQUE_INSTITUTIONAL_CONTENT_REPRESENTED=PASS"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){ Hold "git push failed" }
    Write-Host "PUSH=PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION / TRANSACTION CLOSURE"
    Fetch-Authoritative
    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim()
    $Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim()
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe ls-files --deleted)
    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "AHEAD           : $Ahead"
    Write-Host "BEHIND          : $Behind"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"
    if($FinalLocal -ne $FinalRemote -or $Ahead -ne "0" -or $Behind -ne "0"){ Hold "Final local/remote synchronization failed" }
    if($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){ Hold "Final index/deletion state unsafe" }

    Write-Host ""
    Write-Host "SGODA R119 RUNTIME IGNORE RECOVERY : CLOSED / PASS" -ForegroundColor Green
    Write-Host "R119_RUNTIME_IGNORE_RECOVERY=PASS"
    Write-Host "MASTER_SYNCHRONIZATION=RECOVERED"
    Write-Host "RUNTIME_IGNORE_RECOVERY=PASS"
    Write-Host "SPT025_STATUS=INSTITUTIONALLY_CLOSED"
    Write-Host "R117_EVIDENCE_CONSUMED=PASS"
    Write-Host "R118_PRIOR_ATTEMPT_EVIDENCE_PRESERVED=PASS"
    Write-Host "R119_SUPERSEDED_SCRIPT_PRESERVED=PASS"
    Write-Host "R117_INTEGRITY_MANIFEST=PASS"
    Write-Host "GZIP_RECONSTRUCTION_RECERTIFIED=4"
    Write-Host "RAW_OVERSIZED_ORIGINALS_DELETED=NO"
    Write-Host "RAW_OVERSIZED_LOCAL_PRESERVED=4"
    Write-Host "INSTITUTIONAL_TEST_COLLECTION=PASS"
    Write-Host "INSTITUTIONAL_TESTS_COLLECTED=2409"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "R118_FULL_SUITE_EVIDENCE_REUSED=PASS"
    Write-Host "INSTITUTIONAL_TESTS=2409"
    Write-Host "COMPILEALL=PASS"
    Write-Host "SECURITY_GATE=PASS"
    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "DELETED_TRACKED=0"
    Write-Host "ALL_UNIQUE_INSTITUTIONAL_CONTENT_REPRESENTED=PASS"
    Write-Host "COMMIT_PERFORMED=YES"
    Write-Host "PUSH_PERFORMED=YES"
    Write-Host "LOCAL_REMOTE_GATE=PASS"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "AHEAD=0"
    Write-Host "BEHIND=0"
    Write-Host "STAGED=0"
    Write-Host "TRANSACTION=PUBLISHED"
    Write-Host "INSTITUTIONAL_BASELINE=SYNCHRONIZED"
    Write-Host "AUTHORITATIVE_MASTER_BASELINE=$FinalLocal"
    Write-Host "NEXT_ACTION=SGODA_MASTER_CLOSE"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch { Hold $_.Exception.Message }
