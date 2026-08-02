[CmdletBinding()]
param(
    [switch]$RequireCleanGit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.governance.repository_governance",
    "--root",
    $Root,
    "--policy",
    "config/governance/sgd-114-v2-repository-policy.json",
    "--audit-output",
    "artifacts/pmo/SGD-114-v2/repository-audit.json",
    "--manifest-output",
    "artifacts/pmo/SGD-114-v2/repository-manifest.json",
    "--event-output",
    "artifacts/pmo/SGD-114-v2/repository-governance-event.json"
)

if ($RequireCleanGit) {
    $Arguments += "--require-clean-git"
}

& python @Arguments

if ($LASTEXITCODE -ne 0) {
    throw "La auditoría SGD-114 v2.0 no fue aprobada."
}