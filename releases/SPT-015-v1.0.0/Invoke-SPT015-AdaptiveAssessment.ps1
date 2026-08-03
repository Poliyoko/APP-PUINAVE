[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [string]$Output = "artifacts/adaptive_assessment/SPT-015/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.adaptive_assessment.cli `
    --request-file "$RequestFile" `
    --output "$Output"

exit $LASTEXITCODE