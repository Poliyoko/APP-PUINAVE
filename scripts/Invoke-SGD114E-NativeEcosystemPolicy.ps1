[CmdletBinding()]
param(
    [string]$OutputDirectory = "artifacts/pmo/SGD-114E"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Json = Join-Path $OutputDirectory "SGD-114E-repository-evaluation.json"
$Markdown = Join-Path $OutputDirectory "SGD-114E-repository-evaluation.md"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$Root" `
    --output-json "$Json" `
    --output-md "$Markdown"

exit $LASTEXITCODE