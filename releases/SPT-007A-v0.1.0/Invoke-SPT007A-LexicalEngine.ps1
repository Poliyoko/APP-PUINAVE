[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Rlb,

    [Parameter(Mandatory = $true)]
    [string]$Query,

    [int]$Limit = 20,

    [string]$Output = "artifacts/lexical_engine/SPT-007A/search-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.lexical_engine.cli `
    --rlb $Rlb `
    --query $Query `
    --limit $Limit `
    --output $Output

exit $LASTEXITCODE