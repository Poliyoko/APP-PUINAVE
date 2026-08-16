[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$MatrixPath,

    [Parameter(Mandatory=$true)]
    [int]$ExpectedRecords
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $MatrixPath)) {
    throw "No existe la matriz: $MatrixPath"
}

$Matrix = @(
    Import-Csv -LiteralPath $MatrixPath
)

$Missing = @(
    $Matrix |
        Where-Object {
            $_.missing_resources -ne ''
        }
)

$DriveFail = @(
    $Matrix |
        Where-Object {
            $_.drive_validation_status -ne 'PASS'
        }
)

$BadFilename = @(
    $Matrix |
        Where-Object {
            $_.filename_valid -ne 'True'
        }
)

$DuplicateIds = @(
    $Matrix |
        Group-Object lexical_id |
        Where-Object Count -gt 1
)

$InvalidWavHash = @(
    $Matrix |
        Where-Object {
            [string]::IsNullOrWhiteSpace($_.wav_sha256) -or
            $_.wav_sha256.Length -ne 64
        }
)

$InvalidMp3Hash = @(
    $Matrix |
        Where-Object {
            [string]::IsNullOrWhiteSpace($_.mp3_sha256) -or
            $_.mp3_sha256.Length -ne 64
        }
)

$Status = 'PASS'

if ($Matrix.Count -ne $ExpectedRecords)  { $Status = 'FAIL' }
if ($Missing.Count -gt 0)               { $Status = 'FAIL' }
if ($DriveFail.Count -gt 0)             { $Status = 'FAIL' }
if ($BadFilename.Count -gt 0)           { $Status = 'FAIL' }
if ($DuplicateIds.Count -gt 0)          { $Status = 'FAIL' }
if ($InvalidWavHash.Count -gt 0)        { $Status = 'FAIL' }
if ($InvalidMp3Hash.Count -gt 0)        { $Status = 'FAIL' }

[PSCustomObject]@{
    Status              = $Status
    Records             = $Matrix.Count
    MissingResources    = $Missing.Count
    DriveFailures       = $DriveFail.Count
    InvalidFilenames    = $BadFilename.Count
    DuplicateLexicalIds = $DuplicateIds.Count
    InvalidWavHashes    = $InvalidWavHash.Count
    InvalidMp3Hashes    = $InvalidMp3Hash.Count
}
