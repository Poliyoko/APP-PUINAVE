[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Rlb,

    [Parameter(Mandatory = $true)]
    [string]$Relations,

    [Parameter(Mandatory = $true)]
    [string]$Query,

    [int]$Limit = 20,

    [string]$Output = "artifacts/lexical_engine/SPT-007B/search-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.lexical_engine.semantic_cli `
    --rlb $Rlb `
    --relations $Relations `
    --query $Query `
    --limit $Limit `
    --output $Output

exit $LASTEXITCODE