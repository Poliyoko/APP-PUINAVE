[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location -LiteralPath $Root

$env:SGODA_PROJECT_ROOT = $Root
$env:N8N_HOST = "127.0.0.1"
$env:N8N_PORT = "5678"
$env:N8N_PROTOCOL = "http"
$env:N8N_USER_FOLDER = Join-Path $Root ".runtime\n8n"
$env:N8N_DIAGNOSTICS_ENABLED = "false"
$env:N8N_PERSONALIZATION_ENABLED = "false"

New-Item -ItemType Directory -Path $env:N8N_USER_FOLDER -Force | Out-Null

$n8n = Get-Command n8n.cmd -ErrorAction SilentlyContinue
if ($null -eq $n8n) {
    throw "n8n no esta instalado. Ejecute el instalador SPT-022 con -InstallN8n."
}

& $n8n.Source start
exit $LASTEXITCODE