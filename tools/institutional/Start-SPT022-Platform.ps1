[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()

$Gateway = Join-Path $Root "tools\institutional\Start-SPT022-Gateway.ps1"
$N8n = Join-Path $Root "tools\institutional\Start-SPT022-n8n.ps1"

Start-Process powershell.exe -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "`"$Gateway`""
)

Start-Sleep -Seconds 2

Start-Process powershell.exe -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "`"$N8n`""
)

Write-Host "SPT-022 runtime launch requested."
Write-Host "FastAPI: http://127.0.0.1:8000/api/spt022/health"
Write-Host "n8n:     http://127.0.0.1:5678"