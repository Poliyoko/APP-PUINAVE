[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,

    [Parameter(Mandatory=$true)]
    [string]$InputPath,

    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {

    $Base = Split-Path `
        -Parent `
        (Split-Path -Parent $ConfigPath)

    $OutputDirectory = Join-Path `
        $Base `
        'output\current'
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SGODA AUDIO MANAGER v0.1.0" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`n[1/4] Validando entrada minima..." -ForegroundColor Yellow

$ImportScript = Join-Path $PSScriptRoot 'Import-SGODAInput.ps1'

$Imported = & $ImportScript `
    -ConfigPath $ConfigPath `
    -InputPath $InputPath

Write-Host "Entrada: PASS ($(@($Imported.Rows).Count) registros)" -ForegroundColor Green

Write-Host "`n[2/4] Validando Drive..." -ForegroundColor Yellow

$DriveTestScript = Join-Path $PSScriptRoot 'Test-SGODADriveAudio.ps1'

$DriveResult = & $DriveTestScript `
    -ConfigPath $ConfigPath `
    -InputPath $InputPath

Write-Host "WAV    : $($DriveResult.WavCount)"
Write-Host "MP3    : $($DriveResult.Mp3Count)"
Write-Host "MASTER : $($DriveResult.MasterCount)"

if ($DriveResult.Status -ne 'PASS') {

    throw (
        "DRIVE QUALITY GATE: FAIL. " +
        "WAV faltantes=$($DriveResult.MissingWav.Count); " +
        "MP3 faltantes=$($DriveResult.MissingMp3.Count)"
    )
}

Write-Host "DRIVE QUALITY GATE: PASS" -ForegroundColor Green

Write-Host "`n[3/4] Generando Matriz Tecnologica..." -ForegroundColor Yellow

$MatrixScript = Join-Path $PSScriptRoot 'New-SGODATechnologyMatrix.ps1'

$MatrixResult = & $MatrixScript `
    -ConfigPath $ConfigPath `
    -InputPath $InputPath `
    -OutputDirectory $OutputDirectory

Write-Host "Matriz generada: $(@($MatrixResult.Matrix).Count) registros" -ForegroundColor Green

Write-Host "`n[4/4] Ejecutando Quality Gate..." -ForegroundColor Yellow

$MatrixTestScript = Join-Path $PSScriptRoot 'Test-SGODATechnologyMatrix.ps1'

$MatrixGate = & $MatrixTestScript `
    -MatrixPath $MatrixResult.CsvPath `
    -ExpectedRecords @($Imported.Rows).Count

Write-Host "Recursos faltantes : $($MatrixGate.MissingResources)"
Write-Host "Drive FAIL         : $($MatrixGate.DriveFailures)"
Write-Host "Nombres invalidos  : $($MatrixGate.InvalidFilenames)"
Write-Host "IDs duplicados     : $($MatrixGate.DuplicateLexicalIds)"
Write-Host "SHA WAV invalidos  : $($MatrixGate.InvalidWavHashes)"
Write-Host "SHA MP3 invalidos  : $($MatrixGate.InvalidMp3Hashes)"

if ($MatrixGate.Status -ne 'PASS') {
    throw "MATRIX QUALITY GATE: FAIL"
}

Write-Host ""
Write-Host "MATRIX QUALITY GATE: PASS" -ForegroundColor Green

Write-Host "`nCSV :" $MatrixResult.CsvPath
Write-Host "JSON:" $MatrixResult.JsonPath

Write-Host ""
Write-Host "SGODA AUDIO MANAGER v0.1.0: PASS" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan

[PSCustomObject]@{
    Status      = 'PASS'
    Records     = @($Imported.Rows).Count
    CsvPath     = $MatrixResult.CsvPath
    JsonPath    = $MatrixResult.JsonPath
    DriveStatus = $DriveResult.Status
    MatrixStatus= $MatrixGate.Status
}
