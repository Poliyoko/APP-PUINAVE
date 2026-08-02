[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Increment,

    [string]$OutputDirectory = "artifacts/pmo/SGD-114D"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Json = Join-Path $OutputDirectory ($Increment + "-adaptive-policy-result.json")
$Markdown = Join-Path $OutputDirectory ($Increment + "-adaptive-policy-result.md")

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$Root" `
    --increment "$Increment" `
    --output-json "$Json" `
    --output-md "$Markdown"

exit $LASTEXITCODE