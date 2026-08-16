[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,

    [Parameter(Mandatory=$true)]
    [string]$InputPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "No existe la configuracion: $ConfigPath"
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "No existe la entrada minima: $InputPath"
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

if ($Rows.Count -eq 0) {
    throw "La entrada minima no contiene registros."
}

$NativeName = [string]$Config.instance.native_language.name
$AuxName    = [string]$Config.instance.primary_auxiliary_language.name

$NativeUpper = $NativeName.ToUpper()
$AuxUpper    = $AuxName.ToUpper()

$Columns = [ordered]@{
    Id                 = 'ID'
    NativeWord         = "PALABRA EN $NativeUpper"
    NativePronunciation= "PRONUNCIACION EN $NativeUpper"
    NativeAudio        = "AUDIO EN $NativeUpper"
    PrimaryTranslation = "PALABRA EN $AuxUpper"
}

$RequiredColumns = @(
    $Columns.Id
    $Columns.NativeWord
    $Columns.NativePronunciation
    $Columns.NativeAudio
    $Columns.PrimaryTranslation
)

$ActualColumns = @(
    $Rows[0].PSObject.Properties.Name
)

$MissingColumns = @(
    $RequiredColumns |
        Where-Object { $_ -notin $ActualColumns }
)

if ($MissingColumns.Count -gt 0) {

    throw (
        "Columnas obligatorias faltantes: " +
        ($MissingColumns -join ', ')
    )
}

$DuplicateIds = @(
    $Rows |
        Group-Object -Property $Columns.Id |
        Where-Object Count -gt 1
)

if ($DuplicateIds.Count -gt 0) {

    throw (
        "IDs duplicados detectados: " +
        (($DuplicateIds | Select-Object -ExpandProperty Name) -join ', ')
    )
}

foreach ($Row in $Rows) {

    $RawId = [string]$Row.($Columns.Id)

    if ($RawId -notmatch '^\d+$') {
        throw "ID no numerico detectado: $RawId"
    }
}

[PSCustomObject]@{
    Config  = $Config
    Rows    = $Rows
    Columns = [PSCustomObject]$Columns
}
