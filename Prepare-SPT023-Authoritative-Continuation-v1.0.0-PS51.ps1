param(
    [string]$ProjectRoot = "",
    [string]$ExpectedHead = "543dd7e52c24e661b8b7a1936aae7b88346733e1"
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "SPT-023 CONTINUATION PREPARE : HOLD" -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
    exit 20
}

function Git-One([string[]]$Args) {
    $Out = @(& git @Args 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "git failed: $($Out -join ' ')" }
    return ([string]($Out | Select-Object -First 1)).Trim()
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Git-One @("rev-parse","--show-toplevel")
}
Set-Location $ProjectRoot
$Root = Git-One @("rev-parse","--show-toplevel")
$Branch = Git-One @("branch","--show-current")
$Origin = Git-One @("remote","get-url","origin")

Write-Host ""
Write-Host "=== SPT-023 AUTHORITATIVE CONTINUATION PREPARE ===" -ForegroundColor Cyan

& git fetch origin $Branch --no-tags
if ($LASTEXITCODE -ne 0) { Fail "Unable to fetch official remote." }

$Local = Git-One @("rev-parse","HEAD")
$Remote = Git-One @("rev-parse","origin/$Branch")
$Staged = @(& git diff --cached --name-only)
$Deleted = @(& git ls-files --deleted)

Write-Host "LOCAL HEAD      : $Local"
Write-Host "REMOTE HEAD     : $Remote"
Write-Host "STAGED          : $($Staged.Count)"
Write-Host "DELETED TRACKED : $($Deleted.Count)"

if ($Local -ne $ExpectedHead) { Fail "Local HEAD is not certified baseline." }
if ($Remote -ne $ExpectedHead) { Fail "Remote HEAD is not certified baseline." }
if ($Staged.Count -ne 0) { Fail "Staging is not clean." }
if ($Deleted.Count -ne 0) { Fail "Tracked deletions detected." }

$Tracked = @(& git -c core.quotepath=false ls-files)
$Spt0232 = @($Tracked | Where-Object { $_ -match '(?i)SPT-023\.2|SPT0232' })
if ($Spt0232.Count -eq 0) { Fail "SPT-023.2 evidence not found in tracked baseline." }

$NameHits = @(
    $Tracked | Where-Object {
        $_ -match '(?i)SPT-023\.3|SPT0233|categor(y|ies|ía|ías)|categoria|categorias|categoriz'
    }
)

$Roots = @("docs","releases","artifacts","config","knowledge","src","tools")
$Patterns = @("SPT-023.3","SPT0233","Motor de Categor","Motor de Categoriz","Category Engine","Category Manager","categorias","categorías")
$TextHits = New-Object System.Collections.ArrayList

foreach ($Pattern in $Patterns) {
    $Out = @(& git -c core.quotepath=false grep -n -I -i -F -- "$Pattern" -- @Roots 2>$null)
    foreach ($Line in $Out) {
        if (-not [string]::IsNullOrWhiteSpace([string]$Line)) {
            [void]$TextHits.Add([string]$Line)
        }
    }
}
$TextHits = @($TextHits | Sort-Object -Unique)

$Explicit = @(
    $NameHits + $TextHits | Where-Object { $_ -match '(?i)SPT-023\.3|SPT0233' }
)
$Category = @(
    $NameHits + $TextHits | Where-Object { $_ -match '(?i)categor(y|ies|ía|ías)|categoria|categorias|categoriz' }
)

Write-Host "SPT-023.2 REFERENCES : $($Spt0232.Count)"
Write-Host "SPT-023.3 HITS       : $($Explicit.Count)"
Write-Host "CATEGORY HITS        : $($Category.Count)"

$Decision = "UNCONFIRMED"
if ($Explicit.Count -gt 0 -and $Category.Count -gt 0) { $Decision = "CONFIRMED" }

$RunId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
$ReportDir = Join-Path $Root "artifacts\runtime\spt-023-continuation-prepare"
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$ReportPath = Join-Path $ReportDir ("prepare-" + $RunId + ".json")

$Report = [ordered]@{
    schema_version = "1.0.0"
    generated_utc = [DateTime]::UtcNow.ToString("o")
    repository = $Origin
    branch = $Branch
    certified_head = $ExpectedHead
    local_head = $Local
    remote_head = $Remote
    spt0232_reference_count = $Spt0232.Count
    explicit_spt0233_hits = $Explicit.Count
    category_evidence_count = $Category.Count
    decision = $Decision
    filename_hits = @($NameHits)
    text_hits = @($TextHits)
    destructive_actions = 0
}
[System.IO.File]::WriteAllText(
    $ReportPath,
    ($Report | ConvertTo-Json -Depth 8) + "`n",
    (New-Object System.Text.UTF8Encoding($false))
)

$After = Git-One @("rev-parse","HEAD")
$StageAfter = @(& git diff --cached --name-only)
$DeletedAfter = @(& git ls-files --deleted)

if ($After -ne $ExpectedHead) { Fail "HEAD changed during PREPARE." }
if ($StageAfter.Count -ne 0) { Fail "Staging changed during PREPARE." }
if ($DeletedAfter.Count -ne 0) { Fail "Tracked deletion detected during PREPARE." }

Write-Host "REPORT : $ReportPath"

if ($Decision -ne "CONFIRMED") {
    Write-Host "NEXT PACKAGE : NOT CONFIRMED BY REPOSITORY" -ForegroundColor Yellow
    Write-Host "SPT-023.2    : PRESERVED / NOT REOPENED" -ForegroundColor Green
    exit 10
}

Write-Host "NEXT PACKAGE : SPT-023.3" -ForegroundColor Green
Write-Host "PURPOSE      : CATEGORY ENGINE CONFIRMED BY REPOSITORY EVIDENCE" -ForegroundColor Green
Write-Host "READY FOR IMPLEMENTATION : YES" -ForegroundColor Green
exit 0
