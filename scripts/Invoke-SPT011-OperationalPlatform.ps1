[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Settings,

    [Parameter(Mandatory = $true)]
    [string]$Rlb,

    [string]$Media,

    [Parameter(Mandatory = $true)]
    [string]$Operation,

    [string]$Entry,

    [string]$Payload = "{}",

    [string]$Output = "artifacts/operational_platform/SPT-011/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.operational_platform.cli",
    "--settings",
    $Settings,
    "--rlb",
    $Rlb,
    "--operation",
    $Operation,
    "--payload",
    $Payload,
    "--output",
    $Output
)

if ($Media) {
    $Arguments += @("--media", $Media)
}

if ($Entry) {
    $Arguments += @("--entry", $Entry)
}

& python @Arguments
exit $LASTEXITCODE