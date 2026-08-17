[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RecordsPath,

    [Parameter(Mandatory=$true)]
    [string]$WavDirectory,

    [Parameter(Mandatory=$true)]
    [string]$Mp3Directory,

    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Never','IfInvalid','Always')]
    [string]$OverwritePolicy = 'Never',

    [Parameter(Mandatory=$false)]
    [int]$AudioBitrateKbps = 128
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Write-Utf8LfText {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Text
    )

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    $Normalized = $Text.
        Replace("`r`n","`n").
        Replace("`r","`n")

    if (-not $Normalized.EndsWith("`n")) {
        $Normalized += "`n"
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Normalized,
        $Utf8NoBom
    )
}

function Write-Utf8LfJson {
    param(
        [string]$Path,
        [object]$Object,
        [int]$Depth = 20
    )

    Write-Utf8LfText `
        -Path $Path `
        -Text (
            $Object |
            ConvertTo-Json -Depth $Depth
        )
}

function Write-Utf8LfCsv {
    param(
        [string]$Path,
        [object[]]$Rows
    )

    $Text = (
        $Rows |
        ConvertTo-Csv -NoTypeInformation
    ) -join "`n"

    Write-Utf8LfText `
        -Path $Path `
        -Text $Text
}

function Get-AudioProbe {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$FfprobePath
    )

    $Json = & $FfprobePath `
        -v error `
        -select_streams a:0 `
        -show_entries `
        stream=codec_name,codec_type,sample_rate,channels,bit_rate,duration `
        -show_entries `
        format=format_name,duration,size,bit_rate `
        -of json `
        -- `
        $Path

    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe fallo para: $Path"
    }

    $Parsed = (
        $Json -join "`n"
    ) | ConvertFrom-Json

    $AudioStream = @(
        $Parsed.streams |
        Where-Object {
            $_.codec_type -eq 'audio'
        }
    ) | Select-Object -First 1

    if ($null -eq $AudioStream) {
        throw "No se encontro stream de audio: $Path"
    }

    return [PSCustomObject]@{
        codec_name = [string]$AudioStream.codec_name
        sample_rate = [string]$AudioStream.sample_rate
        channels = [string]$AudioStream.channels
        stream_bit_rate = [string]$AudioStream.bit_rate
        duration = [string]$Parsed.format.duration
        size = [string]$Parsed.format.size
        format_name = [string]$Parsed.format.format_name
    }
}

foreach ($Required in @(
    $RecordsPath,
    $WavDirectory
)) {
    if (-not (Test-Path -LiteralPath $Required)) {
        throw "No existe recurso requerido: $Required"
    }
}

$Ffmpeg = Get-Command `
    ffmpeg `
    -ErrorAction SilentlyContinue

$Ffprobe = Get-Command `
    ffprobe `
    -ErrorAction SilentlyContinue

if ($null -eq $Ffmpeg) {
    throw 'ffmpeg no disponible.'
}

if ($null -eq $Ffprobe) {
    throw 'ffprobe no disponible.'
}

New-Item `
    -ItemType Directory `
    -Path $Mp3Directory `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $OutputDirectory `
    -Force |
    Out-Null

$Records = @(
    Import-Csv `
        -LiteralPath $RecordsPath `
        -Encoding UTF8
)

if ($Records.Count -lt 1) {
    throw 'RecordsPath no contiene registros.'
}

$Pending = @(
    $Records |
    Where-Object {
        $_.record_status -eq 'MISSING_MP3'
    }
)

$Results = @()

