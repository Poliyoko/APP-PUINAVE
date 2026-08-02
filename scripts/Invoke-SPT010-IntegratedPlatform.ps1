[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Graph,

    [Parameter(Mandatory = $true)]
    [string]$Operation,

    [string]$Payload = "{}",

    [string]$Node,

    [string]$Session = "anonymous",

    [string]$Language = "es",

    [string]$Output = "artifacts/platform/SPT-010/operation-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.platform.cli",
    "--graph",
    $Graph,
    "--operation",
    $Operation,
    "--payload",
    $Payload,
    "--session",
    $Session,
    "--language",
    $Language,
    "--output",
    $Output,
    "--root",
    "."
)

if ($Node) {
    $Arguments += @("--node", $Node)
}

& python @Arguments
exit $LASTEXITCODE