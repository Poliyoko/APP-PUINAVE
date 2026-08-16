#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "5e3fd09e8079bbaec2c38ff495049418008b2a29"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$Version = "1.0.0"
$Self = "SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE.ps1"

$FastExecDir = "artifacts/development/SGODA-FASTPATH-EXECUTION-v1.0.0"
$PostDir = "artifacts/development/SGODA-FASTPATH-POSTEXEC-CERTIFY-v1.0.0"
$CloseDir = "artifacts/development/SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE-v1.0.0"

$FinalInventory = "$FastExecDir/global-deliverable-inventory-fastpath-final.json"
$FinalStatus = "$FastExecDir/global-deliverable-status-matrix-fastpath-final.json"
$FinalNext = "$FastExecDir/next-technological-deliverable-assessment-fastpath-final.json"
$FastExecLedger = "$FastExecDir/fastpath-execution-ledger.json"
$FastExecAssessment = "$FastExecDir/fastpath-execution-assessment.json"
$FastExecManifest = "$FastExecDir/fastpath-execution-sha256-manifest.json"

$PostAssessment = "$PostDir/fastpath-postexec-certification-assessment.json"
$PostLedger = "$PostDir/fastpath-postexec-certification-ledger.json"
$PostEvidence = "$PostDir/implementation-evidence.json"
$PostManifest = "$PostDir/fastpath-postexec-certification-sha256-manifest.json"
$PostDoc = "docs/00_Estado_Maestro/SGODA-FASTPATH-POSTEXEC-CERTIFICATION-v1.0.0.md"
$PostActa = "docs/00_Estado_Maestro/ACT-SGODA-FASTPATH-POSTEXEC-CERTIFICATION-v1.0.0.md"
$PostScript = "SGODA-FASTPATH-POSTEXEC-CERTIFY.ps1"

$CloseAssessment = "$CloseDir/final-global-deliverable-map-close-assessment.json"
$CloseLedger = "$CloseDir/final-global-deliverable-map-close-ledger.json"
$CloseEvidence = "$CloseDir/implementation-evidence.json"
$CloseManifest = "$CloseDir/final-global-deliverable-map-close-sha256-manifest.json"
$CloseDoc = "docs/00_Estado_Maestro/SGODA-PUINAVE-Cierre-Final-Mapa-Global-Entregables-v1.0.0.md"
$CloseActa = "docs/00_Estado_Maestro/ACT-SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE-v1.0.0.md"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "TRANSACTION : NOT PUBLISHED"
    exit 1
}

function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Text) -ForegroundColor Cyan
}

function Fetch {
    for($I=1;$I -le 4;$I++){
        Write-Host ("GIT FETCH ATTEMPT : {0}/4" -f $I)
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){
            Write-Host "GIT FETCH : PASS"
            return
        }
        Start-Sleep -Seconds ([Math]::Min(2*$I,8))
    }
    Hold "git fetch failed after 4 attempts"
}

