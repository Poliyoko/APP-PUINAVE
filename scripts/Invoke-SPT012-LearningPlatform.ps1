[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Dictionary,

    [Parameter(Mandatory = $true)]
    [string]$Media,

    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [string]$Output = "artifacts/learning_platform/SPT-012/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.learning_platform.cli `
    --dictionary "$Dictionary" `
    --media "$Media" `
    --request-file "$RequestFile" `
    --output "$Output"

exit $LASTEXITCODE