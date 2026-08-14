#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "28ca61560db884ae8803d346130c177924e99316"
$ExpectedHistoricalOutsideScope = 56
$Branch = "feature/SPT-001A-rlb-schema-foundation"

$SelfName = "Invoke-SGODA-Repository-Reconciliation-FINAL-v1.0.2-PS51.ps1"
$RuntimeFile = "artifacts/runtime/sgd002-auto/state.json"
$ArtifactDir = "artifacts/audit/repository-reconciliation-v1.0.0"
$InventoryFile = "$ArtifactDir/reconciliation-inventory.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"
$DocFile = "docs/06_Tecnologia/Repositorio/SGD-Reconciliacion-Institucional-No-Destructiva-v1.0.0.md"

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " REPOSITORY RECONCILIATION : HOLD" -ForegroundColor Red
    Write-Host " REASON                    : $Reason" -ForegroundColor Red
    Write-Host " TRANSACTION               : NOT PUBLISHED" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    exit 1
}
function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Text) -ForegroundColor Cyan
}
function Native {
    param([string]$Exe,[string[]]$NativeArgs=@(),[string]$Label="Native command")
    & $Exe @NativeArgs
    if($LASTEXITCODE -ne 0){ throw "$Label failed with exit code $LASTEXITCODE." }
}
function Git-Fetch-With-Retry {
    param([string]$Remote="origin",[string]$Ref="",[int]$Attempts=4)
    $Delays=@(3,7,15,25); $LastMessage=""
    for($i=1;$i -le $Attempts;$i++){
        Write-Host ("GIT FETCH ATTEMPT : {0}/{1}" -f $i,$Attempts)
        $FetchArgs=@("fetch","--prune",$Remote)
        if(-not [string]::IsNullOrWhiteSpace($Ref)){ $FetchArgs += $Ref }

        $PreviousEap=$ErrorActionPreference
        try{
            $ErrorActionPreference="Continue"
            $Output=@(& git.exe @FetchArgs 2>&1)
            $Code=$LASTEXITCODE
        } finally {
            $ErrorActionPreference=$PreviousEap
        }

        if($Output.Count -gt 0){
            $Output|ForEach-Object{Write-Host ([string]$_)}
            $LastMessage=(($Output|ForEach-Object{[string]$_}) -join " | ")
        }
        if($Code -eq 0){ Write-Host "GIT FETCH : PASS"; return }
        if($i -lt $Attempts){
            $Delay=$Delays[[Math]::Min($i-1,$Delays.Count-1)]
            Write-Host ("GIT FETCH TEMPORARY FAILURE : retry in {0}s" -f $Delay) -ForegroundColor Yellow
            Start-Sleep -Seconds $Delay
        }
    }
    throw "GitHub connectivity unavailable after $Attempts attempts. Repository was not modified. Last error: $LastMessage"
}
function PythonExe {
    foreach($p in @(".venv\Scripts\python.exe","venv\Scripts\python.exe")){
        if(Test-Path -LiteralPath $p){ return (Resolve-Path $p).Path }
    }
    $cmd=Get-Command python.exe -ErrorAction SilentlyContinue
    if($null -ne $cmd){ return $cmd.Source }
    throw "Python executable not found."
}
function Norm {
    param([string]$P)
    if($null -eq $P){return ""}
    return ($P.Trim('"') -replace '\\','/')
}
function Write-Lf {
    param([string]$Path,[string]$Text)
    $parent=Split-Path -Parent $Path
    if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    $utf8=New-Object System.Text.UTF8Encoding($false)
    $canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $canonical.EndsWith("`n")){$canonical+="`n"}
    [IO.File]::WriteAllText((Join-Path $PWD $Path),$canonical,$utf8)
}
function Is-TransactionPath {
    param([string]$P)
    $p=Norm $P
    if($p -eq $SelfName -or $p -eq $InventoryFile -or $p -eq $EvidenceFile -or $p -eq $DocFile){return $true}
    if($p.StartsWith((Norm $ArtifactDir)+"/")){return $true}
    return $false
}
function Is-HistoricalTransactionResidue {
    param([string]$P)
    $p=Norm $P
    if($p -eq "SPT0246-Baseline-Input.zip"){return $true}
    if($p -match '^Invoke-SGODA-SPT0246-(?:Capa1-FINAL|R1-SECURITY-CERTIFY)-v[0-9]+\.[0-9]+\.[0-9]+-PS51\.ps1$'){return $true}
    if($p -match '^Invoke-SGODA-SPT0247-(?:Capa1-FINAL|R1-SECURITY-CERTIFY)-v[0-9]+\.[0-9]+\.[0-9]+-PS51\.ps1$'){return $true}

    # Previous failed/held repository-reconciliation masters belong to the
    # reconciliation transaction itself. They are preserved locally but are
    # excluded from the historical outside-scope count, exactly like previous
    # SPT-024.6/024.7 failed masters.
    if($p -match '^Invoke-SGODA-Repository-Reconciliation-FINAL-v[0-9]+\.[0-9]+\.[0-9]+-PS51\.ps1$'){return $true}

    return $false
}
function StatusRecords {
    $records=@()
    $lines=@(& git.exe -c core.quotepath=false status --porcelain=v1 --untracked-files=all)
    if($LASTEXITCODE -ne 0){throw "Unable to inspect worktree."}
    foreach($line in $lines){
        if([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4){continue}
        $xy=$line.Substring(0,2); $path=$line.Substring(3)
        if($path -match ' -> '){$path=($path -split ' -> ')[-1]}
        $records += [pscustomobject]@{XY=$xy;Path=(Norm $path)}
    }
    return @($records)
}
function Finger {
    param([string]$P)
    $native=$P -replace '/',[IO.Path]::DirectorySeparatorChar
    if(-not(Test-Path -LiteralPath $native)){return "MISSING"}
    $item=Get-Item -LiteralPath $native -Force
    if($item.PSIsContainer){return "DIRECTORY"}
    return (Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToUpperInvariant()
}
function Is-ExplicitLocalResidue {
    param([string]$P)
    $p=(Norm $P).ToLowerInvariant()
    if($p -match '(^|/)(backup|backups|repository-backup|tmp|temp|cache)(/|$)'){return $true}
    if($p -match '(^|/)robocopy/.+\.log$'){return $true}
    if($p -match '\.(tmp|bak|old|orig|rej|swp)$'){return $true}
    if($p -match '\s\([0-9]+\)\.ps1$'){return $true}
    if($p -match '(^|/)(transfer-|prepare-|certify-).+\.ps1$'){return $true}
    return $false
}
function Is-InstitutionalCandidate {
    param([string]$P)
    $p=Norm $P; $low=$p.ToLowerInvariant()
    if(Is-ExplicitLocalResidue $p){return $false}
    if($low -match '^(docs|config|src|tests|tools|releases)/'){return $true}
    if($low -match '^artifacts/(audit|development|pmo|publication|consolidation)/'){return $true}
    if($low -match '^[^/]+\.ps1$'){return $true}
    return $false
}
function Test-SafeTextCandidate {
    param([string]$P)

    $native=$P -replace '/',[IO.Path]::DirectorySeparatorChar
    if(-not(Test-Path -LiteralPath $native -PathType Leaf)){
        return [pscustomobject]@{
            safe=$false
            reason="FILE_NOT_FOUND"
            secret_markers=0
            review_required=$true
            findings=@()
        }
    }

    $ext=[IO.Path]::GetExtension($native).ToLowerInvariant()
    $textExtensions=@(".ps1",".py",".md",".txt",".json",".yml",".yaml",".toml",".ini",".cfg",".conf",".xml",".sql",".csv",".properties",".lock")

    if($textExtensions -notcontains $ext){
        return [pscustomobject]@{
            safe=$true
            reason="BINARY_OR_NON_TEXT_NO_CONTENT_SCAN"
            secret_markers=0
            review_required=$false
            findings=@()
        }
    }

    try{
        $lines=[IO.File]::ReadAllLines((Resolve-Path -LiteralPath $native).Path,[Text.Encoding]::UTF8)
    } catch {
        return [pscustomobject]@{
            safe=$false
            reason="TEXT_READ_FAILED"
            secret_markers=0
            review_required=$true
            findings=@()
        }
    }

    $Findings=New-Object System.Collections.ArrayList

    $Rules=@(
        [pscustomobject]@{
            id="PRIVATE_KEY_MARKER"
            pattern='-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
            severity="CRITICAL"
        },
        [pscustomobject]@{
            id="AWS_ACCESS_KEY"
            pattern='\bAKIA[0-9A-Z]{16}\b'
            severity="CRITICAL"
        },
        [pscustomobject]@{
            id="GITHUB_TOKEN"
            pattern='(?i)\bgh[pousr]_[A-Za-z0-9_]{20,}\b'
            severity="CRITICAL"
        },
        [pscustomobject]@{
            id="ASSIGNED_SECRET"
            pattern='(?i)\b(api[_-]?key|secret|token|password|passwd|client[_-]?secret)\b\s*[:=]\s*["''][^"'']{8,}["'']'
            severity="WARNING"
        }
    )

    for($i=0;$i -lt $lines.Count;$i++){
        $line=[string]$lines[$i]

        foreach($rule in $Rules){
            if($line -notmatch $rule.pattern){ continue }

            $trim=$line.Trim()
            $low=$trim.ToLowerInvariant()

            # Automatic false-positive contexts:
            # - regex definitions / detector source code
            # - documentation/examples/placeholders/tests
            # - explicit redacted or dummy values
            $isDetectorSource = (
                $low -match 'pattern\s*=' -or
                $low -match '\[regex\]' -or
                $low -match 're\.compile' -or
                $low -match 'secret_patterns' -or
                $low -match 'rules\s*='
            )

            $isExampleContext = (
                $low -match 'example|dummy|placeholder|not[_ -]?real|fake|redacted|masked|sample|test[_ -]?only' -or
                $low -match '\$\{[{]?\s*secrets\.' -or
                $low -match 'string\.fromenvironment' -or
                $low -match 'getenv|environment::getenvironmentvariable'
            )

            $disposition="REVIEW_REQUIRED"
            if($isDetectorSource -or $isExampleContext){
                $disposition="FALSE_POSITIVE"
            }
            elseif($rule.id -eq "ASSIGNED_SECRET"){
                # Generic assignments remain review-required unless clearly
                # detector/example code; never auto-certify an unknown value.
                $disposition="REVIEW_REQUIRED"
            }
            else {
                $disposition="CONFIRMED_RISK"
            }

            $fingerMaterial=("{0}|{1}|{2}|{3}" -f (Norm $P),($i+1),$rule.id,$trim)
            $sha=[Security.Cryptography.SHA256]::Create()
            try{
                $bytes=[Text.Encoding]::UTF8.GetBytes($fingerMaterial)
                $fp=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").Substring(0,24)
            } finally {
                $sha.Dispose()
            }

            [void]$Findings.Add([ordered]@{
                path=(Norm $P)
                line=($i+1)
                detector=$rule.id
                fingerprint=$fp
                disposition=$disposition
                severity=$rule.severity
                value_exposed=$false
            })
        }
    }

    $Confirmed=@($Findings|Where-Object{$_.disposition -eq "CONFIRMED_RISK"})
    $Review=@($Findings|Where-Object{$_.disposition -eq "REVIEW_REQUIRED"})
    $FalsePositive=@($Findings|Where-Object{$_.disposition -eq "FALSE_POSITIVE"})

    if($Confirmed.Count -gt 0){
        return [pscustomobject]@{
            safe=$false
            reason="CONFIRMED_SECRET_RISK"
            secret_markers=$Findings.Count
            review_required=$false
            findings=@($Findings)
            confirmed_risks=$Confirmed.Count
            false_positives=$FalsePositive.Count
            review_count=$Review.Count
        }
    }

    if($Review.Count -gt 0){
        return [pscustomobject]@{
            safe=$false
            reason="SECRET_LIKE_CONTENT_REQUIRES_REVIEW"
            secret_markers=$Findings.Count
            review_required=$true
            findings=@($Findings)
            confirmed_risks=0
            false_positives=$FalsePositive.Count
            review_count=$Review.Count
        }
    }

    return [pscustomobject]@{
        safe=$true
        reason=($(if($Findings.Count -gt 0){"FALSE_POSITIVE_CERTIFIED"}else{"SAFE_STATIC_CONTENT_SCAN"}))
        secret_markers=$Findings.Count
        review_required=$false
        findings=@($Findings)
        confirmed_risks=0
        false_positives=$FalsePositive.Count
        review_count=0
    }
}

function Test-PowerShellSyntax {
    param([string]$P)
    $native=$P -replace '/',[IO.Path]::DirectorySeparatorChar
    if([IO.Path]::GetExtension($native).ToLowerInvariant() -ne ".ps1"){
        return [pscustomobject]@{passed=$true;errors=0}
    }
    $tokens=$null; $errors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $native).Path,[ref]$tokens,[ref]$errors)
    return [pscustomobject]@{passed=($errors.Count -eq 0);errors=$errors.Count}
}
function Build-TrackedHashIndex {
    $index=@{}
    $tracked=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate tracked files for duplicate detection."}
    foreach($rel in $tracked){
        $p=Norm $rel; $native=$p -replace '/',[IO.Path]::DirectorySeparatorChar
        if(-not(Test-Path -LiteralPath $native -PathType Leaf)){continue}
        try{
            $hash=(Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToUpperInvariant()
            if(-not $index.ContainsKey($hash)){$index[$hash]=New-Object System.Collections.ArrayList}
            [void]$index[$hash].Add($p)
        }catch{continue}
    }
    return $index
}

try {
    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    if(-not(Test-Path -LiteralPath ".git")){Stop-Hold "Execute from official repository root."}

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $LocalHead=(& git.exe rev-parse HEAD).Trim()
    $RemoteHead=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Staged=@(& git.exe diff --cached --name-only)
    $Deleted=@(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if($LocalHead -ne $ExpectedBaseline){Stop-Hold "Unexpected local baseline. Expected $ExpectedBaseline; found $LocalHead."}
    if($RemoteHead -ne $ExpectedBaseline){Stop-Hold "Unexpected remote baseline. Expected $ExpectedBaseline; found $RemoteHead."}
    if($Staged.Count -ne 0){Stop-Hold "Pre-existing staged changes detected."}
    if($Deleted.Count -ne 0){Stop-Hold "Tracked deletions detected."}

    Write-Host "BASELINE : PASS"
    Write-Host "REMOTE CONNECTIVITY RETRY : ACTIVE"
    Write-Host "DESTRUCTIVE CLEANUP : NO"
    Write-Host "SAFE SECRET CLASSIFIER : v1.0.1 CONTEXT-AWARE"
    Write-Host "RECONCILIATION RESIDUE ACCOUNTING : v1.0.2 ACTIVE"

    Step 2 "PREEXISTING WORKTREE INVENTORY"
    $AllStatus=@(StatusRecords)
    $Historical=@(
        $AllStatus|Where-Object{
            $p=Norm $_.Path
            $p -ne $RuntimeFile -and -not(Is-TransactionPath $p) -and -not(Is-HistoricalTransactionResidue $p)
        }
    )

    $ReconciliationResidues=@(
        $AllStatus | Where-Object {
            $p=Norm $_.Path
            $p -match '^Invoke-SGODA-Repository-Reconciliation-FINAL-v[0-9]+\.[0-9]+\.[0-9]+-PS51\.ps1$' -and
            $p -ne $SelfName
        }
    )

    Write-Host "TOTAL WORKTREE ITEMS             : $($AllStatus.Count)"
    Write-Host "RECONCILIATION MASTER RESIDUES   : $($ReconciliationResidues.Count)"
    Write-Host "HISTORICAL OUTSIDE-SCOPE ITEMS   : $($Historical.Count)"
    Write-Host "EXPECTED HISTORICAL ITEMS        : $ExpectedHistoricalOutsideScope"

    if($Historical.Count -ne $ExpectedHistoricalOutsideScope){
        Stop-Hold "Historical outside-scope count changed. Expected $ExpectedHistoricalOutsideScope; found $($Historical.Count)."
    }

    Step 3 "SHA-256 FREEZE OF ALL HISTORICAL ITEMS"
    $HistoricalSnapshot=@{}
    foreach($record in $Historical){
        $p=Norm $record.Path
        $HistoricalSnapshot[$p]=[ordered]@{status=[string]$record.XY;sha256=(Finger $p)}
    }
    Write-Host "HISTORICAL SNAPSHOT : ESTABLISHED"
    Write-Host "HISTORICAL ITEMS    : $($HistoricalSnapshot.Count)"

    Step 4 "TRACKED / UNTRACKED / MODIFIED CLASSIFICATION"
    $TrackedModified=@(); $Untracked=@()
    foreach($record in $Historical){
        $p=Norm $record.Path
        if($record.XY -eq "??"){$Untracked += $p}else{$TrackedModified += $p}
    }
    Write-Host "TRACKED MODIFIED ITEMS : $($TrackedModified.Count)"
    Write-Host "UNTRACKED ITEMS        : $($Untracked.Count)"

    Step 5 "DUPLICATE DETECTION BY SHA-256"
    $TrackedHashIndex=Build-TrackedHashIndex
    $DuplicateMap=@{}
    foreach($p in $Untracked){
        $hash=Finger $p
        if($hash -ne "MISSING" -and $TrackedHashIndex.ContainsKey($hash)){
            $DuplicateMap[$p]=@($TrackedHashIndex[$hash])
        }
    }
    Write-Host "EXACT DUPLICATE UNTRACKED ITEMS : $($DuplicateMap.Count)"

    Step 6 "INSTITUTIONAL / LOCAL-RESIDUE POLICY CLASSIFICATION"
    $Classifications=New-Object System.Collections.ArrayList
    $CandidatePaths=New-Object System.Collections.ArrayList
    $ExcludedPaths=New-Object System.Collections.ArrayList
    $DuplicatePaths=New-Object System.Collections.ArrayList

    foreach($record in $Historical){
        $p=Norm $record.Path
        $kind=""; $publish=$false; $reason=""

        if($DuplicateMap.ContainsKey($p)){
            $kind="EXACT_DUPLICATE"; $reason="Same SHA-256 already exists in tracked repository."
            [void]$DuplicatePaths.Add($p)
        } elseif(Is-ExplicitLocalResidue $p){
            $kind="LOCAL_RESIDUE_PRESERVE_NO_PUBLISH"
            $reason="Backup/temp/transfer/certification residue retained locally but excluded from canonical publication."
            [void]$ExcludedPaths.Add($p)
        } elseif(Is-InstitutionalCandidate $p){
            if($record.XY -eq "??"){$kind="UNTRACKED_INSTITUTIONAL_CANDIDATE"}else{$kind="TRACKED_INSTITUTIONAL_MODIFICATION"}
            $reason="Institutional path eligible for controlled reconciliation."
            $publish=$true
            [void]$CandidatePaths.Add($p)
        } else {
            $kind="UNCLASSIFIED_LOCAL_ITEM"
            $reason="Not in automatic publication whitelist; preserve locally and report."
            [void]$ExcludedPaths.Add($p)
        }

        [void]$Classifications.Add([ordered]@{
            path=$p;git_status=[string]$record.XY;sha256=[string]$HistoricalSnapshot[$p].sha256;
            classification=$kind;auto_publish_candidate=$publish;reason=$reason
        })
    }

    Write-Host "AUTO-PUBLISH CANDIDATES : $($CandidatePaths.Count)"
    Write-Host "DUPLICATES NO-PUBLISH   : $($DuplicatePaths.Count)"
    Write-Host "LOCAL/UNCLASSIFIED HOLD : $($ExcludedPaths.Count)"

    Step 7 "SAFE SECRET / SENSITIVE CONTENT GATE"
    $BlockedCandidates=New-Object System.Collections.ArrayList
    $SafeCandidates=New-Object System.Collections.ArrayList
    $AllSensitiveFindings=New-Object System.Collections.ArrayList
    $FalsePositiveCount=0
    $ConfirmedRiskCount=0
    $ReviewRequiredCount=0

    foreach($p in $CandidatePaths){
        $scan=Test-SafeTextCandidate $p

        foreach($f in @($scan.findings)){
            [void]$AllSensitiveFindings.Add($f)
        }

        if($scan.PSObject.Properties.Name -contains "false_positives"){
            $FalsePositiveCount += [int]$scan.false_positives
        }
        if($scan.PSObject.Properties.Name -contains "confirmed_risks"){
            $ConfirmedRiskCount += [int]$scan.confirmed_risks
        }
        if($scan.PSObject.Properties.Name -contains "review_count"){
            $ReviewRequiredCount += [int]$scan.review_count
        }

        if(-not $scan.safe){
            [void]$BlockedCandidates.Add([ordered]@{
                path=$p
                reason=$scan.reason
                secret_markers=$scan.secret_markers
                review_required=$scan.review_required
                findings=@($scan.findings)
            })
            continue
        }

        [void]$SafeCandidates.Add($p)
    }

    Write-Host "SAFE CANDIDATES             : $($SafeCandidates.Count)"
    Write-Host "FALSE POSITIVES CERTIFIED   : $FalsePositiveCount"
    Write-Host "CONFIRMED RISKS             : $ConfirmedRiskCount"
    Write-Host "REVIEW REQUIRED             : $ReviewRequiredCount"
    Write-Host "BLOCKED CANDIDATE FILES     : $($BlockedCandidates.Count)"
    Write-Host "SECRET VALUES PRINTED       : NO"

    if($BlockedCandidates.Count -gt 0){
        New-Item -ItemType Directory -Force -Path $ArtifactDir|Out-Null

        $PreReport=[ordered]@{
            status="RECONCILIATION_HOLD"
            baseline=$ExpectedBaseline
            generated_utc=[DateTime]::UtcNow.ToString("o")
            historical_items=$Historical.Count
            candidate_count=$CandidatePaths.Count
            safe_candidates=$SafeCandidates.Count
            false_positives=$FalsePositiveCount
            confirmed_risks=$ConfirmedRiskCount
            review_required=$ReviewRequiredCount
            blocked_candidate_files=$BlockedCandidates.Count
            findings=@($AllSensitiveFindings)
            blocked_candidates=@($BlockedCandidates)
            secret_values_exposed=$false
        }

        Write-Lf $InventoryFile ($PreReport|ConvertTo-Json -Depth 15)

        Write-Host ""
        Write-Host "SAFE FINDING SUMMARY (NO VALUES)" -ForegroundColor Yellow
        foreach($f in $AllSensitiveFindings){
            if($f.disposition -ne "FALSE_POSITIVE"){
                Write-Host ("  PATH={0} LINE={1} DETECTOR={2} FINGERPRINT={3} DISPOSITION={4} SEVERITY={5}" -f `
                    $f.path,$f.line,$f.detector,$f.fingerprint,$f.disposition,$f.severity)
            }
        }

        if($ConfirmedRiskCount -gt 0){
            Stop-Hold "Confirmed secret risk detected. Safe metadata was recorded; no value was exposed and no publication occurred."
        }

        Stop-Hold "Secret-like candidate requires review. Safe metadata was recorded; no value was exposed and no publication occurred."
    }

    Write-Host "SENSITIVE CONTENT GATE : PASS"

    Step 8 "POWERSHELL SYNTAX GATE FOR CANDIDATE SCRIPTS"
    $InvalidPowerShell=New-Object System.Collections.ArrayList
    foreach($p in $SafeCandidates){
        if([IO.Path]::GetExtension($p).ToLowerInvariant() -ne ".ps1"){continue}
        $syntax=Test-PowerShellSyntax $p
        if(-not $syntax.passed){[void]$InvalidPowerShell.Add([ordered]@{path=$p;parser_errors=$syntax.errors})}
    }
    Write-Host "POWERSHELL CANDIDATE ERRORS : $($InvalidPowerShell.Count)"
    if($InvalidPowerShell.Count -gt 0){Stop-Hold "Candidate PowerShell files contain parser errors. No reconciliation was published."}

    Step 9 "RECONCILIATION INVENTORY + EVIDENCE GENERATION"
    New-Item -ItemType Directory -Force -Path $ArtifactDir|Out-Null

    $Inventory=[ordered]@{
        component="Repository Institutional Reconciliation";version="1.0.0";status="READY_FOR_CONTROLLED_RECONCILIATION";
        generated_utc=[DateTime]::UtcNow.ToString("o");authoritative_baseline=$ExpectedBaseline;
        historical_outside_scope_items=$Historical.Count;tracked_modified_items=$TrackedModified.Count;untracked_items=$Untracked.Count;
        exact_duplicates=$DuplicatePaths.Count;auto_publish_candidates=$SafeCandidates.Count;preserved_no_publish_items=$ExcludedPaths.Count;
        blocked_sensitive_items=0;false_positives_certified=$FalsePositiveCount;classifications=@($Classifications);publish_candidates=@($SafeCandidates);
        duplicate_no_publish=@($DuplicatePaths);preserved_no_publish=@($ExcludedPaths);secret_values_exposed=$false
    }
    Write-Lf $InventoryFile ($Inventory|ConvertTo-Json -Depth 15)

    $Doc=@"
# Reconciliación Institucional No Destructiva del Repositorio

Baseline autoritativa de partida: ``$ExpectedBaseline``.

Este procedimiento identifica y reconcilia artefactos locales pendientes sin borrar ni sobrescribir componentes históricos.

- Elementos históricos detectados: $($Historical.Count)
- Candidatos institucionales seguros: $($SafeCandidates.Count)
- Duplicados exactos: $($DuplicatePaths.Count)
- Preservados sin publicación automática: $($ExcludedPaths.Count)

Política: ningún archivo se elimina; backups y residuos no se publican automáticamente; secretos no se imprimen; duplicados SHA-256 no se vuelven a publicar; toda publicación pasa por pruebas, staging exacto, commit, push y verificación remota.
"@
    Write-Lf $DocFile $Doc
    Write-Host "INVENTORY : CREATED"
    Write-Host "DOCUMENT  : CREATED"

    Step 10 "INSTITUTIONAL TEST SUITE + COMPILEALL"
    $Python=PythonExe
    $env:PYTHONPATH=(Join-Path $PWD "src")
    Native $Python @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"
    Native $Python @("-m","compileall","-q","src") "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 11 "HISTORICAL CONTENT PRESERVATION GATE"
    foreach($p in $HistoricalSnapshot.Keys){
        if((Finger $p) -ne $HistoricalSnapshot[$p].sha256){Stop-Hold "Historical content changed during reconciliation: $p"}
    }
    Write-Host "HISTORICAL CONTENT HASHES : PRESERVED"
    Write-Host "DESTRUCTIVE MUTATIONS      : 0"

    Step 12 "EXACT CONTROLLED STAGING PLAN"
    $StageTargets=New-Object System.Collections.ArrayList
    foreach($p in $SafeCandidates){[void]$StageTargets.Add($p)}
    [void]$StageTargets.Add($SelfName)
    [void]$StageTargets.Add($InventoryFile)
    [void]$StageTargets.Add($DocFile)

    $Evidence=[ordered]@{
        component="Repository Institutional Reconciliation";version="1.0.0";generated_utc=[DateTime]::UtcNow.ToString("o");
        authoritative_baseline=$ExpectedBaseline;historical_items=$Historical.Count;candidates_published=$SafeCandidates.Count;
        duplicates_not_republished=$DuplicatePaths.Count;local_residues_preserved=$ExcludedPaths.Count;
        gates=[ordered]@{remote_baseline="PASS";sha256_inventory="PASS";duplicate_detection="PASS";sensitive_content="PASS";false_positives_certified=$FalsePositiveCount;
            powershell_syntax="PASS";institutional_suite="PASS";compileall="PASS";historical_content_preserved="PASS"};
        publication="PENDING"
    }
    Write-Lf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)
    [void]$StageTargets.Add($EvidenceFile)

    Write-Host "FILES PLANNED FOR STAGING : $($StageTargets.Count)"
    Write-Host "HISTORICAL CANDIDATES     : $($SafeCandidates.Count)"
    Write-Host "RECONCILIATION ARTIFACTS  : 4"

    Step 13 "EXACT CONTROLLED STAGING"
    foreach($target in $StageTargets){
        if(-not(Test-Path -LiteralPath $target)){Stop-Hold "Planned staging target missing: $target"}
        Native "git.exe" @("-c","core.safecrlf=false","add","--",$target) ("git add "+$target)
    }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    if($LASTEXITCODE -ne 0){throw "Unable to inspect controlled staging."}

    $ExpectedSet=@{}
    foreach($p in $StageTargets){$ExpectedSet[(Norm $p)]=$true}

    $Unexpected=@()
    foreach($p in $StagedNow){$n=Norm $p;if(-not $ExpectedSet.ContainsKey($n)){$Unexpected += $n}}
    $Missing=@()
    foreach($p in $ExpectedSet.Keys){if($StagedNow -notcontains $p){$Missing += $p}}

    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "EXPECTED   : $($ExpectedSet.Count)"
    Write-Host "MISSING    : $($Missing.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if($Unexpected.Count -gt 0 -or $Missing.Count -gt 0){
        & git.exe reset
        Stop-Hold "Controlled staging mismatch. Index was safely unstaged."
    }
    Write-Host "STAGING QUALITY : PASS"

    Step 14 "FINAL REMOTE GATE"
    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch
    $LocalBeforePublish=(& git.exe rev-parse HEAD).Trim()
    $RemoteBeforePublish=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    if($LocalBeforePublish -ne $ExpectedBaseline -or $RemoteBeforePublish -ne $ExpectedBaseline){
        & git.exe reset
        Stop-Hold "Authoritative baseline changed before reconciliation publication."
    }
    Write-Host "REMOTE GATE : PASS"

    Step 15 "COMMIT + PUSH"
    Native "git.exe" @("commit","-m","chore(repository): reconcile validated historical institutional artifacts") "git commit"
    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"
    Native "git.exe" @("push","origin",$Branch) "git push"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION"
    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Counts=((& git.exe rev-list --left-right --count (("origin/"+$Branch)+"...HEAD")).Trim() -split '\s+')
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $($Counts[0])"
    Write-Host "AHEAD           : $($Counts[1])"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if($FinalLocal -ne $FinalRemote -or $Counts[0] -ne "0" -or $Counts[1] -ne "0" -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){
        Stop-Hold "Final repository synchronization failed."
    }

    foreach($p in $ExcludedPaths){
        if(-not(Test-Path -LiteralPath $p)){Stop-Hold "Preserved local item disappeared after reconciliation: $p"}
    }

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host " REPOSITORY INSTITUTIONAL RECONCILIATION : CLOSED" -ForegroundColor Green
    Write-Host " HISTORICAL_ITEMS_ANALYZED=$($Historical.Count)" -ForegroundColor Green
    Write-Host " VALIDATED_ITEMS_PUBLISHED=$($SafeCandidates.Count)" -ForegroundColor Green
    Write-Host " DUPLICATES_NOT_REPUBLISHED=$($DuplicatePaths.Count)" -ForegroundColor Green
    Write-Host " LOCAL_RESIDUES_PRESERVED=$($ExcludedPaths.Count)" -ForegroundColor Green
    Write-Host " SECRET_VALUES_EXPOSED=NO" -ForegroundColor Green
    Write-Host " LOCAL_HEAD=REMOTE_HEAD" -ForegroundColor Green
    Write-Host " FINAL_RECONCILIATION_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    exit 0
}
catch { Stop-Hold $_.Exception.Message }
