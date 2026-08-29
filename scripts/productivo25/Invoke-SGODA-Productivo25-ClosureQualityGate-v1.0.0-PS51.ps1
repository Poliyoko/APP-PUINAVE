$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "PRODUCTIVO-25 QUALITY GATE: FAIL" -ForegroundColor Red
    throw $Message
}

$Json = Join-Path $Root "artifacts/productivo-25/v1.0.0/SGODA-PRODUCTIVO-25-CIERRE-v1.0.0.json"
$Doc  = Join-Path $Root "docs/08_Entregables/PRODUCTIVO-25/SGODA-PRODUCTIVO-25-CIERRE-v1.0.0.md"

if (-not (Test-Path -LiteralPath $Json -PathType Leaf)) {
    Fail "Closure JSON missing."
}

if (-not (Test-Path -LiteralPath $Doc -PathType Leaf)) {
    Fail "Closure document missing."
}

$A = Get-Content -LiteralPath $Json -Raw -Encoding UTF8 | ConvertFrom-Json

if ($A.project -ne "SGODA-PUINAVE") {
    Fail "Project mismatch."
}

if ($A.institutional_state -ne "PRODUCTIVO-25") {
    Fail "Institutional state mismatch."
}

if ($A.version -ne "1.0.0") {
    Fail "Version mismatch."
}

if ($A.real25.records -ne 25) {
    Fail "REAL-25 records != 25."
}

if ($A.real25.expected_records -ne 25) {
    Fail "Expected records != 25."
}

if ($A.real25.lexical_complete -ne 25) {
    Fail "Lexical completeness != 25."
}

if ($A.real25.audio_complete -ne 25) {
    Fail "Audio completeness != 25."
}

if ($A.real25.runtime_audio_available -ne 25) {
    Fail "Runtime audio availability != 25."
}

if ($A.real25.ready -ne $true) {
    Fail "REAL-25 runtime is not READY."
}

if ($A.real25.quality_gate -ne "PASS") {
    Fail "REAL-25 quality gate is not PASS."
}

if ($A.continuity.reopen_closed_components -ne $false) {
    Fail "Continuity policy invalid."
}

if ($A.continuity.preserve_untracked_history -ne 122) {
    Fail "Historical untracked baseline mismatch."
}

$DocText = Get-Content -LiteralPath $Doc -Raw -Encoding UTF8

foreach ($RequiredText in @(
    "PRODUCTIVO-25",
    "25/25",
    "REAL-N",
    "CLOSURE_CANDIDATE"
)) {
    if ($DocText -notmatch [regex]::Escape($RequiredText)) {
        Fail "Required document marker missing: $RequiredText"
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " PRODUCTIVO-25 QUALITY GATE: PASS" -ForegroundColor Green
Write-Host " REAL-25           : 25/25" -ForegroundColor Green
Write-Host " RUNTIME AUDIO     : 25/25" -ForegroundColor Green
Write-Host " READY             : TRUE" -ForegroundColor Green
Write-Host " CONTINUITY POLICY : PASS" -ForegroundColor Green
Write-Host " STATUS            : CLOSURE_CANDIDATE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green