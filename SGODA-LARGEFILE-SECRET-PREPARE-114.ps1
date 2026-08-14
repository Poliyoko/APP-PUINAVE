#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "4d463840b2bae0bbc6f18ea869f37e792b69d450"
$Branch = "feature/SPT-001A-rlb-schema-foundation"

$Oversized = @(
    "artifacts/consolidation/PCI-002-v1.2.1/robocopy/staging-copy-attempt-1.log",
    "artifacts/consolidation/PCI-002-v1.2.1/robocopy/staging-copy-attempt-2.log",
    "artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory.json",
    "releases/SPT-019.0-v1.1.0/institutional-inventory.json"
)

$SecretRisk = "Invoke-SGODA-SPT0242-R1-FINAL-v1.0.0-PS51.ps1"

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA LARGEFILE / SECRET PREPARE : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    exit 1
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Compress-GzipToTemp {
    param([string]$Source,[string]$Destination)

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

Write-Host ""
Write-Host "============================================================"
Write-Host " SGODA LARGEFILE / SECRET RECONCILIATION PREPARE v1.1.4"
Write-Host "============================================================"

$Root = (& git.exe rev-parse --show-toplevel).Trim()
if(-not $Root) { Hold "Not inside Git repository" }
Set-Location $Root

Write-Host ""
Write-Host "[1/8] AUTHORITATIVE BASELINE"
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
Write-Host "[2/8] OVERSIZED INPUT VERIFICATION"
foreach($P in $Oversized) {
    if(-not (Test-Path -LiteralPath $P -PathType Leaf)) { Hold ("Missing oversized input: " + $P) }
    $Size = (Get-Item -LiteralPath $P).Length
    Write-Host ("INPUT_PATH=" + $P)
    Write-Host ("INPUT_MIB=" + [Math]::Round($Size/1MB,2))
    Write-Host ("INPUT_SHA256=" + (Get-Sha256 $P))
}
Write-Host "OVERSIZED_INPUTS=4"
Write-Host "OVERSIZED_INPUT_GATE=PASS"

Write-Host ""
Write-Host "[3/8] TEMPORARY GZIP RECONSTRUCTABILITY TEST"
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("sgoda-largefile-prepare-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

$CompressionResults = @()

try {
    $Index = 0
    foreach($P in $Oversized) {
        $Index++
        $SourceAbs = Join-Path $Root $P
        $Gz = Join-Path $TempRoot ("candidate-" + $Index + ".gz")
        Compress-GzipToTemp $SourceAbs $Gz

        $OriginalBytes = (Get-Item -LiteralPath $SourceAbs).Length
        $CompressedBytes = (Get-Item -LiteralPath $Gz).Length
        $Ratio = if($OriginalBytes -gt 0) { [Math]::Round(($CompressedBytes / $OriginalBytes) * 100,2) } else { 0 }

        $CompressionResults += [PSCustomObject]@{
            Path = $P
            OriginalBytes = [Int64]$OriginalBytes
            CompressedBytes = [Int64]$CompressedBytes
            CompressedMiB = [Math]::Round($CompressedBytes / 1MB,2)
            RatioPercent = $Ratio
            OriginalSHA256 = Get-Sha256 $P
            CompressedSHA256 = Get-Sha256 $Gz
            FitsGitHubBlobGate = ($CompressedBytes -lt 100MB)
        }

        Write-Host ("GZIP_PATH=" + $P)
        Write-Host ("GZIP_COMPRESSED_MIB=" + [Math]::Round($CompressedBytes/1MB,2))
        Write-Host ("GZIP_RATIO_PERCENT=" + $Ratio)
        Write-Host ("GZIP_FITS_UNDER_100MB=" + ($CompressedBytes -lt 100MB))
    }
} finally {
    # Temp content is never part of repository and is removed after metrics are collected.
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$AllFit = (@($CompressionResults | Where-Object { -not $_.FitsGitHubBlobGate }).Count -eq 0)
Write-Host "ALL_GZIP_CANDIDATES_UNDER_100MB=$AllFit"

Write-Host ""
Write-Host "[4/8] PRIVATE-KEY STRUCTURAL CLASSIFICATION"
if(-not (Test-Path -LiteralPath $SecretRisk -PathType Leaf)) { Hold "Secret-risk script missing" }

$SecretText = [IO.File]::ReadAllText((Join-Path $Root $SecretRisk),[Text.Encoding]::UTF8)
$BeginMatches = [regex]::Matches($SecretText,'-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----')
$EndMatches = [regex]::Matches($SecretText,'-----END (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----')

$ActualPemBlock = $false
$MarkerOnly = $false

if($BeginMatches.Count -gt 0) {
    # Detect a plausible PEM payload between begin/end markers without printing any content.
    $PemPattern = '-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----\s*[A-Za-z0-9+/=\r\n]{64,}\s*-----END (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
    $ActualPemBlock = [regex]::IsMatch($SecretText,$PemPattern)
    $MarkerOnly = (-not $ActualPemBlock)
}

Write-Host "SECRET_RISK_PATH=$SecretRisk"
Write-Host "PRIVATE_KEY_BEGIN_MARKERS=$($BeginMatches.Count)"
Write-Host "PRIVATE_KEY_END_MARKERS=$($EndMatches.Count)"
Write-Host "PLAUSIBLE_PRIVATE_KEY_PAYLOAD=$ActualPemBlock"
Write-Host "MARKER_OR_PATTERN_ONLY=$MarkerOnly"
Write-Host "SECRET_VALUES_PRINTED=NO"
Write-Host ("SECRET_RISK_SHA256=" + (Get-Sha256 $SecretRisk))

Write-Host ""
Write-Host "[5/8] SECRET PUBLICATION POLICY"
if($ActualPemBlock) {
    Write-Host "SECRET_PUBLICATION_POLICY=DO_NOT_COMMIT_RAW_FILE"
    Write-Host "SECRET_PRESERVATION_POLICY=HASH_AND_REDACTED_METADATA_ONLY"
} else {
    Write-Host "SECRET_PUBLICATION_POLICY=RAW_FILE_ALLOWED_BY_PRIVATE_KEY_STRUCTURAL_GATE"
    Write-Host "SECRET_PRESERVATION_POLICY=PRESERVE_WITH_SHA256"
}

Write-Host ""
Write-Host "[6/8] LARGEFILE PUBLICATION POLICY"
if($AllFit) {
    Write-Host "LARGEFILE_POLICY=GZIP_RECONSTRUCTABLE_ARCHIVES"
    Write-Host "ORIGINAL_OVERSIZED_RAW_FILES=KEEP_LOCAL_UNTRACKED"
    Write-Host "REPOSITORY_REPRESENTATION=GZIP_PLUS_SHA256_MANIFEST"
} else {
    Write-Host "LARGEFILE_POLICY=GZIP_THEN_SPLIT_IF_NEEDED"
    Write-Host "ORIGINAL_OVERSIZED_RAW_FILES=KEEP_LOCAL_UNTRACKED"
    Write-Host "REPOSITORY_REPRESENTATION=RECONSTRUCTABLE_CHUNKS_PLUS_SHA256_MANIFEST"
}

Write-Host ""
Write-Host "[7/8] RECOVERY READINESS"
Write-Host "DESTRUCTIVE_CLEANUP=NO"
Write-Host "ORIGINAL_LARGEFILES_DELETED=NO"
Write-Host "SECRET_VALUE_DISCLOSURE=NO"
Write-Host "SPT025_REOPENED=NO"
Write-Host "PRODUCTION_CHANGE=NO"
Write-Host "RECOVERY_POLICY_READY=YES"

Write-Host ""
Write-Host "[8/8] FINAL PREPARE GATE"
$Ahead = (& git.exe rev-list --count ("origin/" + $Branch + "..HEAD")).Trim()
$Behind = (& git.exe rev-list --count ("HEAD..origin/" + $Branch)).Trim()

Write-Host "AHEAD=$Ahead"
Write-Host "BEHIND=$Behind"
Write-Host "FILES_STAGED=0"
Write-Host "FILES_DELETED=0"
Write-Host "COMMIT_PERFORMED=NO"
Write-Host "PUSH_PERFORMED=NO"

if($Ahead -eq "0" -and $Behind -eq "0") {
    Write-Host "LARGEFILE_SECRET_PREPARE=PASS"
    Write-Host "NEXT_ACTION=BUILD_MASTER_SYNC_RECOVERY_WITH_RECONSTRUCTABLE_LARGEFILE_POLICY"
    Write-Host "FINAL_EXIT_CODE=0"
} else {
    Write-Host "LARGEFILE_SECRET_PREPARE=HOLD"
    exit 1
}
