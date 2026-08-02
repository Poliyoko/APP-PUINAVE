[CmdletBinding()]
param(
    [string]$Increment = "SGD-116B"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Output = "artifacts/pmo/SGD-114C"
New-Item -ItemType Directory -Path $Output -Force | Out-Null

& python -m sgoda.governance.policy_cli `
    --root "." `
    --policy "config/governance/SGD-114C-policy.json" `
    --increment $Increment `
    --output-json "$Output/$Increment-policy-result.json" `
    --output-md "$Output/$Increment-policy-result.md"

exit $LASTEXITCODE