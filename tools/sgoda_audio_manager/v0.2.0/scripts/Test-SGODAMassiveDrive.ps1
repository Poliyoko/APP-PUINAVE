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
Set-StrictMode -Version 2.0

function Write-Utf8LfText {
    param(
        [string]$Path,
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
        [int]$Depth = 12
    )

    Write-Utf8LfText `
        -Path $Path `
        -Text ($Object | ConvertTo-Json -Depth $Depth)
}

function Write-Utf8LfCsv {
    param(
        [string]$Path,
        [object[]]$Rows
    )

    $CsvText = ($Rows | ConvertTo-Csv -NoTypeInformation) -join "`n"

    Write-Utf8LfText `
        -Path $Path `
        -Text $CsvText
}

foreach ($RequiredPath in @($ConfigPath,$InputPath)) {

    if (-not (Test-Path -LiteralPath $RequiredPath)) {
        throw "No existe recurso requerido: $RequiredPath"
    }
}

$Config = Get-Content `
    -LiteralPath $ConfigPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$Rows = @(
    Import-Csv `
        -LiteralPath $InputPath `
        -Encoding UTF8
)

if ($Rows.Count -lt 1) {
    throw 'La entrada no contiene registros.'
}

$Instance = $Config.instance
$InputConfig = $Config.input
$Production = $Config.production
$Storage = $Config.storage
$Validation = $Config.validation

$Prefix = [string]$Instance.lexical_prefix
$IdWidth = [int]$Instance.id_width
$NativeLanguageName = [string]$Instance.native_language.name
$NativeLanguageCode = [string]$Instance.native_language.code
$PrimaryLanguageName = [string]$Instance.primary_auxiliary_language.name

$NativeUpper = $NativeLanguageName.ToUpperInvariant()
$PrimaryUpper = $PrimaryLanguageName.ToUpperInvariant()

$IdColumn = [string]$InputConfig.columns.id
$NativeWordColumn = [string]$InputConfig.columns.native_word_template
$NativePronunciationColumn = [string]$InputConfig.columns.native_pronunciation_template
$NativeAudioColumn = [string]$InputConfig.columns.native_audio_template
$PrimaryTranslationColumn = [string]$InputConfig.columns.primary_translation_template

$NativeWordColumn = $NativeWordColumn.Replace('{NATIVE_LANGUAGE}',$NativeUpper)
$NativePronunciationColumn = $NativePronunciationColumn.Replace('{NATIVE_LANGUAGE}',$NativeUpper)
$NativeAudioColumn = $NativeAudioColumn.Replace('{NATIVE_LANGUAGE}',$NativeUpper)
$PrimaryTranslationColumn = $PrimaryTranslationColumn.Replace('{PRIMARY_AUXILIARY_LANGUAGE}',$PrimaryUpper)

$RequiredColumns = @(
    $IdColumn,
    $NativeWordColumn,
    $NativePronunciationColumn,
    $NativeAudioColumn,
    $PrimaryTranslationColumn
)

$ActualColumns = @(
    $Rows[0].PSObject.Properties.Name
)

$MissingColumns = @(
    $RequiredColumns |
        Where-Object { $_ -notin $ActualColumns }
)

if ($MissingColumns.Count -gt 0) {
    throw "Columnas obligatorias faltantes: $($MissingColumns -join ', ')"
}

$DriveRoot = [string]$Storage.root
$WavPath = Join-Path $DriveRoot ([string]$Storage.folders.wav)
$Mp3Path = Join-Path $DriveRoot ([string]$Storage.folders.mp3)

foreach ($DrivePath in @($DriveRoot,$WavPath,$Mp3Path)) {

    if (-not (Test-Path -LiteralPath $DrivePath)) {
        throw "Ruta Drive inexistente: $DrivePath"
    }
}

$BatchSize = [int]$Production.batch_size
$IdMode = [string]$InputConfig.id_mode
$GeneratedStart = [int]$InputConfig.generated_id_start

if ([string]::IsNullOrWhiteSpace($IdMode)) {
    $IdMode = 'input_or_generate'
}

$Resolved = @()
$IdFrequency = @{}

for ($Index = 0; $Index -lt $Rows.Count; $Index++) {

    $Row = $Rows[$Index]
    $RawId = [string]$Row.$IdColumn
    $NumericId = $null
    $IdError = ''
    $WasGenerated = $false

    try {

        if ($IdMode -eq 'generate') {
            $NumericId = $GeneratedStart + $Index
            $WasGenerated = $true
        }

        if ($IdMode -eq 'input') {

            if ([string]::IsNullOrWhiteSpace($RawId)) {
                throw 'ID_REQUIRED'
            }

            $NumericId = [int]$RawId
        }

        if ($IdMode -eq 'input_or_generate') {

            if ([string]::IsNullOrWhiteSpace($RawId)) {
                $NumericId = $GeneratedStart + $Index
                $WasGenerated = $true
            }
            else {
                $NumericId = [int]$RawId
            }
        }

        if ($NumericId -lt 0) {
            throw 'NEGATIVE_ID'
        }
    }
    catch {
        $IdError = $_.Exception.Message
    }

    $NormalizedId = ''
    $LexicalId = ''

    if ([string]::IsNullOrWhiteSpace($IdError)) {

        $NormalizedId = $NumericId.ToString(('0' * $IdWidth))
        $LexicalId = "$Prefix-$NormalizedId"

        if (-not $IdFrequency.ContainsKey($LexicalId)) {
            $IdFrequency[$LexicalId] = 0
        }

        $IdFrequency[$LexicalId]++
    }

    $Resolved += [PSCustomObject]@{
        position = $Index + 1
        row = $Row
        raw_id = $RawId
        numeric_id = $NumericId
        normalized_id = $NormalizedId
        lexical_id = $LexicalId
        id_generated = $WasGenerated
        id_error = $IdError
    }
}

$ExpectedWavNames = @()
$ExpectedMp3Names = @()

foreach ($ResolvedRow in $Resolved) {

    if (-not [string]::IsNullOrWhiteSpace($ResolvedRow.lexical_id)) {

        $ExpectedWavNames += "$($ResolvedRow.lexical_id)_$NativeLanguageCode.wav"
        $ExpectedMp3Names += "$($ResolvedRow.lexical_id)_$NativeLanguageCode.mp3"
    }
}

$ExpectedWavNames = @($ExpectedWavNames | Sort-Object -Unique)
$ExpectedMp3Names = @($ExpectedMp3Names | Sort-Object -Unique)

$ActualWavFiles = @(
    Get-ChildItem `
        -LiteralPath $WavPath `
        -File
)

$ActualMp3Files = @(
    Get-ChildItem `
        -LiteralPath $Mp3Path `
        -File
)

$FileReport = @()

foreach ($FormatInfo in @(
    [PSCustomObject]@{
        format = 'WAV'
        extension = 'wav'
        folder = $WavPath
        files = $ActualWavFiles
        expected = $ExpectedWavNames
    },
    [PSCustomObject]@{
        format = 'MP3'
        extension = 'mp3'
        folder = $Mp3Path
        files = $ActualMp3Files
        expected = $ExpectedMp3Names
    }
)) {

    $Regex = '^' +
        [regex]::Escape($Prefix) +
        '-(?<id>\d{' +
        $IdWidth +
        '})_' +
        [regex]::Escape($NativeLanguageCode) +
        '\.' +
        $FormatInfo.extension +
        '$'

    foreach ($File in $FormatInfo.files) {

        $NameValid = ($File.Name -match $Regex)
        $ExpectedFile = ($File.Name -in $FormatInfo.expected)

        $FileStatus = 'EXPECTED_FILE'

        if (-not $NameValid) {
            $FileStatus = 'INVALID_NAME'
        }

        if ($NameValid -and -not $ExpectedFile) {
            $FileStatus = 'UNEXPECTED_FILE'
        }

        if ($File.Length -le 0) {
            $FileStatus = 'EMPTY_FILE'
        }

        $Hash = ''

        if ($File.Length -gt 0 -and
            [bool]$Validation.validate_sha256) {

            $Hash = (
                Get-FileHash `
                    -LiteralPath $File.FullName `
                    -Algorithm SHA256
            ).Hash
        }

        $FileReport += [PSCustomObject]@{
            format = $FormatInfo.format
            name = $File.Name
            path = $File.FullName
            size_bytes = $File.Length
            name_valid = $NameValid
            expected = $ExpectedFile
            sha256 = $Hash
            file_status = $FileStatus
        }
    }
}

$RecordReport = @()

foreach ($ResolvedRow in $Resolved) {

    $Position = $ResolvedRow.position
    $BatchNumber = [int][Math]::Ceiling(
        [double]$Position / [double]$BatchSize
    )

    $BatchId = 'LOTE-{0:D4}' -f $BatchNumber

    $DuplicateId = $false

    if (-not [string]::IsNullOrWhiteSpace($ResolvedRow.lexical_id)) {
        $DuplicateId = ($IdFrequency[$ResolvedRow.lexical_id] -gt 1)
    }

    $ExpectedWav = ''
    $ExpectedMp3 = ''
    $WavFullPath = ''
    $Mp3FullPath = ''

    if (-not [string]::IsNullOrWhiteSpace($ResolvedRow.lexical_id)) {

        $ExpectedWav = "$($ResolvedRow.lexical_id)_$NativeLanguageCode.wav"
        $ExpectedMp3 = "$($ResolvedRow.lexical_id)_$NativeLanguageCode.mp3"

        $WavFullPath = Join-Path $WavPath $ExpectedWav
        $Mp3FullPath = Join-Path $Mp3Path $ExpectedMp3
    }

    $WavExists = $false
    $Mp3Exists = $false
    $WavSize = 0
    $Mp3Size = 0
    $WavSha = ''
    $Mp3Sha = ''

    if (-not [string]::IsNullOrWhiteSpace($WavFullPath)) {
        $WavExists = Test-Path -LiteralPath $WavFullPath
    }

    if (-not [string]::IsNullOrWhiteSpace($Mp3FullPath)) {
        $Mp3Exists = Test-Path -LiteralPath $Mp3FullPath
    }

    if ($WavExists) {

        $WavFile = Get-Item -LiteralPath $WavFullPath
        $WavSize = $WavFile.Length

        if ($WavSize -gt 0 -and
            [bool]$Validation.validate_sha256) {

            $WavSha = (
                Get-FileHash `
                    -LiteralPath $WavFullPath `
                    -Algorithm SHA256
            ).Hash
        }
    }

    if ($Mp3Exists) {

        $Mp3File = Get-Item -LiteralPath $Mp3FullPath
        $Mp3Size = $Mp3File.Length

        if ($Mp3Size -gt 0 -and
            [bool]$Validation.validate_sha256) {

            $Mp3Sha = (
                Get-FileHash `
                    -LiteralPath $Mp3FullPath `
                    -Algorithm SHA256
            ).Hash
        }
    }

    $Status = 'READY'

    if (-not [string]::IsNullOrWhiteSpace($ResolvedRow.id_error)) {
        $Status = 'INVALID_ID'
    }
    elseif ($DuplicateId) {
        $Status = 'DUPLICATE_ID'
    }
    elseif (-not $WavExists -and -not $Mp3Exists) {
        $Status = 'MISSING_WAV_AND_MP3'
    }
    elseif (-not $WavExists) {
        $Status = 'MISSING_WAV'
    }
    elseif (-not $Mp3Exists) {
        $Status = 'MISSING_MP3'
    }
    elseif ($WavSize -le 0 -and $Mp3Size -le 0) {
        $Status = 'EMPTY_WAV_AND_MP3'
    }
    elseif ($WavSize -le 0) {
        $Status = 'EMPTY_WAV'
    }
    elseif ($Mp3Size -le 0) {
        $Status = 'EMPTY_MP3'
    }

    $RecordReport += [PSCustomObject]@{
        position = $Position
        batch_number = $BatchNumber
        batch_id = $BatchId
        raw_id = $ResolvedRow.raw_id
        normalized_id = $ResolvedRow.normalized_id
        lexical_id = $ResolvedRow.lexical_id
        id_generated = $ResolvedRow.id_generated
        id_error = $ResolvedRow.id_error
        duplicate_id = $DuplicateId
        native_word = [string]$ResolvedRow.row.$NativeWordColumn
        native_pronunciation = [string]$ResolvedRow.row.$NativePronunciationColumn
        native_audio_source = [string]$ResolvedRow.row.$NativeAudioColumn
        primary_translation = [string]$ResolvedRow.row.$PrimaryTranslationColumn
        expected_wav = $ExpectedWav
        expected_mp3 = $ExpectedMp3
        wav_exists = $WavExists
        mp3_exists = $Mp3Exists
        wav_size_bytes = $WavSize
        mp3_size_bytes = $Mp3Size
        wav_sha256 = $WavSha
        mp3_sha256 = $Mp3Sha
        record_status = $Status
    }
}

$BatchReport = @(
    $RecordReport |
        Group-Object batch_id |
        Sort-Object Name |
        ForEach-Object {

            $Group = @($_.Group)

            [PSCustomObject]@{
                batch_id = $_.Name
                record_count = $Group.Count
                ready = @($Group | Where-Object record_status -eq 'READY').Count
                missing_wav = @($Group | Where-Object record_status -eq 'MISSING_WAV').Count
                missing_mp3 = @($Group | Where-Object record_status -eq 'MISSING_MP3').Count
                missing_both = @($Group | Where-Object record_status -eq 'MISSING_WAV_AND_MP3').Count
                empty_wav = @($Group | Where-Object record_status -eq 'EMPTY_WAV').Count
                empty_mp3 = @($Group | Where-Object record_status -eq 'EMPTY_MP3').Count
                empty_both = @($Group | Where-Object record_status -eq 'EMPTY_WAV_AND_MP3').Count
                duplicate_id = @($Group | Where-Object record_status -eq 'DUPLICATE_ID').Count
                invalid_id = @($Group | Where-Object record_status -eq 'INVALID_ID').Count
                batch_status = $(if (@($Group | Where-Object record_status -ne 'READY').Count -eq 0) { 'READY' } else { 'REVIEW_REQUIRED' })
            }
        }
)

$InvalidNames = @(
    $FileReport |
        Where-Object file_status -eq 'INVALID_NAME'
)

$UnexpectedFiles = @(
    $FileReport |
        Where-Object file_status -eq 'UNEXPECTED_FILE'
)

$EmptyFiles = @(
    $FileReport |
        Where-Object file_status -eq 'EMPTY_FILE'
)

$Summary = [ordered]@{
    total_records = $RecordReport.Count
    total_batches = $BatchReport.Count
    ready = @($RecordReport | Where-Object record_status -eq 'READY').Count
    missing_wav = @($RecordReport | Where-Object record_status -eq 'MISSING_WAV').Count
    missing_mp3 = @($RecordReport | Where-Object record_status -eq 'MISSING_MP3').Count
    missing_wav_and_mp3 = @($RecordReport | Where-Object record_status -eq 'MISSING_WAV_AND_MP3').Count
    empty_wav = @($RecordReport | Where-Object record_status -eq 'EMPTY_WAV').Count
    empty_mp3 = @($RecordReport | Where-Object record_status -eq 'EMPTY_MP3').Count
    empty_wav_and_mp3 = @($RecordReport | Where-Object record_status -eq 'EMPTY_WAV_AND_MP3').Count
    duplicate_id_records = @($RecordReport | Where-Object record_status -eq 'DUPLICATE_ID').Count
    invalid_id_records = @($RecordReport | Where-Object record_status -eq 'INVALID_ID').Count
    invalid_name_files = $InvalidNames.Count
    unexpected_files = $UnexpectedFiles.Count
    empty_files = $EmptyFiles.Count
    wav_files_found = $ActualWavFiles.Count
    mp3_files_found = $ActualMp3Files.Count
}

$IssueCount =
    $Summary.missing_wav +
    $Summary.missing_mp3 +
    $Summary.missing_wav_and_mp3 +
    $Summary.empty_wav +
    $Summary.empty_mp3 +
    $Summary.empty_wav_and_mp3 +
    $Summary.duplicate_id_records +
    $Summary.invalid_id_records +
    $Summary.invalid_name_files +
    $Summary.unexpected_files

$OverallStatus = 'READY'

if ($IssueCount -gt 0) {
    $OverallStatus = 'REVIEW_REQUIRED'
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $OutputDirectory |
    Out-Null

$RecordsCsv = Join-Path $OutputDirectory 'records.csv'
$RecordsJson = Join-Path $OutputDirectory 'records.json'
$BatchesCsv = Join-Path $OutputDirectory 'batches.csv'
$BatchesJson = Join-Path $OutputDirectory 'batches.json'
$FilesCsv = Join-Path $OutputDirectory 'files.csv'
$FilesJson = Join-Path $OutputDirectory 'files.json'
$SummaryJson = Join-Path $OutputDirectory 'summary.json'

Write-Utf8LfCsv -Path $RecordsCsv -Rows $RecordReport
Write-Utf8LfJson -Path $RecordsJson -Object $RecordReport
Write-Utf8LfCsv -Path $BatchesCsv -Rows $BatchReport
Write-Utf8LfJson -Path $BatchesJson -Object $BatchReport
Write-Utf8LfCsv -Path $FilesCsv -Rows $FileReport
Write-Utf8LfJson -Path $FilesJson -Object $FileReport

$SummaryDocument = [ordered]@{
    status = $OverallStatus
    instance_id = [string]$Instance.instance_id
    native_language = [string]$Instance.native_language.name
    native_language_code = $NativeLanguageCode
    drive_root = $DriveRoot
    batch_size = $BatchSize
    summary = $Summary
    outputs = [ordered]@{
        records_csv = $RecordsCsv
        records_json = $RecordsJson
        batches_csv = $BatchesCsv
        batches_json = $BatchesJson
        files_csv = $FilesCsv
        files_json = $FilesJson
    }
}

Write-Utf8LfJson `
    -Path $SummaryJson `
    -Object $SummaryDocument

[PSCustomObject]@{
    Status = $OverallStatus
    Records = $RecordReport.Count
    Batches = $BatchReport.Count
    Ready = $Summary.ready
    MissingWav = $Summary.missing_wav
    MissingMp3 = $Summary.missing_mp3
    MissingBoth = $Summary.missing_wav_and_mp3
    EmptyWav = $Summary.empty_wav
    EmptyMp3 = $Summary.empty_mp3
    DuplicateIds = $Summary.duplicate_id_records
    InvalidIds = $Summary.invalid_id_records
    InvalidNames = $Summary.invalid_name_files
    UnexpectedFiles = $Summary.unexpected_files
    EmptyFiles = $Summary.empty_files
    SummaryPath = $SummaryJson
}
