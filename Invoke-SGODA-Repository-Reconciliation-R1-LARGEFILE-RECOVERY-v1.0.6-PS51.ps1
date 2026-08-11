#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$RemoteBaseline = "28ca61560db884ae8803d346130c177924e99316"
$RejectedLocalCommit = "5b0b5b546fc4f936708936a273e61f4cc659b70f"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-Repository-Reconciliation-R1-LARGEFILE-RECOVERY-v1.0.6-PS51.ps1"

$EvidenceRel = "artifacts/audit/repository-reconciliation-v1.0.0/implementation-evidence.json"
$InventoryRel = "artifacts/audit/repository-reconciliation-v1.0.0/reconciliation-inventory.json"
$DocRel = "docs/06_Tecnologia/Repositorio/SGD-Reconciliacion-Institucional-No-Destructiva-v1.0.0.md"

$GitHubLimitBytes = 100MB
$PartMaxBytes = 50MB

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " REPOSITORY RECONCILIATION LARGE-FILE RECOVERY v1.0.6 : HOLD" -ForegroundColor Red
    Write-Host " REASON                                                  : $Reason" -ForegroundColor Red
    Write-Host " REMOTE                                                  : NOT MODIFIED" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    exit 1
}

function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/12] {1}" -f $N,$Text) -ForegroundColor Cyan
}

function Native {
    param([string]$Exe,[string[]]$NativeArgs=@(),[string]$Label="Native command")
    & $Exe @NativeArgs
    if($LASTEXITCODE -ne 0){ throw "$Label failed with exit code $LASTEXITCODE." }
}

