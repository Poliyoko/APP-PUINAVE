[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,

    [Parameter(Mandatory=$true)]
    [string]$InputPath
)

$ErrorActionPreference = 'Stop'

$ImportScript = Join-Path $PSScriptRoot 'Import-SGODAInput.ps1'

$Imported = & $ImportScript `
    -ConfigPath $ConfigPath `
    -InputPath $InputPath

$Config  = $Imported.Config
$Rows    = @($Imported.Rows)
$Columns = $Imported.Columns

$Prefix      = [string]$Config.instance.lexical_prefix
$IdWidth     = [int]$Config.instance.id_width
$NativeCode  = [string]$Config.instance.native_language.code

$DriveRoot = [string]$Config.storage.root

if ([string]$Config.storage.type -ne 'drive') {
    throw "SGODA AudioManager requiere storage.type=drive."
}

if ([string]::IsNullOrWhiteSpace($DriveRoot)) {
    throw "La instancia no tiene configurado storage.root."
}

$WavPath = Join-Path `
    $DriveRoot `
    ([string]$Config.storage.folders.wav)

$Mp3Path = Join-Path `
    $DriveRoot `
    ([string]$Config.storage.folders.mp3)

$MasterPath = Join-Path `
    $DriveRoot `
    ([string]$Config.storage.folders.master)

foreach ($Path in @($DriveRoot,$WavPath,$Mp3Path,$MasterPath)) {

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Ruta Drive requerida no encontrada: $Path"
    }
}

$ExpectedWav = @()
$ExpectedMp3 = @()

foreach ($Row in $Rows) {

    $NumericId = [int]([string]$Row.($Columns.Id))
    $RecordId  = $NumericId.ToString(('0' * $IdWidth))
    $LexicalId = "$Prefix-$RecordId"

    $ExpectedWav += "${LexicalId}_${NativeCode}.wav"
    $ExpectedMp3 += "${LexicalId}_${NativeCode}.mp3"
}

$ActualWav = @(
    Get-ChildItem `
        -LiteralPath $WavPath `
        -Filter '*.wav' `
        -File
)

$ActualMp3 = @(
    Get-ChildItem `
        -LiteralPath $Mp3Path `
        -Filter '*.mp3' `
        -File
)

$ActualMaster = @(
    Get-ChildItem `
        -LiteralPath $MasterPath `
        -Filter '*.wav' `
        -File
)

$ActualWavNames = @($ActualWav.Name)
$ActualMp3Names = @($ActualMp3.Name)

$MissingWav = @(
    $ExpectedWav |
        Where-Object { $_ -notin $ActualWavNames }
)

$MissingMp3 = @(
    $ExpectedMp3 |
        Where-Object { $_ -notin $ActualMp3Names }
)

$UnexpectedWav = @(
    $ActualWavNames |
        Where-Object { $_ -notin $ExpectedWav }
)

$UnexpectedMp3 = @(
    $ActualMp3Names |
        Where-Object { $_ -notin $ExpectedMp3 }
)

$EmptyWav = @(
    $ActualWav |
        Where-Object Length -le 0
)

$EmptyMp3 = @(
    $ActualMp3 |
        Where-Object Length -le 0
)

$Status = 'PASS'

if ($MissingWav.Count -gt 0)    { $Status = 'FAIL' }
if ($MissingMp3.Count -gt 0)    { $Status = 'FAIL' }
if ($UnexpectedWav.Count -gt 0) { $Status = 'FAIL' }
if ($UnexpectedMp3.Count -gt 0) { $Status = 'FAIL' }
if ($EmptyWav.Count -gt 0)      { $Status = 'FAIL' }
if ($EmptyMp3.Count -gt 0)      { $Status = 'FAIL' }

[PSCustomObject]@{
    Status            = $Status
    ExpectedRecords   = $Rows.Count

    WavCount          = $ActualWav.Count
    Mp3Count          = $ActualMp3.Count
    MasterCount       = $ActualMaster.Count

    MissingWav        = $MissingWav
    MissingMp3        = $MissingMp3

    UnexpectedWav     = $UnexpectedWav
    UnexpectedMp3     = $UnexpectedMp3

    EmptyWavCount     = $EmptyWav.Count
    EmptyMp3Count     = $EmptyMp3.Count

    DriveRoot         = $DriveRoot
    WavPath           = $WavPath
    Mp3Path           = $Mp3Path
    MasterPath        = $MasterPath
}
