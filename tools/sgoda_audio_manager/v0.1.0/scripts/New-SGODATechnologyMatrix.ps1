[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,

    [Parameter(Mandatory=$true)]
    [string]$InputPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

$ImportScript = Join-Path $PSScriptRoot 'Import-SGODAInput.ps1'

$Imported = & $ImportScript `
    -ConfigPath $ConfigPath `
    -InputPath $InputPath

$Config  = $Imported.Config
$Rows    = @($Imported.Rows)
$Columns = $Imported.Columns

$InstanceId = [string]$Config.instance.instance_id
$Prefix     = [string]$Config.instance.lexical_prefix
$IdWidth    = [int]$Config.instance.id_width

$NativeName = [string]$Config.instance.native_language.name
$NativeCode = [string]$Config.instance.native_language.code

$PrimaryAuxName = [string]$Config.instance.primary_auxiliary_language.name
$PrimaryAuxCode = [string]$Config.instance.primary_auxiliary_language.code

$BatchSize  = [int]$Config.instance.production.batch_size
$SampleRate = [int]$Config.instance.production.sample_rate_hz
$BitDepth   = [int]$Config.instance.production.bit_depth
$Channels   = [int]$Config.instance.production.channels

$DriveProvider = [string]$Config.storage.provider
$DriveRoot     = [string]$Config.storage.root

if ([string]$Config.storage.type -ne 'drive') {
    throw "SGODA AudioManager requiere una fuente tipo Drive."
}

$WavFolder = [string]$Config.storage.folders.wav
$Mp3Folder = [string]$Config.storage.folders.mp3

$WavPath = Join-Path $DriveRoot $WavFolder
$Mp3Path = Join-Path $DriveRoot $Mp3Folder

New-Item `
    -ItemType Directory `
    -Force `
    -Path $OutputDirectory |
    Out-Null

$Matrix = @()

$GeneratedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')

for ($Index = 0; $Index -lt $Rows.Count; $Index++) {

    $Row = $Rows[$Index]

    $NumericId = [int]([string]$Row.($Columns.Id))

    $RecordId = $NumericId.ToString(('0' * $IdWidth))
    $LexicalId = "$Prefix-$RecordId"

    $ExpectedWav = "${LexicalId}_${NativeCode}.wav"
    $ExpectedMp3 = "${LexicalId}_${NativeCode}.mp3"

    $WavFullPath = Join-Path $WavPath $ExpectedWav
    $Mp3FullPath = Join-Path $Mp3Path $ExpectedMp3

    $WavExists = Test-Path -LiteralPath $WavFullPath
    $Mp3Exists = Test-Path -LiteralPath $Mp3FullPath

    $WavSize = [int64]0
    $Mp3Size = [int64]0
    $WavHash = ''
    $Mp3Hash = ''

    if ($WavExists) {

        $WavItem = Get-Item -LiteralPath $WavFullPath
        $WavSize = [int64]$WavItem.Length

        $WavHash = (
            Get-FileHash `
                -LiteralPath $WavFullPath `
                -Algorithm SHA256
        ).Hash
    }

    if ($Mp3Exists) {

        $Mp3Item = Get-Item -LiteralPath $Mp3FullPath
        $Mp3Size = [int64]$Mp3Item.Length

        $Mp3Hash = (
            Get-FileHash `
                -LiteralPath $Mp3FullPath `
                -Algorithm SHA256
        ).Hash
    }

    $Missing = @()

    if (-not $WavExists) {
        $Missing += $ExpectedWav
    }

    if (-not $Mp3Exists) {
        $Missing += $ExpectedMp3
    }

    $BatchNumber = [int](
        [math]::Floor($Index / $BatchSize)
    ) + 1

    $BatchPosition = [int](
        $Index % $BatchSize
    ) + 1

    $BatchId = 'LOTE-' + $BatchNumber.ToString('000')

    $SourceAudio = [string]$Row.($Columns.NativeAudio)

    $FilenameValid = (
        $SourceAudio -eq $ExpectedMp3
    )

    $AuxiliaryExpected = @()

    foreach ($Aux in @($Config.instance.auxiliary_languages)) {

        $AuxCode = [string]$Aux.code

        $AuxiliaryExpected += (
            "${LexicalId}_${AuxCode}.mp3"
        )
    }

    $ProductionStatus = 'PENDING'

    if ($WavExists -or $Mp3Exists) {
        $ProductionStatus = 'PARTIAL'
    }

    if ($WavExists -and $Mp3Exists) {
        $ProductionStatus = 'EXPORTED'
    }

    $DriveValidationStatus = 'FAIL'

    if (
        $WavExists -and
        $Mp3Exists -and
        $WavSize -gt 0 -and
        $Mp3Size -gt 0
    ) {
        $DriveValidationStatus = 'PASS'
    }

    $Matrix += [PSCustomObject][ordered]@{

        record_id                  = $RecordId
        lexical_id                 = $LexicalId
        instance_id                = $InstanceId

        native_language_name       = $NativeName
        native_language_code       = $NativeCode
        native_word                = [string]$Row.($Columns.NativeWord)
        native_pronunciation       = [string]$Row.($Columns.NativePronunciation)

        primary_aux_language_name  = $PrimaryAuxName
        primary_aux_language_code  = $PrimaryAuxCode
        primary_translation        = [string]$Row.($Columns.PrimaryTranslation)

        source_native_audio        = $SourceAudio
        source_filename_valid      = $FilenameValid

        expected_native_wav        = $ExpectedWav
        expected_native_mp3        = $ExpectedMp3
        expected_auxiliary_mp3     = ($AuxiliaryExpected -join ';')

        batch_id                   = $BatchId
        batch_position             = $BatchPosition
        batch_size                 = $BatchSize

        drive_provider             = $DriveProvider
        drive_root                 = $DriveRoot

        drive_wav_relative_path    = Join-Path $WavFolder $ExpectedWav
        drive_mp3_relative_path    = Join-Path $Mp3Folder $ExpectedMp3

        wav_exists                 = $WavExists
        mp3_exists                 = $Mp3Exists

        wav_size_bytes             = $WavSize
        mp3_size_bytes             = $Mp3Size

        wav_sha256                 = $WavHash
        mp3_sha256                 = $Mp3Hash

        expected_sample_rate_hz    = $SampleRate
        expected_bit_depth         = $BitDepth
        expected_channels          = $Channels

        missing_resources          = ($Missing -join ';')

        filename_valid             = $FilenameValid
        drive_validation_status    = $DriveValidationStatus

        audio_qc_status            = 'PENDING'
        production_status          = $ProductionStatus

        generated_at               = $GeneratedAt
    }
}

if ($Matrix.Count -ne $Rows.Count) {

    throw (
        "Matriz incompleta. Entrada=$($Rows.Count); " +
        "Matriz=$($Matrix.Count)"
    )
}

$CsvPath = Join-Path `
    $OutputDirectory `
    'MATRIZ_TECNOLOGICA_SGODA.csv'

$JsonPath = Join-Path `
    $OutputDirectory `
    'MATRIZ_TECNOLOGICA_SGODA.json'

$Matrix |
    Export-Csv `
        -LiteralPath $CsvPath `
        -NoTypeInformation `
        -Encoding UTF8

$Matrix |
    ConvertTo-Json -Depth 10 |
    Set-Content `
        -LiteralPath $JsonPath `
        -Encoding UTF8

[PSCustomObject]@{
    Matrix   = $Matrix
    CsvPath  = $CsvPath
    JsonPath = $JsonPath
}
