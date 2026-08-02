[CmdletBinding()]
param(
    [string]$Provider = "mock",
    [int]$Limit = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.automation.adapters.processor `
    --jobs "artifacts/automation/SPT-003A/multimedia-jobs.sqlite3" `
    --storage "artifacts/automation/SPT-003B/media" `
    --events "artifacts/automation/SPT-003B/multimedia-events.jsonl" `
    --rmr "artifacts/media/ADR-010/rmr.sqlite3" `
    --provider $Provider `
    --limit $Limit `
    --summary "artifacts/automation/SPT-003B/processing-summary.json"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-003B terminó con errores."
}