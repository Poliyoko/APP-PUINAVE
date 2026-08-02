<#
.SYNOPSIS
    Plantilla de correctivo versionado para SPT-999A.
#>
[CmdletBinding()]
param([string]$ProjectRoot = (Get-Location).Path)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $ProjectRoot "artifacts/pmo/SPT-999A/backups/$Timestamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
try {
    # TODO: validar instalaciÃ³n parcial, respaldar y corregir.
    & python -m py_compile "src/sgoda/<module>/module.py"
    if ($LASTEXITCODE -ne 0) { throw "La sintaxis continÃºa con errores." }
    & python -m pytest "tests/<module>/test_SPT_999A.py::test_case" -q
    if ($LASTEXITCODE -ne 0) { throw "La prueba puntual continÃºa fallando." }
    & python -m pytest "tests/<module>/test_SPT_999A.py" -q
    if ($LASTEXITCODE -ne 0) { throw "Las pruebas especÃ­ficas fallaron." }
    & python -m pytest
    if ($LASTEXITCODE -ne 0) { throw "La suite completa fallÃ³." }
    Write-Host "Correctivo SPT-999A validado." -ForegroundColor Green
}
catch {
    Write-Host "Correctivo fallido. Respaldo: $BackupDir" -ForegroundColor Red
    throw
}
