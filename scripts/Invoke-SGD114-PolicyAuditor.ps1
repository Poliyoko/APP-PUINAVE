[CmdletBinding()]
param(
    [string]$Increment = "SGD-116B"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Policy = "config/governance/sgd-114-policy.json"
$OutputDir = "artifacts/pmo/SGD-114-Policy-Auditor"
$Gate = Join-Path $OutputDir "$Increment-quality-gate.json"
$Json = Join-Path $OutputDir "$Increment-policy-audit.json"
$Markdown = Join-Path $OutputDir "$Increment-policy-audit.md"

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

& python -m sgoda.governance.evidence_policy `
    --root "." `
    --policy $Policy `
    --increment $Increment `
    --status "technically_completed" `
    --output $Gate

$GateExitCode = $LASTEXITCODE

if (-not (Test-Path -LiteralPath $Gate)) {
    throw "El motor evidence_policy no produjo evidencia."
}

& python -m sgoda.governance.policy_auditor `
    --root "." `
    --policy $Policy `
    --gate $Gate `
    --increment $Increment `
    --output-json $Json `
    --output-md $Markdown

if ($LASTEXITCODE -ne 0) {
    throw "El Policy Auditor terminó con errores."
}

Write-Host ""
Write-Host "Quality gate exit code: $GateExitCode" -ForegroundColor Cyan
Write-Host "Informe JSON: $Json" -ForegroundColor Cyan
Write-Host "Informe Markdown: $Markdown" -ForegroundColor Cyan