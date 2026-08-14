#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "4d463840b2bae0bbc6f18ea869f37e792b69d450"
$Branch = "feature/SPT-001A-rlb-schema-foundation"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA LARGEFILE / SECRET AUDIT : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    exit 1
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

Write-Host ""
Write-Host "============================================================"
Write-Host " SGODA LARGEFILE / SECRET CLASSIFICATION AUDIT v1.1.3"
Write-Host "============================================================"

$Root = (& git.exe rev-parse --show-toplevel).Trim()
if(-not $Root) { Hold "Not inside Git repository" }
Set-Location $Root

Write-Host ""
Write-Host "[1/7] AUTHORITATIVE BASELINE"
& git.exe fetch origin $Branch
if($LASTEXITCODE -ne 0) { Hold "git fetch failed" }

$Local = (& git.exe rev-parse HEAD).Trim()
$Remote = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
$Staged = @(& git.exe diff --cached --name-only)
$Deleted = @(& git.exe ls-files --deleted)

Write-Host "EXPECTED=$ExpectedBaseline"
Write-Host "LOCAL=$Local"
Write-Host "REMOTE=$Remote"
Write-Host "STAGED=$($Staged.Count)"
Write-Host "DELETED_TRACKED=$($Deleted.Count)"

if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline) { Hold "Authoritative baseline mismatch" }
if($Staged.Count -ne 0 -or $Deleted.Count -ne 0) { Hold "Unsafe staged/deleted state" }

Write-Host "BASELINE_GATE=PASS"

Write-Host ""
Write-Host "[2/7] CURRENT UNTRACKED INVENTORY"
$Untracked = @(& git.exe -c core.quotepath=false ls-files --others --exclude-standard)
Write-Host "UNTRACKED_COUNT=$($Untracked.Count)"

Write-Host ""
Write-Host "[3/7] BUILD TRACKED / UNTRACKED HASH INDEX"
$TrackedHash = @{}
foreach($P in @(& git.exe -c core.quotepath=false ls-files)) {
    if(Test-Path -LiteralPath $P -PathType Leaf) {
        try {
            $H = Get-Sha256 $P
            if(-not $TrackedHash.ContainsKey($H)) { $TrackedHash[$H] = New-Object System.Collections.ArrayList }
            [void]$TrackedHash[$H].Add($P)
        } catch {}
    }
}

$UntrackedHash = @{}
foreach($P in $Untracked) {
    if(Test-Path -LiteralPath $P -PathType Leaf) {
        try {
            $H = Get-Sha256 $P
            if(-not $UntrackedHash.ContainsKey($H)) { $UntrackedHash[$H] = New-Object System.Collections.ArrayList }
            [void]$UntrackedHash[$H].Add($P)
        } catch {}
    }
}

Write-Host "TRACKED_HASH_INDEX=PASS"
Write-Host "UNTRACKED_HASH_INDEX=PASS"

Write-Host ""
Write-Host "[4/7] OVERSIZED CANDIDATES"
$Oversized = @()

foreach($P in $Untracked) {
    if(Test-Path -LiteralPath $P -PathType Leaf) {
        $Item = Get-Item -LiteralPath $P
        if($Item.Length -ge 100MB) {
            $H = Get-Sha256 $P
            $TrackedEquiv = @()
            $UntrackedEquiv = @()

            if($TrackedHash.ContainsKey($H)) { $TrackedEquiv = @($TrackedHash[$H]) }
            if($UntrackedHash.ContainsKey($H)) { $UntrackedEquiv = @($UntrackedHash[$H] | Where-Object { $_ -ne $P }) }

            $Oversized += [PSCustomObject]@{
                Path = $P
                Bytes = [Int64]$Item.Length
                MiB = [Math]::Round($Item.Length / 1MB, 2)
                SHA256 = $H
                TrackedEquivalentCount = $TrackedEquiv.Count
                UntrackedEquivalentCount = $UntrackedEquiv.Count
                UntrackedEquivalents = ($UntrackedEquiv -join " | ")
            }
        }
    }
}

