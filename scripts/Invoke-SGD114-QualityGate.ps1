[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$IncrementCode,

    [ValidateSet(
        "planned",
        "in_progress",
        "technically_completed",
        "institutionally_closed",
        "blocked"
    )]
    [string]$RequestedStatus = "technically_completed",

    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $SafeCode = $IncrementCode -replace "[^A-Za-z0-9_.-]", "_"
    $OutputPath = Join-Path `
        $Root `
        "artifacts\pmo\SGD-114\$SafeCode-quality-gate.json"
}

python -m sgoda.governance.evidence_policy `
    --root "$Root" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "$IncrementCode" `
    --status "$RequestedStatus" `
    --output "$OutputPath"

$ExitCode = $LASTEXITCODE

if ($ExitCode -eq 0) {
    Write-Host ""
    Write-Host "Quality gate SGD-114 aprobado." -ForegroundColor Green
}
elseif ($ExitCode -eq 2) {
    Write-Host ""
    Write-Host "Quality gate SGD-114 no aprobado." -ForegroundColor Yellow
}
else {
    throw "SGD-114 terminó con código $ExitCode."
}

exit $ExitCode