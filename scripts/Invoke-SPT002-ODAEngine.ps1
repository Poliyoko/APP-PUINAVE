[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.oda.cli `
    --canonical "artifacts/rlb/SPT-001B-P08/canonical-repository-v1.0.0.json" `
    --active-schema "config/rlb/active-schema.json" `
    --output "artifacts/oda/SPT-002"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-002 terminó con errores."
}