function ReadJson {
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

function WriteLf {
    param([string]$Path,[string]$Text)
    $Full=Join-Path $Root $Path
    $Parent=Split-Path -Parent $Full
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    [IO.File]::WriteAllText($Full,$Canonical,$Utf8)
}

function Sha {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){
        Hold ("Missing file for SHA256: "+$Path)
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Test-SecretPattern {
    param([string]$Path)
    $Ext=[IO.Path]::GetExtension($Path).ToLowerInvariant()
    if(@(".ps1",".psm1",".psd1",".py",".json",".md",".txt",".yml",".yaml",".toml",".ini",".cfg") -notcontains $Ext){
        return $false
    }
    try {
        $Text=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path,[Text.Encoding]::UTF8)
    }
    catch { return $false }

    $Patterns=@(
        '-----BEGIN[ ]+(RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
        '(?i)\b(password|passwd|pwd)\s*[:=]\s*["''][^"'']{8,}["'']',
        '(?i)\b(api[_-]?key|secret[_-]?key|access[_-]?token)\s*[:=]\s*["''][^"'']{12,}["'']'
    )
    foreach($Rx in $Patterns){
        if($Text -match $Rx){ return $true }
    }
    return $false
}

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root){ Hold "Not inside Git repository" }
    Set-Location $Root

    Step 1 "AUTHORITATIVE POST-FASTPATH BASELINE / REMOTE SAFETY"
    Fetch

    $Local=(& git.exe rev-parse HEAD).Trim()
    $Remote=(& git.exe rev-parse "origin/$Branch").Trim()
    $AB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    $Staged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Modified=@(& git.exe -c core.quotepath=false diff --name-only)
    $Deleted=@(& git.exe ls-files --deleted)

    Write-Host "EXPECTED HEAD    : $ExpectedBaseline"
    Write-Host "LOCAL HEAD       : $Local"
    Write-Host "REMOTE HEAD      : $Remote"
    Write-Host "AHEAD            : $([int]$AB[0])"
    Write-Host "BEHIND           : $([int]$AB[1])"
    Write-Host "STAGED           : $($Staged.Count)"
    Write-Host "MODIFIED TRACKED : $($Modified.Count)"
    Write-Host "DELETED TRACKED  : $($Deleted.Count)"

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){ Hold "Authoritative baseline mismatch" }
    if([int]$AB[0] -ne 0 -or [int]$AB[1] -ne 0){ Hold "Local/remote divergence" }
    if($Staged.Count -ne 0 -or $Modified.Count -ne 0 -or $Deleted.Count -ne 0){ Hold "Tracked baseline is not clean" }

    Write-Host "BASELINE_GATE=PASS"
    Write-Host "LOCAL_REMOTE_GATE=PASS"

    Step 2 "CONSUME FASTPATH FINAL MAP"
    foreach($F in @($FinalInventory,$FinalStatus,$FinalNext,$FastExecLedger,$FastExecAssessment,$FastExecManifest)){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){ Hold ("FASTPATH final artifact missing: "+$F) }
    }

    $StatusObj=ReadJson $FinalStatus
    $NextObj=ReadJson $FinalNext
    $ExecAssessmentObj=ReadJson $FastExecAssessment

    $Pending=@($StatusObj.pending_spt_candidates)
    if($Pending.Count -ne 0){ Hold "FASTPATH final map still has pending SPT candidates" }
    if([string]$NextObj.decision -ne "NO_EXISTING_PENDING_DELIVERABLE"){ Hold "Final map decision is not NO_EXISTING_PENDING_DELIVERABLE" }
    if([string]$NextObj.next_action -ne "FINAL_GLOBAL_DELIVERABLE_MAP_CLOSE"){ Hold "Final map does not authorize final global map close" }

    Write-Host "FASTPATH_FINAL_MAP=PASS"
    Write-Host "PENDING_SPT_CANDIDATES=0"
    Write-Host "NEXT_DELIVERABLE_DECISION=NO_EXISTING_PENDING_DELIVERABLE"

    Step 3 "CONSUME POSTEXEC CERTIFICATION"
    $PostFiles=@(
        $PostScript,$PostAssessment,$PostLedger,$PostEvidence,$PostManifest,$PostDoc,$PostActa
    )
    foreach($F in $PostFiles){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){ Hold ("POSTEXEC certification output missing: "+$F) }
    }

    $PostAssessmentObj=ReadJson $PostAssessment
    if([string]$PostAssessmentObj.status -ne "PASS"){ Hold "POSTEXEC certification status is not PASS" }
    if([int]$PostAssessmentObj.candidates_processed -ne 27){ Hold "POSTEXEC candidates_processed is not 27" }
    if([int]$PostAssessmentObj.already_closed_reconciled -ne 21){ Hold "POSTEXEC already_closed_reconciled is not 21" }
    if([int]$PostAssessmentObj.formalized_and_reconciled -ne 6){ Hold "POSTEXEC formalized_and_reconciled is not 6" }
    if([int]$PostAssessmentObj.incomplete -ne 0){ Hold "POSTEXEC incomplete is not 0" }
    if([int]$PostAssessmentObj.pending_after -ne 0){ Hold "POSTEXEC pending_after is not 0" }

    Write-Host "POSTEXEC_CERTIFICATION=PASS"
    Write-Host "CANDIDATES_PROCESSED=27"
    Write-Host "ALREADY_CLOSED_RECONCILED=21"
    Write-Host "FORMALIZED_AND_RECONCILED=6"
    Write-Host "INCOMPLETE=0"

    Step 4 "RECERTIFY POSTEXEC SHA-256 MANIFEST"
    $PostManifestObj=ReadJson $PostManifest
    $PostShaFailures=0

    foreach($R in @($PostManifestObj.records)){
        $Path=[string]$R.path
        $Expected=[string]$R.sha256
        if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){
            $PostShaFailures++
            continue
        }
        if((Sha $Path) -ne $Expected.ToUpperInvariant()){
            $PostShaFailures++
        }
    }

    Write-Host "POSTEXEC_SHA256_RECORDS=$(@($PostManifestObj.records).Count)"
    Write-Host "POSTEXEC_SHA256_FAILURES=$PostShaFailures"
    if($PostShaFailures -ne 0){ Hold "POSTEXEC SHA-256 recertification failed" }
    Write-Host "POSTEXEC_SHA256_RECERTIFICATION=PASS"

    Step 5 "RECERTIFY FASTPATH EXECUTION INTEGRITY"
    $FastManifestObj=ReadJson $FastExecManifest
    $FastShaFailures=0
    foreach($R in @($FastManifestObj.records)){
        $Path=[string]$R.path
        $Expected=[string]$R.sha256
        if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){
            $FastShaFailures++
            continue
        }
        if((Sha $Path) -ne $Expected.ToUpperInvariant()){
            $FastShaFailures++
        }
    }

    Write-Host "FASTPATH_SHA256_RECORDS=$(@($FastManifestObj.records).Count)"
    Write-Host "FASTPATH_SHA256_FAILURES=$FastShaFailures"
    if($FastShaFailures -ne 0){ Hold "FASTPATH execution SHA-256 recertification failed" }
    Write-Host "FASTPATH_EXECUTION_INTEGRITY=PASS"

    Step 6 "RECERTIFY NON-DESTRUCTIVE / GITHUB SIZE / SECURITY"
    $CommitChanges=@(& git.exe diff-tree --no-commit-id --name-status -r $ExpectedBaseline)
    $CommitDeletes=@($CommitChanges | Where-Object { $_ -match '^D\s' })

    if($CommitDeletes.Count -ne 0){ Hold "FASTPATH baseline commit contains deletions" }

    $Large=0
    foreach($F in @(& git.exe -c core.quotepath=false ls-files)){
        $SizeText=(& git.exe cat-file -s (":$F") 2>$null)
        if($LASTEXITCODE -eq 0 -and $SizeText -and [int64]$SizeText -ge 100MB){ $Large++ }
    }

    $SecurityHits=0
    foreach($F in $PostFiles){
        if(Test-SecretPattern $F){ $SecurityHits++ }
    }

    Write-Host "FASTPATH_COMMIT_DELETIONS=$($CommitDeletes.Count)"
    Write-Host "INDEX_BLOBS_GE_100MB=$Large"
    Write-Host "POSTEXEC_SECURITY_HITS=$SecurityHits"

    if($Large -ne 0){ Hold "GitHub size gate failed" }
    if($SecurityHits -ne 0){ Hold "Security gate detected secret-like content" }

    Write-Host "DESTRUCTIVE_CLEANUP=NO"
    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "SECURITY_GATE=PASS"

    Step 7 "WRITE FINAL GLOBAL DELIVERABLE MAP CLOSURE"
    $Now=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

    $AssessmentObj=[ordered]@{
        component="SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE"
        version=$Version
        authoritative_input_head=$ExpectedBaseline
        status="INSTITUTIONALLY_CLOSED"
        fastpath_execution_recertified=$true
        total_fastpath_candidates=27
        already_closed_reconciled=21
        formalized_and_reconciled=6
        incomplete=0
        pending_spt_candidates=0
        master_map_reconciliation="PASS"
        postexec_certification_published=$true
        automatic_spt_creation=$false
        destructive_cleanup=$false
        new_functionality=$false
        production_change=$false
        next_action="DETERMINE_NEXT_TECHNOLOGICAL_PHASE"
        generated_at=$Now
    }

    $LedgerObj=[ordered]@{
        component="SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE"
        baseline=$ExpectedBaseline
        source_final_inventory=$FinalInventory
        source_final_status=$FinalStatus
        source_final_next=$FinalNext
        source_fastpath_ledger=$FastExecLedger
        source_postexec_assessment=$PostAssessment
        source_postexec_ledger=$PostLedger
        pending_before=27
        pending_after=0
        candidates_processed=27
        already_closed_reconciled=21
        formalized_and_reconciled=6
        incomplete=0
        result="PASS"
    }

    $EvidenceObj=[ordered]@{
        component="SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE"
        baseline=$ExpectedBaseline
        fastpath_execution_integrity="PASS"
        postexec_sha256_recertification="PASS"
        github_size_gate="PASS"
        security_gate="PASS"
        destructive_cleanup=$false
        postexec_certification_inputs=$PostFiles
    }

    WriteLf $CloseAssessment ($AssessmentObj | ConvertTo-Json -Depth 16)
    WriteLf $CloseLedger ($LedgerObj | ConvertTo-Json -Depth 16)
    WriteLf $CloseEvidence ($EvidenceObj | ConvertTo-Json -Depth 16)

    $CloseDocText=@"