foreach ($Record in $Pending) {

    $LexicalId = [string]$Record.lexical_id
    $NativeWord = [string]$Record.native_word
    $ExpectedWav = [string]$Record.expected_wav
    $ExpectedMp3 = [string]$Record.expected_mp3

    $WavPath = Join-Path `
        $WavDirectory `
        $ExpectedWav

    $Mp3Path = Join-Path `
        $Mp3Directory `
        $ExpectedMp3

    $Status = 'PENDING'
    $Action = ''
    $ErrorMessage = ''
    $WavSha256 = ''
    $Mp3Sha256 = ''
    $Mp3Codec = ''
    $Mp3Duration = ''
    $Mp3Size = 0

    try {

        if (-not (Test-Path -LiteralPath $WavPath)) {
            throw "WAV_MASTER_MISSING"
        }

        $WavItem = Get-Item -LiteralPath $WavPath

        if ($WavItem.Length -le 0) {
            throw "WAV_MASTER_EMPTY"
        }

        $WavSha256 = (
            Get-FileHash `
                -LiteralPath $WavPath `
                -Algorithm SHA256
        ).Hash

        $ExistingValid = $false

        if (Test-Path -LiteralPath $Mp3Path) {

            try {

                $Probe = Get-AudioProbe `
                    -Path $Mp3Path `
                    -FfprobePath $Ffprobe.Source

                if (
                    $Probe.codec_name -eq 'mp3' -and
                    [int64]$Probe.size -gt 0
                ) {
                    $ExistingValid = $true
                }
            }
            catch {
                $ExistingValid = $false
            }

            if (
                $OverwritePolicy -eq 'Never' -and
                $ExistingValid
            ) {
                $Action = 'SKIPPED_VALID_EXISTING'
            }
            elseif (
                $OverwritePolicy -eq 'Never' -and
                -not $ExistingValid
            ) {
                throw "MP3_EXISTS_INVALID_OVERWRITE_FORBIDDEN"
            }
            elseif (
                $OverwritePolicy -eq 'IfInvalid' -and
                $ExistingValid
            ) {
                $Action = 'SKIPPED_VALID_EXISTING'
            }
            else {
                Remove-Item `
                    -LiteralPath $Mp3Path `
                    -Force

                $Action = 'REGENERATED'
            }
        }
        else {
            $Action = 'GENERATED'
        }

        if (
            $Action -eq 'GENERATED' -or
            $Action -eq 'REGENERATED'
        ) {

            & $Ffmpeg.Source `
                -hide_banner `
                -loglevel error `
                -nostdin `
                -y `
                -i $WavPath `
                -map_metadata -1 `
                -vn `
                -codec:a libmp3lame `
                -b:a ("{0}k" -f $AudioBitrateKbps) `
                $Mp3Path

            if ($LASTEXITCODE -ne 0) {
                throw "FFMPEG_CONVERSION_FAILED"
            }
        }

        if (-not (Test-Path -LiteralPath $Mp3Path)) {
            throw "MP3_OUTPUT_MISSING"
        }

        $Probe = Get-AudioProbe `
            -Path $Mp3Path `
            -FfprobePath $Ffprobe.Source

        if ($Probe.codec_name -ne 'mp3') {
            throw "MP3_CODEC_INVALID"
        }

        $Mp3Item = Get-Item -LiteralPath $Mp3Path

        if ($Mp3Item.Length -le 0) {
            throw "MP3_OUTPUT_EMPTY"
        }

        $Mp3Sha256 = (
            Get-FileHash `
                -LiteralPath $Mp3Path `
                -Algorithm SHA256
        ).Hash

        $Mp3Codec = $Probe.codec_name
        $Mp3Duration = $Probe.duration
        $Mp3Size = $Mp3Item.Length
        $Status = 'READY'
    }
    catch {

        $Status = 'ERROR'
        $ErrorMessage = $_.Exception.Message
    }

    $Results += [PSCustomObject]@{
        lexical_id = $LexicalId
        native_word = $NativeWord
        expected_wav = $ExpectedWav
        expected_mp3 = $ExpectedMp3
        wav_path = $WavPath
        mp3_path = $Mp3Path
        overwrite_policy = $OverwritePolicy
        action = $Action
        wav_sha256 = $WavSha256
        mp3_sha256 = $Mp3Sha256
        mp3_codec = $Mp3Codec
        mp3_duration_seconds = $Mp3Duration
        mp3_size_bytes = $Mp3Size
        status = $Status
        error = $ErrorMessage
    }
}

$Ready = @(
    $Results |
    Where-Object {
        $_.status -eq 'READY'
    }
)

$Errors = @(
    $Results |
    Where-Object {
        $_.status -eq 'ERROR'
    }
)

$Summary = [ordered]@{
    engine = 'SGODA Audio Derivation Engine'
    version = '0.3.0'
    source_records = $Records.Count
    pending_mp3 = $Pending.Count
    processed = $Results.Count
    ready = $Ready.Count
    errors = $Errors.Count
    overwrite_policy = $OverwritePolicy
    audio_bitrate_kbps = $AudioBitrateKbps
    ffmpeg = $Ffmpeg.Source
    ffprobe = $Ffprobe.Source
    generated_utc = [DateTime]::UtcNow.ToString('o')
}

$CsvPath = Join-Path `
    $OutputDirectory `
    'audio-derivation-records.csv'

$JsonPath = Join-Path `
    $OutputDirectory `
    'audio-derivation-records.json'

$SummaryPath = Join-Path `
    $OutputDirectory `
    'audio-derivation-summary.json'

Write-Utf8LfCsv `
    -Path $CsvPath `
    -Rows $Results

Write-Utf8LfJson `
    -Path $JsonPath `
    -Object $Results

Write-Utf8LfJson `
    -Path $SummaryPath `
    -Object $Summary

[PSCustomObject]@{
    Status = if ($Errors.Count -eq 0) {
        'PASS'
    }
    else {
        'FAIL'
    }

    SourceRecords = $Records.Count
    PendingMp3 = $Pending.Count
    Processed = $Results.Count
    Ready = $Ready.Count
    Errors = $Errors.Count
    RecordsCsv = $CsvPath
    RecordsJson = $JsonPath
    SummaryJson = $SummaryPath
}