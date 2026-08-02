[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Graph,

    [Parameter(Mandatory = $true)]
    [string]$Node,

    [string]$Output = "artifacts/knowledge_engine/SPT-007C/query-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.knowledge_engine.cli `
    --graph $Graph `
    --node $Node `
    --output $Output

exit $LASTEXITCODE