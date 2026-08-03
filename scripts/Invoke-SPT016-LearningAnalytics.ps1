[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [string]$Output = "artifacts/learning_analytics/SPT-016/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.learning_analytics.cli `
    --request-file "$RequestFile" `
    --output "$Output"

exit $LASTEXITCODE