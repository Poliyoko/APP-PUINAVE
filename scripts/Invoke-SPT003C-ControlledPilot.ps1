[CmdletBinding()]
param(
    [string]$Provider = "mock",
    [int]$Limit = 2,
    [string]$ApprovalPath = "",
    [switch]$Live
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.automation.pilot.runner",
    "--provider",
    $Provider,
    "--limit",
    $Limit,
    "--pricing",
    "config/automation/SPT-003C-pricing-template.json"
)

if (-not [string]::IsNullOrWhiteSpace($ApprovalPath)) {
    $Arguments += @("--approval", $ApprovalPath)
}

if ($Live) {
    $Arguments += "--live"
}

& python @Arguments

if ($LASTEXITCODE -ne 0) {
    throw "SPT-003C terminó con errores."
}