[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.automation.cli `
    --rmr "artifacts/media/ADR-010/rmr.sqlite3" `
    --oda "artifacts/oda/SPT-002/oda-repository-v0.1.0.json" `
    --jobs "artifacts/automation/SPT-003A/multimedia-jobs.sqlite3" `
    --output "artifacts/automation/SPT-003A"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-003A terminÃ³ con errores."
}