[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.media.cli `
    --oda-repository "artifacts/oda/SPT-002/oda-repository-v0.1.0.json" `
    --database "artifacts/media/ADR-010/rmr.sqlite3" `
    --output "artifacts/media/ADR-010"

if ($LASTEXITCODE -ne 0) {
    throw "ADR-010 RMR terminó con errores."
}