$ErrorActionPreference = "Stop"

$Expected = "94b7d91aab208dba922d2551574968f4b60fbf3c"

$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root
$Branch = (git branch --show-current).Trim()

git fetch origin $Branch --no-tags | Out-Null
if ($LASTEXITCODE -ne 0) { throw "HOLD: fetch failed." }

$Local = (git rev-parse HEAD).Trim()
$Remote = (git rev-parse ("origin/" + $Branch)).Trim()
$Ahead = @(git rev-list ("origin/" + $Branch + "..HEAD")).Count
$Behind = @(git rev-list ("HEAD..origin/" + $Branch)).Count
$Staged = @(git diff --cached --name-only).Count
$Deleted = @(git ls-files --deleted).Count

$EvidencePath = Join-Path $Root "artifacts\development\SPT-023.3-v1.0.1\runs\20260810-001831\implementation-evidence.json"
if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
    throw "HOLD: evidence missing."
}

$Evidence = Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8 | ConvertFrom-Json
$Targeted = [int]$Evidence.targeted_tests_passed
$FullSuite = [int]$Evidence.institutional_tests_passed
$Protected = [int]$Evidence.protected_files_changed

if ($Local -ne $Expected) { throw "HOLD: local HEAD mismatch." }
if ($Remote -ne $Expected) { throw "HOLD: remote HEAD mismatch." }
if ($Ahead -ne 0) { throw "HOLD: ahead != 0." }
if ($Behind -ne 0) { throw "HOLD: behind != 0." }
if ($Staged -ne 0) { throw "HOLD: staging not clean." }
if ($Deleted -ne 0) { throw "HOLD: deleted tracked != 0." }
if ($Targeted -lt 9) { throw "HOLD: targeted tests < 9." }
if ($FullSuite -lt 870) { throw "HOLD: full suite < 870." }
if ($Protected -ne 0) { throw "HOLD: protected changes != 0." }

$OldColor = [Console]::ForegroundColor
try {
    [Console]::ForegroundColor = [ConsoleColor]::Green
    [Console]::WriteLine("")
    [Console]::WriteLine("======================================================================")
    [Console]::WriteLine(" SPT-023.3 CAPA 1 : PUBLISHED / CLOSED")
    [Console]::WriteLine(" COMMIT           : " + $Local)
    [Console]::WriteLine(" TARGETED TESTS   : " + $Targeted + " PASSED")
    [Console]::WriteLine(" FULL SUITE       : " + $FullSuite + " PASSED")
    [Console]::WriteLine(" SPT-023.1/.2     : PRESERVED")
    [Console]::WriteLine(" LOCAL/REMOTE     : IDENTICAL")
    [Console]::WriteLine(" AHEAD            : " + $Ahead)
    [Console]::WriteLine(" BEHIND           : " + $Behind)
    [Console]::WriteLine(" STAGING          : CLEAN")
    [Console]::WriteLine(" DELETED TRACKED  : " + $Deleted)
    [Console]::WriteLine(" ERRORS PENDING   : 0")
    [Console]::WriteLine(" NEXT             : SPT-023.3 CAPA 2")
    [Console]::WriteLine("======================================================================")
    [Console]::WriteLine("")
    [Console]::WriteLine("FINAL_CLOSURE_EXIT_CODE=0")
}
finally {
    [Console]::ForegroundColor = $OldColor
}
