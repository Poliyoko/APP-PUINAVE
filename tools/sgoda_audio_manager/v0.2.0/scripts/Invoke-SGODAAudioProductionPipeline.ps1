[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,

    [Parameter(Mandatory=$true)]
    [string]$InputPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory=$false)]
    [string]$LinguisticBaselinePath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

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
    throw 'Entrada vacia.'
}

$IdEngine = Join-Path $PSScriptRoot 'Resolve-SGODALexicalIds.ps1'
$BatchEngine = Join-Path $PSScriptRoot 'New-SGODADynamicBatchPlan.ps1'
$DriveValidator = Join-Path $PSScriptRoot 'Test-SGODAMassiveDrive.ps1'
$LinguisticValidator = Join-Path $PSScriptRoot 'Test-SGODALinguisticIntegrity.ps1'

foreach ($Path in @(
    $IdEngine,
    $BatchEngine,
    $DriveValidator,
    $LinguisticValidator
)) {

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Componente faltante: $Path"
    }
}

$Prefix = [string]$Config.instance.lexical_prefix
$IdWidth = [int]$Config.instance.id_width
$IdMode = [string]$Config.input.id_mode
$StartId = [int]$Config.input.generated_id_start
$BatchSize = [int]$Config.production.batch_size

$Ids = @(
    & $IdEngine `
        -Rows $Rows `
        -LexicalPrefix $Prefix `
        -IdWidth $IdWidth `
        -IdMode $IdMode `
        -StartId $StartId
)

if ($Ids.Count -ne $Rows.Count) {
    throw 'ID engine cardinality mismatch.'
}

$BatchPlan = & $BatchEngine `
    -RecordCount $Rows.Count `
    -BatchSize $BatchSize `
    -StartId $StartId `
    -IdWidth $IdWidth `
    -LexicalPrefix $Prefix

$LinguisticResult = $null

if (-not [string]::IsNullOrWhiteSpace($LinguisticBaselinePath)) {

    $LinguisticResult = & $LinguisticValidator `
        -ConfigPath $ConfigPath `
        -InputPath $InputPath `
        -BaselinePath $LinguisticBaselinePath

    if ($LinguisticResult.Status -ne 'PASS') {
        throw "LINGUISTIC INTEGRITY: FAIL - Differences=$($LinguisticResult.Differences)"
    }
}

$DriveResult = & $DriveValidator `
    -ConfigPath $ConfigPath `
    -InputPath $InputPath `
    -OutputDirectory $OutputDirectory

if ($DriveResult.Records -ne $Rows.Count) {
    throw 'Drive validator cardinality mismatch.'
}

if ($DriveResult.Batches -ne $BatchPlan.batch_count) {
    throw 'Drive validator batch count mismatch.'
}

$Status = $DriveResult.Status

[PSCustomObject]@{
    Status = $Status
    Records = $Rows.Count
    ResolvedIds = $Ids.Count
    Batches = $BatchPlan.batch_count
    BatchSize = $BatchSize
    DriveStatus = $DriveResult.Status
    Ready = $DriveResult.Ready
    MissingWav = $DriveResult.MissingWav
    MissingMp3 = $DriveResult.MissingMp3
    MissingBoth = $DriveResult.MissingBoth
    DuplicateIds = $DriveResult.DuplicateIds
    InvalidNames = $DriveResult.InvalidNames
    UnexpectedFiles = $DriveResult.UnexpectedFiles
    EmptyFiles = $DriveResult.EmptyFiles
    LinguisticStatus = $(if ($null -eq $LinguisticResult) { 'NOT_REQUESTED' } else { $LinguisticResult.Status })
    LinguisticDifferences = $(if ($null -eq $LinguisticResult) { 0 } else { $LinguisticResult.Differences })
    SummaryPath = $DriveResult.SummaryPath
}
