$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$Root = (git rev-parse --show-toplevel).Trim()
Set-Location -LiteralPath $Root

$Records = Join-Path $Root 'tools\sgoda_audio_manager\v0.3.0\evidence\real-5\20260817T055528Z\validator-real-25\records.json'
$Summary = Join-Path $Root 'tools\sgoda_audio_manager\v0.3.0\evidence\real-5\20260817T055528Z\validator-real-25\summary.json'

$Config = Get-Content -LiteralPath $Summary -Raw -Encoding UTF8 | ConvertFrom-Json
$DriveRoot = [string]$Config.drive_root

if (-not (Test-Path -LiteralPath $Records -PathType Leaf)) {
    throw "REAL-25 records missing."
}

if (-not (Test-Path -LiteralPath $DriveRoot -PathType Container)) {
    throw "Google Drive audio root unavailable: $DriveRoot"
}

$env:PYTHONPATH = Join-Path $Root 'src'
$env:SGODA_PILOT25_RECORDS = $Records
$env:SGODA_PILOT25_DRIVE_ROOT = $DriveRoot

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SGODA-PUINAVE DEMO-READY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "WEB  : http://127.0.0.1:8010/"
Write-Host "API  : http://127.0.0.1:8010/api/demo/pilot25"
Write-Host "DOCS : http://127.0.0.1:8010/docs"
Write-Host ""

$PythonExe = Join-Path $Root '.venv\Scripts\python.exe'

if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
    throw "SGODA .venv Python not found: $PythonExe"
}

& $PythonExe -m uvicorn sgoda.demo_ready.app:app --host 127.0.0.1 --port 8010

if ($LASTEXITCODE -ne 0) {
    throw "Demo-Ready API terminated with error."
}