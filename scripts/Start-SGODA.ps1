[CmdletBinding()]
param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvPython = Join-Path $Root ".venv\Scripts\python.exe"

if (-not (Test-Path $VenvPython)) {
    throw "No existe .venv. Ejecute primero: .\scripts\Install-SPB0051-F001.ps1"
}

$env:PYTHONPATH = Join-Path $Root "src"
& $VenvPython -m uvicorn sgoda.main:app --host $HostAddress --port $Port --reload
