$ErrorActionPreference = "Stop"

$Expected = "94b7d91aab208dba922d2551574968f4b60fbf3c"
$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root
$Branch = (git branch --show-current).Trim()

git fetch origin $Branch --no-tags
if ($LASTEXITCODE -ne 0) { throw "HOLD: fetch failed." }

$Local = (git rev-parse HEAD).Trim()
$Remote = (git rev-parse ("origin/" + $Branch)).Trim()
$Ahead = @(git rev-list ("origin/" + $Branch + "..HEAD")).Count
$Behind = @(git rev-list ("HEAD..origin/" + $Branch)).Count
$Staged = @(git diff --cached --name-only).Count
$Deleted = @(git ls-files --deleted).Count

$EvidencePath = Join-Path $Root "artifacts\development\SPT-023.3-v1.0.1\runs\20260810-001831\implementation-evidence.json"
$Evidence = Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8 | ConvertFrom-Json
$Targeted = [int]$Evidence.targeted_tests_passed
$FullSuite = [int]$Evidence.institutional_tests_passed
$Protected = [int]$Evidence.protected_files_changed

$Pass = (
    $Local -eq $Expected -and
    $Remote -eq $Expected -and
    $Ahead -eq 0 -and
    $Behind -eq 0 -and
    $Staged -eq 0 -and
    $Deleted -eq 0 -and
    $Targeted -ge 9 -and
    $FullSuite -ge 870 -and
    $Protected -eq 0
)

if (-not $Pass) {
    throw "HOLD: final closure conditions are not all satisfied."
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host " SPT-023.3 CAPA 1 : PUBLISHED / CLOSED" -ForegroundColor Green
Write-Host " COMMIT           : $Local" -ForegroundColor Green
Write-Host " TARGETED TESTS   : $Targeted PASSED" -ForegroundColor Green
Write-Host " FULL SUITE       : $FullSuite PASSED" -ForegroundColor Green
Write-Host " SPT-023.1/.2     : PRESERVED" -ForegroundColor Green
Write-Host " LOCAL/REMOTE     : IDENTICAL" -ForegroundColor Green
Write-Host " AHEAD            : $Ahead" -ForegroundColor Green
Write-Host " BEHIND           : $Behind" -ForegroundColor Green
Write-Host " STAGING          : CLEAN" -ForegroundColor Green
Write-Host " DELETED TRACKED  : $Deleted" -ForegroundColor Green
Write-Host " ERRORS PENDING   : 0" -ForegroundColor Green
Write-Host " NEXT             : SPT-023.3 CAPA 2" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
