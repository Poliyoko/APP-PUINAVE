[CmdletBinding()]
param([string]$RepositoryRoot=(Get-Location).Path,[switch]$RunBuilderTests)
$ErrorActionPreference="Stop"
Set-Location $RepositoryRoot
$env:PYTHONPATH=Join-Path $RepositoryRoot "src"

python -m pytest -q tests/pmo/audit
if($LASTEXITCODE -ne 0){ throw "Fallaron las pruebas del Auditor PMO." }

if($RunBuilderTests -and (Test-Path "builder")){
  Push-Location builder
  try{
    python -m pytest -q
    if($LASTEXITCODE -ne 0){ throw "Falló la suite Builder." }
  } finally { Pop-Location }
}

python -m sgoda.pmo.audit.cli --repository $RepositoryRoot --output (Join-Path $RepositoryRoot "artifacts/audit/spb-003.2")
if($LASTEXITCODE -eq 2){ Write-Warning "Existen acciones antes del cierre."; exit 2 }
if($LASTEXITCODE -ne 0){ throw "Falló el Auditor modular." }