function Git-Fetch-With-Retry {
    param([string]$Remote="origin",[string]$Ref="",[int]$Attempts=4)
    $Delays=@(3,7,15,25)
    $LastMessage=""

    for($i=1;$i -le $Attempts;$i++){
        Write-Host ("GIT FETCH ATTEMPT : {0}/{1}" -f $i,$Attempts)

        $FetchArgs=@("fetch","--prune",$Remote)
        if(-not [string]::IsNullOrWhiteSpace($Ref)){ $FetchArgs += $Ref }

        $PreviousEap=$ErrorActionPreference
        try{
            $ErrorActionPreference="Continue"
            $Output=@(& git.exe @FetchArgs 2>&1)
            $Code=$LASTEXITCODE
        }
        finally{
            $ErrorActionPreference=$PreviousEap
        }

        if($Output.Count -gt 0){
            $Output|ForEach-Object{Write-Host ([string]$_)}
            $LastMessage=(($Output|ForEach-Object{[string]$_}) -join " | ")
        }

        if($Code -eq 0){
            Write-Host "GIT FETCH : PASS"
            return
        }

        if($i -lt $Attempts){
            $Delay=$Delays[[Math]::Min($i-1,$Delays.Count-1)]
            Write-Host ("GIT FETCH TEMPORARY FAILURE : retry in {0}s" -f $Delay) -ForegroundColor Yellow
            Start-Sleep -Seconds $Delay
        }
    }

    throw "GitHub connectivity unavailable after $Attempts attempts. Last error: $LastMessage"
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

function Get-HeadOversizedBlobs {
    $result=New-Object System.Collections.ArrayList

    $lines=@(& git.exe -c core.quotepath=false ls-tree -r -l HEAD)
    if($LASTEXITCODE -ne 0){throw "Unable to inspect HEAD tree."}

    foreach($line in $lines){
        if($line -notmatch '^\d+\s+blob\s+([0-9a-f]+)\s+(\d+)\t(.+)$'){continue}

        $sha=$Matches[1]
        [Int64]$size=[Int64]$Matches[2]
        $path=Norm $Matches[3]

        if($size -ge $GitHubLimitBytes){
            [void]$result.Add([ordered]@{
                path=$path
                object_sha=$sha
                bytes=$size
            })
        }
    }

    return @($result)
}

function New-ReconstructableArchive {
    param(
        [string]$SourceRel,
        [Int64]$SourceBytes
    )

    if(-not(Test-Path -LiteralPath $SourceRel -PathType Leaf)){
        throw "Oversized source is not present in working tree: $SourceRel"
    }

    $SourceHash=(Get-FileHash -LiteralPath $SourceRel -Algorithm SHA256).Hash.ToUpperInvariant()

    $parent=Split-Path -Parent $SourceRel
    $leaf=[IO.Path]::GetFileName($SourceRel)
    $archiveRoot=(Norm (Join-Path $parent ($leaf + "-archive")))
    $partsDir="$archiveRoot/parts"
    $gzipRel="$archiveRoot/$leaf.gz"
    $manifestRel="$archiveRoot/manifest.json"

    if(Test-Path -LiteralPath $archiveRoot){
        Remove-Item -LiteralPath $archiveRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $partsDir|Out-Null

    $gzipAbs=Join-Path $PWD $gzipRel
    $sourceAbs=(Resolve-Path -LiteralPath $SourceRel).Path

    $inStream=[IO.File]::OpenRead($sourceAbs)
    try{
        $outStream=[IO.File]::Create($gzipAbs)
        try{
            $gzip=New-Object IO.Compression.GZipStream($outStream,[IO.Compression.CompressionMode]::Compress,$false)
            try{
                $buffer=New-Object byte[] (1024*1024)
                while(($read=$inStream.Read($buffer,0,$buffer.Length)) -gt 0){
                    $gzip.Write($buffer,0,$read)
                }
            }
            finally{$gzip.Dispose()}
        }
        finally{$outStream.Dispose()}
    }
    finally{$inStream.Dispose()}

    $gzipHash=(Get-FileHash -LiteralPath $gzipRel -Algorithm SHA256).Hash.ToUpperInvariant()

    $parts=New-Object System.Collections.ArrayList
    $gzipRead=[IO.File]::OpenRead((Resolve-Path -LiteralPath $gzipRel).Path)
    try{
        $partIndex=1
        $buffer=New-Object byte[] $PartMaxBytes

        while(($read=$gzipRead.Read($buffer,0,$buffer.Length)) -gt 0){
            $partName=("{0}.gz.part{1:D3}" -f $leaf,$partIndex)
            $partRel="$partsDir/$partName"
            $partAbs=Join-Path $PWD $partRel

            $partStream=[IO.File]::Create($partAbs)
            try{$partStream.Write($buffer,0,$read)}
            finally{$partStream.Dispose()}

            $partInfo=Get-Item -LiteralPath $partRel
            $partHash=(Get-FileHash -LiteralPath $partRel -Algorithm SHA256).Hash.ToUpperInvariant()

            if($partInfo.Length -ge $GitHubLimitBytes){
                throw "Generated archive part exceeds GitHub limit: $partRel"
            }

            [void]$parts.Add([ordered]@{
                index=$partIndex
                file=(Norm $partRel)
                bytes=$partInfo.Length
                sha256=$partHash
            })

            $partIndex++
        }
    }
    finally{$gzipRead.Dispose()}

    $rebuiltGz=Join-Path $env:TEMP ("sgoda-rebuilt-"+[Guid]::NewGuid().ToString("N")+".gz")
    $rebuiltSource=Join-Path $env:TEMP ("sgoda-rebuilt-"+[Guid]::NewGuid().ToString("N")+".json")

    try{
        $join=[IO.File]::Create($rebuiltGz)
        try{
            foreach($part in $parts){
                $readPart=[IO.File]::OpenRead((Resolve-Path -LiteralPath ([string]$part.file)).Path)
                try{$readPart.CopyTo($join)}
                finally{$readPart.Dispose()}
            }
        }
        finally{$join.Dispose()}

        $rebuiltGzHash=(Get-FileHash -LiteralPath $rebuiltGz -Algorithm SHA256).Hash.ToUpperInvariant()
        if($rebuiltGzHash -ne $gzipHash){
            throw "Rejoined gzip SHA-256 mismatch for $SourceRel"
        }

        $gzIn=[IO.File]::OpenRead($rebuiltGz)
        try{
            $decompress=New-Object IO.Compression.GZipStream($gzIn,[IO.Compression.CompressionMode]::Decompress,$false)
            try{
                $sourceOut=[IO.File]::Create($rebuiltSource)
                try{$decompress.CopyTo($sourceOut)}
                finally{$sourceOut.Dispose()}
            }
            finally{$decompress.Dispose()}
        }
        finally{$gzIn.Dispose()}

        $rebuiltSourceHash=(Get-FileHash -LiteralPath $rebuiltSource -Algorithm SHA256).Hash.ToUpperInvariant()
        if($rebuiltSourceHash -ne $SourceHash){
            throw "Reconstructed source SHA-256 mismatch for $SourceRel"
        }
    }
    finally{
        Remove-Item -LiteralPath $rebuiltGz -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $rebuiltSource -Force -ErrorAction SilentlyContinue
    }

    Remove-Item -LiteralPath $gzipRel -Force

    $manifest=[ordered]@{
        format="SGODA-SPLIT-GZIP-ARCHIVE"
        version="1.0"
        source_path=(Norm $SourceRel)
        source_bytes=$SourceBytes
        source_sha256=$SourceHash
        compression="gzip"
        compressed_sha256=$gzipHash
        part_max_bytes=$PartMaxBytes
        part_count=$parts.Count
        parts=@($parts)
        reconstruction=[ordered]@{
            join_order="ascending part index"
            decompress="gzip"
            expected_source_sha256=$SourceHash
        }
        github_file_limit_mitigation=$true
        original_file_preserved_locally=$true
        reconstruction_verified=$true
        secret_values_exposed=$false
    }

    Write-Lf $manifestRel ($manifest|ConvertTo-Json -Depth 12)

    return [ordered]@{
        source_path=(Norm $SourceRel)
        source_bytes=$SourceBytes
        source_sha256=$SourceHash
        archive_root=(Norm $archiveRoot)
        manifest=(Norm $manifestRel)
        part_count=$parts.Count
        compressed_sha256=$gzipHash
        reconstruction_verified=$true
    }
}

try {
    Step 1 "AUTHORITATIVE RECOVERY STATE / REMOTE SAFETY"

    if(-not(Test-Path -LiteralPath ".git")){
        Stop-Hold "Execute from the official SGODA-PUINAVE repository root."
    }

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $LocalHead=(& git.exe rev-parse HEAD).Trim()
    $RemoteHead=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Staged=@(& git.exe diff --cached --name-only)
    $Deleted=@(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if($LocalHead -ne $RejectedLocalCommit){
        Stop-Hold "Expected rejected local commit $RejectedLocalCommit; found $LocalHead."
    }
    if($RemoteHead -ne $RemoteBaseline){
        Stop-Hold "Remote baseline changed. Expected $RemoteBaseline; found $RemoteHead."
    }
    if($Staged.Count -ne 0){
        Stop-Hold "Unexpected staged changes detected before v1.0.6 recovery."
    }
    if($Deleted.Count -ne 0){
        Stop-Hold "Unexpected tracked working-tree deletions detected."
    }

    Write-Host "RECOVERY STATE : PASS"
    Write-Host "GENERIC HEAD OVERSIZED-BLOB SCAN : ACTIVE"

    Step 2 "SCAN ENTIRE LOCAL HEAD FOR ALL BLOBS >= 100 MB"

    $Oversized=@(Get-HeadOversizedBlobs)

    Write-Host "OVERSIZED BLOBS IN HEAD : $($Oversized.Count)"

    foreach($item in $Oversized){
        Write-Host ("  {0} : {1} bytes" -f $item.path,$item.bytes)
    }

    if($Oversized.Count -eq 0){
        Stop-Hold "No oversized blobs remain in local HEAD; recovery assumptions changed."
    }

    Step 3 "PRESERVE ORIGINALS + REMOVE OVERSIZED PATHS FROM INDEX"

    $OriginalHashes=@{}

    foreach($item in $Oversized){
        $p=[string]$item.path

        if(-not(Test-Path -LiteralPath $p -PathType Leaf)){
            Stop-Hold "Oversized source is missing from working tree: $p"
        }

        $hash=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpperInvariant()
        $OriginalHashes[$p]=$hash

        Native "git.exe" @("rm","--cached","--",$p) ("git rm --cached "+$p)

        if(-not(Test-Path -LiteralPath $p -PathType Leaf)){
            Stop-Hold "Original oversized source disappeared after untracking: $p"
        }

        Write-Host ("PRESERVED LOCAL / UNTRACKED : {0}" -f $p)
    }

    Step 4 "CREATE VERIFIED RECONSTRUCTABLE ARCHIVES FOR ALL OVERSIZED SOURCES"

    $ArchiveRecords=New-Object System.Collections.ArrayList

    foreach($item in $Oversized){
        $record=New-ReconstructableArchive -SourceRel ([string]$item.path) -SourceBytes ([Int64]$item.bytes)
        [void]$ArchiveRecords.Add($record)

        Write-Host ("ARCHIVE VERIFIED : {0}" -f $record.source_path)
        Write-Host ("  MANIFEST       : {0}" -f $record.manifest)
        Write-Host ("  PARTS          : {0}" -f $record.part_count)
    }

    Step 5 "UPDATE RECONCILIATION EVIDENCE / INVENTORY / DOCUMENTATION"

    if(Test-Path -LiteralPath $EvidenceRel){
        $E=Get-Content -LiteralPath $EvidenceRel -Raw -Encoding UTF8|ConvertFrom-Json
        $E|Add-Member -NotePropertyName large_file_recovery_v1_0_6 -NotePropertyValue ([ordered]@{
            recovered_files=@($ArchiveRecords)
            github_file_limit_resolved=$true
            all_originals_preserved_locally=$true
            all_reconstructions_verified=$true
            secret_values_exposed=$false
        }) -Force
        Write-Lf $EvidenceRel ($E|ConvertTo-Json -Depth 18)
    }

    if(Test-Path -LiteralPath $InventoryRel){
        $I=Get-Content -LiteralPath $InventoryRel -Raw -Encoding UTF8|ConvertFrom-Json
        $I|Add-Member -NotePropertyName oversized_artifact_archives -NotePropertyValue @($ArchiveRecords) -Force
        Write-Lf $InventoryRel ($I|ConvertTo-Json -Depth 20)
    }

    if(Test-Path -LiteralPath $DocRel){
        $Doc=Get-Content -LiteralPath $DocRel -Raw -Encoding UTF8

        if($Doc -notmatch 'Escaneo global de blobs'){
            $Doc += @"

## Escaneo global de blobs superiores a 100 MB

La recuperación v1.0.6 inspeccionó el árbol completo del commit local rechazado mediante ``git ls-tree -r -l HEAD`` para identificar todos los blobs que exceden el límite individual de GitHub.

Cada archivo detectado se retiró únicamente del índice Git, permaneció preservado localmente y se representó en el repositorio mediante un archivo gzip dividido en partes menores a 100 MB. Para cada representación se verificó la reconstrucción exacta mediante SHA-256 antes de la publicación.
"@
            Write-Lf $DocRel $Doc
        }
    }

    Write-Host "EVIDENCE      : UPDATED"
    Write-Host "INVENTORY     : UPDATED"
    Write-Host "DOCUMENTATION : UPDATED"

    Step 6 "INSTITUTIONAL TEST SUITE + COMPILEALL"

    $Python=PythonExe
    $env:PYTHONPATH=(Join-Path $PWD "src")

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q","src") "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 7 "STAGE RECOVERY TRANSACTION"

    Native "git.exe" @("-c","core.safecrlf=false","add","--",$SelfName) "stage recovery master"

    foreach($record in $ArchiveRecords){
        Native "git.exe" @("-c","core.safecrlf=false","add","--",([string]$record.archive_root)) ("stage archive "+[string]$record.archive_root)
    }

    if(Test-Path -LiteralPath $EvidenceRel){
        Native "git.exe" @("-c","core.safecrlf=false","add","--",$EvidenceRel) "stage evidence"
    }
    if(Test-Path -LiteralPath $InventoryRel){
        Native "git.exe" @("-c","core.safecrlf=false","add","--",$InventoryRel) "stage inventory"
    }
    if(Test-Path -LiteralPath $DocRel){
        Native "git.exe" @("-c","core.safecrlf=false","add","--",$DocRel) "stage documentation"
    }

    Write-Host "RECOVERY TRANSACTION : STAGED"

    Step 8 "INDEX-WIDE GITHUB 100 MB GATE"

    $IndexEntries=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate index."}

    $TooLarge=New-Object System.Collections.ArrayList
    $Checked=0

    foreach($p0 in $IndexEntries){
        $p=Norm $p0
        $spec=":"+$p

        $PreviousEap=$ErrorActionPreference
        try{
            $ErrorActionPreference="Continue"
            $sizeOut=@(& git.exe cat-file -s $spec 2>$null)
            $code=$LASTEXITCODE
        }
        finally{
            $ErrorActionPreference=$PreviousEap
        }

        if($code -ne 0 -or $sizeOut.Count -eq 0){continue}

        [Int64]$len=0
        if([Int64]::TryParse(([string]$sizeOut[0]).Trim(),[ref]$len)){
            $Checked++
            if($len -ge $GitHubLimitBytes){
                [void]$TooLarge.Add([ordered]@{path=$p;bytes=$len})
            }
        }
    }

    Write-Host "INDEX BLOBS CHECKED : $Checked"
    Write-Host "INDEX BLOBS >=100MB : $($TooLarge.Count)"

    if($TooLarge.Count -gt 0){
        foreach($x in $TooLarge){
            Write-Host ("TOO LARGE INDEX BLOB : {0} ({1} bytes)" -f $x.path,$x.bytes) -ForegroundColor Red
        }
        Stop-Hold "At least one oversized blob remains in the Git index."
    }

    Write-Host "GITHUB 100 MB INDEX-WIDE GATE : PASS"

    Step 9 "VERIFY ALL ORIGINAL LARGE FILES STILL LOCAL AND UNCHANGED"

    foreach($item in $Oversized){
        $p=[string]$item.path

        if(-not(Test-Path -LiteralPath $p -PathType Leaf)){
            Stop-Hold "Original oversized file disappeared locally: $p"
        }

        $hash=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpperInvariant()
        if($hash -ne $OriginalHashes[$p]){
            Stop-Hold "Original oversized file changed during recovery: $p"
        }

        $tracked=@(& git.exe ls-files -- $p)
        if($tracked.Count -ne 0){
            Stop-Hold "Oversized original remains tracked: $p"
        }
    }

    Write-Host "ALL ORIGINAL LARGE FILES : PRESERVED LOCAL"
    Write-Host "ALL OVERSIZED ORIGINALS   : UNTRACKED"

    Step 10 "AMEND REJECTED LOCAL COMMIT"

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $RemoteBefore=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    if($RemoteBefore -ne $RemoteBaseline){
        Stop-Hold "Remote baseline changed before amend."
    }

    Native "git.exe" @("commit","--amend","--no-edit") "git commit --amend"

    $AmendedCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "AMENDED COMMIT : $AmendedCommit"

    if($AmendedCommit -eq $RejectedLocalCommit){
        Stop-Hold "Commit hash did not change after v1.0.6 recovery."
    }

    Step 11 "PUSH + REMOTE ACCEPTANCE"

    Native "git.exe" @("push","origin",$Branch) "git push"
    Write-Host "PUSH : PASS"

    Step 12 "AUTHORITATIVE REMOTE VERIFICATION"

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

    if(
        $FinalLocal -ne $FinalRemote -or
        $Counts[0] -ne "0" -or
        $Counts[1] -ne "0" -or
        $FinalStaged.Count -ne 0 -or
        $FinalDeleted.Count -ne 0
    ){
        Stop-Hold "Final repository synchronization gate failed."
    }

    foreach($item in $Oversized){
        $p=[string]$item.path
        if(-not(Test-Path -LiteralPath $p -PathType Leaf)){
            Stop-Hold "Original oversized file disappeared after publication: $p"
        }

        $hash=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpperInvariant()
        if($hash -ne $OriginalHashes[$p]){
            Stop-Hold "Original oversized file hash changed after publication: $p"
        }
    }

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host " REPOSITORY RECONCILIATION LARGE-FILE RECOVERY v1.0.6 : CLOSED" -ForegroundColor Green
    Write-Host " ALL_HEAD_OVERSIZED_BLOBS_DISCOVERED=YES" -ForegroundColor Green
    Write-Host " ALL_OVERSIZED_ORIGINALS_GITHUB_TRACKED=NO" -ForegroundColor Green
    Write-Host " ALL_ORIGINAL_LARGE_FILES_LOCAL=PRESERVED" -ForegroundColor Green
    Write-Host " ALL_SPLIT_GZIP_ARCHIVES=VERIFIED" -ForegroundColor Green
    Write-Host " INDEX_WIDE_100MB_GATE=PASS" -ForegroundColor Green
    Write-Host " LOCAL_HEAD=REMOTE_HEAD" -ForegroundColor Green
    Write-Host " FINAL_RECOVERY_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    exit 0
}
catch{
    Stop-Hold $_.Exception.Message
}
