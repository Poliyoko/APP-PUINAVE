[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Graph,

    [Parameter(Mandatory = $true)]
    [string]$Node,

    [Parameter(Mandatory = $true)]
    [string]$Message,

    [string]$Output = "artifacts/integrated_intelligence/conversation-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.conversation.cli `
    --graph $Graph `
    --node $Node `
    --message $Message `
    --output $Output

exit $LASTEXITCODE