Write-Host "OVERSIZED_COUNT=$($Oversized.Count)"
foreach($R in $Oversized) {
    Write-Host ("OVERSIZED_PATH=" + $R.Path)
    Write-Host ("OVERSIZED_MIB=" + $R.MiB)
    Write-Host ("OVERSIZED_SHA256=" + $R.SHA256)
    Write-Host ("TRACKED_EQUIVALENTS=" + $R.TrackedEquivalentCount)
    Write-Host ("UNTRACKED_EQUIVALENTS=" + $R.UntrackedEquivalentCount)
    if($R.UntrackedEquivalentCount -gt 0) {
        Write-Host ("UNTRACKED_EQUIVALENT_PATHS=" + $R.UntrackedEquivalents)
    }
}

Write-Host ""
Write-Host "[5/7] HIGH-RISK SECRET PATH CLASSIFICATION"
$Patterns = [ordered]@{
    "PRIVATE_KEY_BLOCK" = '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
    "GITHUB_PAT" = 'github_pat_[A-Za-z0-9_]{20,}'
    "GITHUB_CLASSIC_TOKEN" = 'ghp_[A-Za-z0-9]{30,}'
    "AWS_ACCESS_KEY" = 'AKIA[0-9A-Z]{16}'
    "OPENAI_STYLE_SECRET" = 'sk-[A-Za-z0-9_-]{20,}'
}

$TextExt = @(".ps1",".py",".json",".md",".txt",".yml",".yaml",".toml",".ini",".cfg",".env",".xml",".csv",".log")
$SecretHits = @()

foreach($P in $Untracked) {
    if(-not (Test-Path -LiteralPath $P -PathType Leaf)) { continue }
    $Ext = [IO.Path]::GetExtension($P).ToLowerInvariant()
    if($TextExt -notcontains $Ext) { continue }

    try {
        $Text = [IO.File]::ReadAllText((Join-Path $Root $P),[Text.Encoding]::UTF8)
    } catch {
        try { $Text = Get-Content -LiteralPath $P -Raw } catch { continue }
    }

    foreach($Name in $Patterns.Keys) {
        if([regex]::IsMatch($Text,$Patterns[$Name])) {
            $SecretHits += [PSCustomObject]@{
                Path = $P
                Pattern = $Name
                SHA256 = (Get-Sha256 $P)
            }
        }
    }
}

Write-Host "HIGH_RISK_SECRET_HIT_COUNT=$($SecretHits.Count)"
foreach($H in $SecretHits) {
    Write-Host ("SECRET_RISK_PATH=" + $H.Path)
    Write-Host ("SECRET_RISK_PATTERN=" + $H.Pattern)
    Write-Host ("SECRET_RISK_SHA256=" + $H.SHA256)
}
Write-Host "SECRET_VALUES_PRINTED=NO"

Write-Host ""
Write-Host "[6/7] SPLIT-PRESERVATION READINESS"
foreach($R in $Oversized) {
    $RecommendedChunkMiB = 90
    $ChunkCount = [Math]::Ceiling($R.Bytes / ($RecommendedChunkMiB * 1MB))
    Write-Host ("SPLIT_PLAN_PATH=" + $R.Path)
    Write-Host ("SPLIT_PLAN_CHUNK_MIB=" + $RecommendedChunkMiB)
    Write-Host ("SPLIT_PLAN_CHUNK_COUNT=" + $ChunkCount)
    Write-Host ("SPLIT_PLAN_RECONSTRUCTABLE=YES")
}

Write-Host ""
Write-Host "[7/7] FINAL AUDIT GATE"
$Ahead = (& git.exe rev-list --count ("origin/" + $Branch + "..HEAD")).Trim()
$Behind = (& git.exe rev-list --count ("HEAD..origin/" + $Branch)).Trim()

Write-Host "AHEAD=$Ahead"
Write-Host "BEHIND=$Behind"
Write-Host "FILES_MODIFIED=0"
Write-Host "FILES_STAGED=0"
Write-Host "FILES_DELETED=0"
Write-Host "COMMIT_PERFORMED=NO"
Write-Host "PUSH_PERFORMED=NO"

if($Ahead -eq "0" -and $Behind -eq "0" -and $Staged.Count -eq 0 -and $Deleted.Count -eq 0) {
    Write-Host "NON_DESTRUCTIVE_AUDIT=PASS"
    Write-Host "NEXT_ACTION=BUILD_LARGEFILE_AND_SECRET_RECONCILIATION_RECOVERY"
    Write-Host "FINAL_EXIT_CODE=0"
} else {
    Write-Host "NON_DESTRUCTIVE_AUDIT=HOLD"
    exit 1
}
