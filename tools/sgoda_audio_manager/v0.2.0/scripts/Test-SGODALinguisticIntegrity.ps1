[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,

    [Parameter(Mandatory=$true)]
    [string]$InputPath,

    [Parameter(Mandatory=$true)]
    [string]$BaselinePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

foreach ($Path in @($ConfigPath,$InputPath,$BaselinePath)) {

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No existe recurso requerido: $Path"
    }
}

$Config = Get-Content `
    -LiteralPath $ConfigPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$Current = @(
    Import-Csv `
        -LiteralPath $InputPath `
        -Encoding UTF8
)

$Baseline = @(
    Import-Csv `
        -LiteralPath $BaselinePath `
        -Encoding UTF8
)

if ($Current.Count -lt 1 -or $Baseline.Count -lt 1) {
    throw 'Entrada o baseline vacia.'
}

$IdEngine = Join-Path `
    $PSScriptRoot `
    'Resolve-SGODALexicalIds.ps1'

if (-not (Test-Path -LiteralPath $IdEngine)) {
    throw "No existe gestor de IDs: $IdEngine"
}

$Instance = $Config.instance
$InputConfig = $Config.input
$Columns = $InputConfig.columns

$Prefix = [string]$Instance.lexical_prefix
$IdWidth = [int]$Instance.id_width
$IdMode = [string]$InputConfig.id_mode
$StartId = [int]$InputConfig.generated_id_start

if ([string]::IsNullOrWhiteSpace($IdMode)) {
    $IdMode = 'input_or_generate'
}

$CurrentResolved = @(
    & $IdEngine `
        -Rows $Current `
        -LexicalPrefix $Prefix `
        -IdWidth $IdWidth `
        -IdMode $IdMode `
        -StartId $StartId
)

$BaselineResolved = @(
    & $IdEngine `
        -Rows $Baseline `
        -LexicalPrefix $Prefix `
        -IdWidth $IdWidth `
        -IdMode $IdMode `
        -StartId $StartId
)

if ($CurrentResolved.Count -ne $Current.Count) {
    throw 'Current ID resolution cardinality mismatch.'
}

if ($BaselineResolved.Count -ne $Baseline.Count) {
    throw 'Baseline ID resolution cardinality mismatch.'
}

$NativeUpper = ([string]$Instance.native_language.name).ToUpperInvariant()
$PrimaryUpper = ([string]$Instance.primary_auxiliary_language.name).ToUpperInvariant()

$NativeWordColumn = ([string]$Columns.native_word_template).Replace('{NATIVE_LANGUAGE}',$NativeUpper)
$NativePronunciationColumn = ([string]$Columns.native_pronunciation_template).Replace('{NATIVE_LANGUAGE}',$NativeUpper)
$NativeAudioColumn = ([string]$Columns.native_audio_template).Replace('{NATIVE_LANGUAGE}',$NativeUpper)
$PrimaryTranslationColumn = ([string]$Columns.primary_translation_template).Replace('{PRIMARY_AUXILIARY_LANGUAGE}',$PrimaryUpper)

$CompareFields = @(
    $NativeWordColumn,
    $NativePronunciationColumn,
    $NativeAudioColumn,
    $PrimaryTranslationColumn
)

$BaselineIndex = @{}
$CurrentIndex = @{}

foreach ($Resolved in $BaselineResolved) {

    $Key = [string]$Resolved.lexical_id

    if ([string]::IsNullOrWhiteSpace($Key)) {
        throw 'Baseline no pudo resolver lexical_id.'
    }

    if ($BaselineIndex.ContainsKey($Key)) {
        throw "Baseline con ID duplicado: $Key"
    }

    $BaselineIndex[$Key] = $Resolved.row
}

foreach ($Resolved in $CurrentResolved) {

    $Key = [string]$Resolved.lexical_id

    if ([string]::IsNullOrWhiteSpace($Key)) {
        throw 'Entrada no pudo resolver lexical_id.'
    }

    if ($CurrentIndex.ContainsKey($Key)) {
        throw "Entrada con ID duplicado: $Key"
    }

    $CurrentIndex[$Key] = $Resolved.row
}

$Missing = @(
    $BaselineIndex.Keys |
        Where-Object { -not $CurrentIndex.ContainsKey($_) } |
        Sort-Object
)

$Unexpected = @(
    $CurrentIndex.Keys |
        Where-Object { -not $BaselineIndex.ContainsKey($_) } |
        Sort-Object
)

$Differences = @()

foreach ($LexicalId in ($BaselineIndex.Keys | Sort-Object)) {

    if (-not $CurrentIndex.ContainsKey($LexicalId)) {
        continue
    }

    foreach ($Field in $CompareFields) {

        $Expected = [string]$BaselineIndex[$LexicalId].$Field
        $Actual = [string]$CurrentIndex[$LexicalId].$Field

        if ($Expected -cne $Actual) {

            $Differences += [PSCustomObject]@{
                lexical_id = $LexicalId
                field = $Field
                expected = $Expected
                actual = $Actual
            }
        }
    }
}

$Status = 'PASS'

if ($Missing.Count -gt 0 -or
    $Unexpected.Count -gt 0 -or
    $Differences.Count -gt 0) {

    $Status = 'FAIL'
}

[PSCustomObject]@{
    Status = $Status
    CurrentRecords = $Current.Count
    BaselineRecords = $Baseline.Count
    CurrentResolvedIds = $CurrentResolved.Count
    BaselineResolvedIds = $BaselineResolved.Count
    IdMode = $IdMode
    MissingIds = $Missing.Count
    UnexpectedIds = $Unexpected.Count
    Differences = $Differences.Count
    DifferenceItems = $Differences
    MissingItems = $Missing
    UnexpectedItems = $Unexpected
}