# SGODA-PUINAVE - Cierre Institucional Final del Mapa Global de Entregables v1.0.0

Baseline de entrada: $ExpectedBaseline

## Resultado final

- FASTPATH recertificado: YES
- Candidatos procesados: 27
- Already closed reconciliados: 21
- Formalizados y reconciliados: 6
- Incompletos: 0
- Pendientes SPT: 0
- Reaperturas: 0
- Recreacion de pruebas historicas: NO
- Limpieza destructiva: NO
- Mapa global: CLOSED
- Creacion automatica de nuevo SPT: NO
- Siguiente accion: DETERMINE_NEXT_TECHNOLOGICAL_PHASE
"@
    WriteLf $CloseDoc $CloseDocText

    $CloseActaText=@"
# ACT-SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE-v1.0.0

Se declara institucionalmente cerrado el Mapa Global de Entregables SGODA-PUINAVE.

- Baseline de entrada: $ExpectedBaseline
- FASTPATH execution recertified: YES
- Total candidatos FASTPATH: 27
- Already closed reconciliados: 21
- Formalizados y reconciliados: 6
- Incompletos: 0
- Pendientes SPT: 0
- Master Map Reconciliation: PASS
- POSTEXEC certification published: YES
- Automatic SPT creation: NO
- Destructive cleanup: NO
- New functionality: NO
- Production change: NO
- Next action: DETERMINE_NEXT_TECHNOLOGICAL_PHASE
"@
    WriteLf $CloseActa $CloseActaText

    Write-Host "FINAL_CLOSE_ASSESSMENT=CREATED"
    Write-Host "FINAL_CLOSE_LEDGER=CREATED"
    Write-Host "FINAL_CLOSE_EVIDENCE=CREATED"
    Write-Host "FINAL_CLOSE_DOCUMENT=CREATED"
    Write-Host "FINAL_CLOSE_ACTA=CREATED"

    Step 8 "BUILD EXACT PUBLICATION SET / SHA-256 MANIFEST"
    $Publication=@(
        $Self,
        $PostScript,$PostAssessment,$PostLedger,$PostEvidence,$PostManifest,$PostDoc,$PostActa,
        $CloseAssessment,$CloseLedger,$CloseEvidence,$CloseDoc,$CloseActa
    )

    $Publication=@($Publication | Select-Object -Unique)

    $Records=@()
    foreach($F in $Publication){
        if(-not(Test-Path -LiteralPath $F -PathType Leaf)){ Hold ("Publication file missing: "+$F) }
        $Records += [ordered]@{path=$F;sha256=(Sha $F)}
    }

    $CloseManifestObj=[ordered]@{
        component="SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE"
        version=$Version
        baseline=$ExpectedBaseline
        records=$Records
    }

    WriteLf $CloseManifest ($CloseManifestObj | ConvertTo-Json -Depth 12)
    $Publication += $CloseManifest

    Write-Host "EXACT_PUBLICATION_SET=$($Publication.Count)"
    Write-Host "POSTEXEC_OUTPUTS_INCLUDED=7"
    Write-Host "FINAL_CLOSE_SHA256_MANIFEST=CREATED"

    Step 9 "JSON / EOL / SECURITY QUALITY GATE"
    $JsonFailures=0
    $EolFailures=0
    $SecurityFailures=0

    foreach($F in $Publication){
        $Ext=[IO.Path]::GetExtension($F).ToLowerInvariant()

        if($Ext -eq ".json"){
            try { $null=ReadJson $F } catch { $JsonFailures++ }
        }

        if(Test-SecretPattern $F){ $SecurityFailures++ }

        $Attr=@(& git.exe check-attr eol -- $F)
        $Required=""
        foreach($Line in $Attr){
            if($Line -match ': eol: (.+)$'){ $Required=$Matches[1].Trim().ToLowerInvariant() }
        }

        $Text=""
        try { $Text=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $F).Path,[Text.Encoding]::UTF8) } catch {}

        if($Required -eq "lf"){
            if([regex]::Matches($Text,"`r`n").Count -ne 0){ $EolFailures++ }
        }
        elseif($Required -eq "crlf"){
            $Bare=[regex]::Matches(($Text -replace "`r`n",""),"`n").Count
            if($Bare -ne 0){ $EolFailures++ }
        }
    }

    Write-Host "JSON_FAILURES=$JsonFailures"
    Write-Host "EOL_FAILURES=$EolFailures"
    Write-Host "SECURITY_FAILURES=$SecurityFailures"

    if($JsonFailures -ne 0){ Hold "JSON validation failed" }
    if($EolFailures -ne 0){ Hold "EOL quality gate failed" }
    if($SecurityFailures -ne 0){ Hold "Security quality gate failed" }

    Write-Host "JSON_VALIDATION=PASS"
    Write-Host "OUTPUT_EOL_GATE=PASS"
    Write-Host "OUTPUT_SECURITY_GATE=PASS"

    Step 10 "CLOSED BASELINE PRESERVATION / UNTRACKED ACCOUNTING"
    $ModifiedNow=@(& git.exe -c core.quotepath=false diff --name-only)
    $DeletedNow=@(& git.exe ls-files --deleted)

    if($ModifiedNow.Count -ne 0){ Hold "Tracked baseline changed before staging" }
    if($DeletedNow.Count -ne 0){ Hold "Tracked deletion detected" }

    $CurrentUntracked=@(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
    $Blocking=@($CurrentUntracked | Where-Object {
        $P=($_ -replace "\\","/")
        ($P -match '(?i)FASTPATH-POSTEXEC|FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE') -and
        ($Publication -notcontains $P)
    })

    Write-Host "CURRENT_UNTRACKED=$($CurrentUntracked.Count)"
    Write-Host "BLOCKING_FINAL_CLOSE_UNTRACKED=$($Blocking.Count)"

    if($Blocking.Count -ne 0){
        $Blocking | ForEach-Object { Write-Host ("BLOCKING_UNTRACKED="+$_) }
        Hold "Unexpected final-close content outside publication set"
    }

    Write-Host "CLOSED_BASELINE_PRESERVED=PASS"
    Write-Host "UNTRACKED_ACCOUNTING=PASS"

    Step 11 "EXACT CONTROLLED STAGING"
    foreach($F in $Publication){
        & git.exe -c core.autocrlf=false -c core.safecrlf=true add -- $F
        if($LASTEXITCODE -ne 0){ Hold ("git add failed: "+$F) }
    }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected=@($StagedNow | Where-Object { $Publication -notcontains ($_ -replace "\\","/") })
    $Missing=@($Publication | Where-Object { $StagedNow -notcontains $_ })

    Write-Host "STAGED=$($StagedNow.Count)"
    Write-Host "EXPECTED_STAGE_SET=$($Publication.Count)"
    Write-Host "UNEXPECTED_STAGED=$($Unexpected.Count)"
    Write-Host "MISSING_STAGED=$($Missing.Count)"

    if($Unexpected.Count -ne 0 -or $Missing.Count -ne 0 -or $StagedNow.Count -ne $Publication.Count){
        Hold "Exact staging mismatch"
    }

    Write-Host "STAGING_QUALITY=PASS"

    Step 12 "STAGED DELETION / SIZE / REMOTE PRE-COMMIT GATE"
    $StagedDeletes=@(& git.exe diff --cached --diff-filter=D --name-only)
    if($StagedDeletes.Count -ne 0){ Hold "Staged deletion detected" }

    $LargeIndex=0
    foreach($F in @(& git.exe -c core.quotepath=false ls-files)){
        $SizeText=(& git.exe cat-file -s (":$F") 2>$null)
        if($LASTEXITCODE -eq 0 -and $SizeText -and [int64]$SizeText -ge 100MB){ $LargeIndex++ }
    }

    Write-Host "STAGED_DELETIONS=$($StagedDeletes.Count)"
    Write-Host "INDEX_BLOBS_GE_100MB=$LargeIndex"
    if($LargeIndex -ne 0){ Hold "GitHub size gate failed" }

    Fetch
    $PreLocal=(& git.exe rev-parse HEAD).Trim()
    $PreRemote=(& git.exe rev-parse "origin/$Branch").Trim()

    if($PreLocal -ne $ExpectedBaseline -or $PreRemote -ne $ExpectedBaseline){
        Hold "Remote changed before final-close commit"
    }

    Write-Host "GITHUB_SIZE_GATE=PASS"
    Write-Host "REMOTE_PRECOMMIT_GATE=PASS"

    Step 13 "COMMIT FINAL GLOBAL DELIVERABLE MAP CLOSE"
    & git.exe commit -m "chore(institutional): close final global deliverable map"
    if($LASTEXITCODE -ne 0){ Hold "git commit failed" }

    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"
    Write-Host "COMMIT_PERFORMED=YES"

    Step 14 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){ Hold "git push failed" }
    Write-Host "PUSH=PASS"

    Step 15 "AUTHORITATIVE REMOTE VERIFICATION"
    Fetch

    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse "origin/$Branch").Trim()
    $FinalAB=(& git.exe rev-list --left-right --count "HEAD...origin/$Branch") -split '\s+'
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "AHEAD           : $([int]$FinalAB[0])"
    Write-Host "BEHIND          : $([int]$FinalAB[1])"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if($FinalLocal -ne $FinalRemote){ Hold "Final local/remote mismatch" }
    if([int]$FinalAB[0] -ne 0 -or [int]$FinalAB[1] -ne 0){ Hold "Final divergence detected" }
    if($FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){ Hold "Final repository safety gate failed" }

    Write-Host "FINAL_REMOTE_GATE=PASS"

    Step 16 "FINAL INSTITUTIONAL CLOSURE"
    Write-Host ""
    Write-Host "SGODA-FINAL-GLOBAL-DELIVERABLE-MAP-CLOSE : INSTITUTIONALLY CLOSED / PASS" -ForegroundColor Green
    Write-Host "FASTPATH_EXECUTION_RECERTIFIED=YES"
    Write-Host "TOTAL_FASTPATH_CANDIDATES=27"
    Write-Host "ALREADY_CLOSED_RECONCILED=21"
    Write-Host "FORMALIZED_AND_RECONCILED=6"
    Write-Host "INCOMPLETE=0"
    Write-Host "PENDING_SPT_CANDIDATES=0"
    Write-Host "GLOBAL_DELIVERABLE_MAP_STATUS=CLOSED"
    Write-Host "MASTER_MAP_RECONCILIATION=PASS"
    Write-Host "POSTEXEC_CERTIFICATION_PUBLISHED=YES"
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
    Write-Host "NEXT_ACTION=DETERMINE_NEXT_TECHNOLOGICAL_PHASE"
    Write-Host "FINAL_EXIT_CODE=0"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
