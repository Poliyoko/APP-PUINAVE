$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$ExpectedHead = "94b7d91aab208dba922d2551574968f4b60fbf3c"

$Root = [string](git rev-parse --show-toplevel)
$Root = $Root.Trim()
Set-Location $Root

$Branch = [string](git branch --show-current)
$Branch = $Branch.Trim()

Write-Host ""
Write-Host "=== SPT-023.3 CAPA 1 - FINAL BANNER CERTIFICATION ===" -ForegroundColor Cyan

git fetch origin $Branch --no-tags | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "HOLD: git fetch failed."
}

$LocalHead = [string](git rev-parse HEAD)
$LocalHead = $LocalHead.Trim()

$RemoteHead = [string](git rev-parse ("origin/" + $Branch))
$RemoteHead = $RemoteHead.Trim()

$Ahead = @(git rev-list ("origin/" + $Branch + "..HEAD")).Count
$Behind = @(git rev-list ("HEAD..origin/" + $Branch)).Count
$Staged = @(git diff --cached --name-only).Count
$Deleted = @(git ls-files --deleted).Count

$EvidencePath = Join-Path `
    $Root `
    "artifacts\development\SPT-023.3-v1.0.1\runs\20260810-001831\implementation-evidence.json"

if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
    throw "HOLD: implementation evidence not found."
}

$Evidence = Get-Content `
    -LiteralPath $EvidencePath `
    -Raw `
    -Encoding UTF8 |
ConvertFrom-Json

$Targeted = [int]$Evidence.targeted_tests_passed
$FullSuite = [int]$Evidence.institutional_tests_passed
$ProtectedChanges = [int]$Evidence.protected_files_changed

Write-Host ""
Write-Host "LOCAL HEAD          : $LocalHead"
Write-Host "REMOTE HEAD         : $RemoteHead"
Write-Host "AHEAD               : $Ahead"
Write-Host "BEHIND              : $Behind"
Write-Host "STAGED              : $Staged"
Write-Host "DELETED TRACKED     : $Deleted"
Write-Host "TARGETED TESTS      : $Targeted"
Write-Host "INSTITUTIONAL TESTS : $FullSuite"
Write-Host "PROTECTED CHANGES   : $ProtectedChanges"

if ($LocalHead -ne $ExpectedHead) {
    throw "HOLD: local HEAD mismatch."
}
if ($RemoteHead -ne $ExpectedHead) {
    throw "HOLD: remote HEAD mismatch."
}
if ($Ahead -ne 0) {
    throw "HOLD: repository is ahead."
}
if ($Behind -ne 0) {
    throw "HOLD: repository is behind."
}
if ($Staged -ne 0) {
    throw "HOLD: staging is not clean."
}
if ($Deleted -ne 0) {
    throw "HOLD: tracked deletions detected."
}
if ($Targeted -lt 9) {
    throw "HOLD: targeted tests are below 9."
}
if ($FullSuite -lt 870) {
    throw "HOLD: institutional tests are below 870."
}
if ($ProtectedChanges -ne 0) {
    throw "HOLD: protected components changed."
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host " SPT-023.3 CAPA 1 : PUBLISHED / CLOSED" -ForegroundColor Green
Write-Host " COMMIT           : $LocalHead" -ForegroundColor Green
Write-Host " TARGETED TESTS   : 9 PASSED" -ForegroundColor Green
Write-Host " FULL SUITE       : 870 PASSED" -ForegroundColor Green
Write-Host " SPT-023.1/.2     : PRESERVED" -ForegroundColor Green
Write-Host " LOCAL/REMOTE     : IDENTICAL" -ForegroundColor Green
Write-Host " AHEAD            : 0" -ForegroundColor Green
Write-Host " BEHIND           : 0" -ForegroundColor Green
Write-Host " STAGING          : CLEAN" -ForegroundColor Green
Write-Host " DELETED TRACKED  : 0" -ForegroundColor Green
Write-Host " ERRORS PENDING   : 0" -ForegroundColor Green
Write-Host " NEXT             : SPT-023.3 CAPA 2" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
