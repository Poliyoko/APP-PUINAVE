param(
    [string]$ProjectRoot = "",
    [string]$ExpectedHead = "543dd7e52c24e661b8b7a1936aae7b88346733e1"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Stop-Prepare {
    param([string]$Message)

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host " SPT-023 CONTINUATION PREPARE v1.0.1 : HOLD" -ForegroundColor Red
    Write-Host (" " + $Message) -ForegroundColor Red
    Write-Host " NO SOURCE MODIFICATION / NO COMMIT / NO PUSH" -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Red
    exit 20
}

function Invoke-GitSingleLine {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$GitArguments
    )

    $Output = @(& git @GitArguments 2>&1)
    $Code = $LASTEXITCODE

    if ($Code -ne 0) {
        throw ("git " + ($GitArguments -join " ") + " failed with exit code " + $Code + ": " + ($Output -join " "))
    }

    if ($Output.Count -eq 0) {
        throw ("git " + ($GitArguments -join " ") + " returned no output.")
    }

    return ([string]($Output | Select-Object -First 1)).Trim()
}

function Invoke-GitLines {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$GitArguments,
        [switch]$AllowNoMatches
    )

    $Output = @(& git @GitArguments 2>&1)
    $Code = $LASTEXITCODE

    if ($AllowNoMatches -and $Code -eq 1) {
        return @()
    }

    if ($Code -ne 0) {
        throw ("git " + ($GitArguments -join " ") + " failed with exit code " + $Code + ": " + ($Output -join " "))
    }

    return @($Output | ForEach-Object { [string]$_ })
}

try {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = Invoke-GitSingleLine -GitArguments @("rev-parse","--show-toplevel")
    }

    Set-Location $ProjectRoot

    $Root   = Invoke-GitSingleLine -GitArguments @("rev-parse","--show-toplevel")
    $Branch = Invoke-GitSingleLine -GitArguments @("branch","--show-current")
    $Origin = Invoke-GitSingleLine -GitArguments @("remote","get-url","origin")

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host " SGODA-PUINAVE - SPT-023 AUTHORITATIVE CONTINUATION PREPARE v1.0.1" -ForegroundColor Cyan
    Write-Host " SINGLE FILE / POWERSHELL 5.1 / NON-DESTRUCTIVE" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "[1/6] AUTHORITATIVE BASELINE" -ForegroundColor Yellow

    & git fetch origin $Branch --no-tags
    if ($LASTEXITCODE -ne 0) {
        Stop-Prepare "Unable to fetch official remote."
    }

    $Local  = Invoke-GitSingleLine -GitArguments @("rev-parse","HEAD")
    $Remote = Invoke-GitSingleLine -GitArguments @("rev-parse","origin/$Branch")

    $Staged = Invoke-GitLines -GitArguments @("diff","--cached","--name-only")
    $Deleted = Invoke-GitLines -GitArguments @("ls-files","--deleted")

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "BRANCH          : $Branch"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if ($Local -ne $ExpectedHead) {
        Stop-Prepare "Local HEAD is not the certified continuation baseline."
    }

    if ($Remote -ne $ExpectedHead) {
        Stop-Prepare "Remote HEAD is not the certified continuation baseline."
    }

    if ($Staged.Count -ne 0) {
        Stop-Prepare "Staging is not clean."
    }

    if ($Deleted.Count -ne 0) {
        Stop-Prepare "Tracked deletions detected."
    }

    Write-Host "BASELINE : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[2/6] SPT-023.2 PRESERVATION" -ForegroundColor Yellow

    $TrackedFiles = Invoke-GitLines -GitArguments @("-c","core.quotepath=false","ls-files")

    $Spt0232 = @(
        $TrackedFiles |
        Where-Object {
            $_ -match '(?i)SPT-023\.2|SPT0232'
        }
    )

    Write-Host "TRACKED SPT-023.2 REFERENCES : $($Spt0232.Count)"

    if ($Spt0232.Count -eq 0) {
        Stop-Prepare "No tracked SPT-023.2 evidence found in certified baseline."
    }

    Write-Host "SPT-023.2 : PRESERVED / NOT REOPENED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/6] NEXT-PACKAGE DISCOVERY" -ForegroundColor Yellow

    $NameHits = @(
        $TrackedFiles |
        Where-Object {
            $_ -match '(?i)SPT-023\.3|SPT0233|categor(y|ies|ía|ías)|categoria|categorias|categoriz'
        } |
        Sort-Object -Unique
    )

    $TextHitsList = New-Object System.Collections.ArrayList

    $Patterns = @(
        "SPT-023.3",
        "SPT0233",
        "Motor de Categor",
        "Motor de Categoriz",
        "Category Engine",
        "Category Manager",
        "categorias",
        "categorías"
    )

    foreach ($Pattern in $Patterns) {
        $SearchArgs = @(
            "-c","core.quotepath=false",
            "grep","-n","-I","-i","-F",
            "--",$Pattern,"--",
            "docs","releases","artifacts","config","knowledge","src","tools"
        )

        $Matches = Invoke-GitLines -GitArguments $SearchArgs -AllowNoMatches

        foreach ($Match in $Matches) {
            if (-not [string]::IsNullOrWhiteSpace($Match)) {
                [void]$TextHitsList.Add($Match)
            }
        }
    }

    $TextHits = @($TextHitsList | Sort-Object -Unique)

    $ExplicitSpt0233 = @(
        $NameHits + $TextHits |
        Where-Object {
            $_ -match '(?i)SPT-023\.3|SPT0233'
        } |
        Sort-Object -Unique
    )

    $CategoryEvidence = @(
        $NameHits + $TextHits |
        Where-Object {
            $_ -match '(?i)categor(y|ies|ía|ías)|categoria|categorias|categoriz'
        } |
        Sort-Object -Unique
    )

    Write-Host "FILENAME HITS         : $($NameHits.Count)"
    Write-Host "TEXT HITS             : $($TextHits.Count)"
    Write-Host "EXPLICIT SPT-023.3    : $($ExplicitSpt0233.Count)"
    Write-Host "CATEGORY EVIDENCE     : $($CategoryEvidence.Count)"

    Write-Host ""
    Write-Host "[4/6] EVIDENCE SAMPLE" -ForegroundColor Yellow

    $ExplicitSpt0233 | Select-Object -First 25 | ForEach-Object {
        Write-Host ("SPT0233 : " + $_)
    }

    $CategoryEvidence | Select-Object -First 25 | ForEach-Object {
        Write-Host ("CATEGORY: " + $_)
    }

    $Decision = "UNCONFIRMED"
    $NextPackage = ""
    $Purpose = ""

    if ($ExplicitSpt0233.Count -gt 0 -and $CategoryEvidence.Count -gt 0) {
        $Decision = "CONFIRMED"
        $NextPackage = "SPT-023.3"
        $Purpose = "CATEGORY ENGINE / CATEGORIZATION"
    }

    Write-Host ""
    Write-Host "[5/6] AUTHORITATIVE DECISION" -ForegroundColor Yellow
    Write-Host "DECISION     : $Decision"
    Write-Host "NEXT PACKAGE : $NextPackage"
    Write-Host "PURPOSE      : $Purpose"

    $RunId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
    $ReportDir = Join-Path $Root "artifacts\runtime\spt-023-continuation-prepare"

    if (-not (Test-Path -LiteralPath $ReportDir)) {
        New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
    }

    $ReportPath = Join-Path $ReportDir ("prepare-" + $RunId + ".json")

    $Report = [ordered]@{
        schema_version = "1.0.1"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        repository = $Origin
        branch = $Branch
        certified_head = $ExpectedHead
        local_head = $Local
        remote_head = $Remote
        staged = $Staged.Count
        deleted_tracked = $Deleted.Count
        spt0232_reference_count = $Spt0232.Count
        filename_hits = @($NameHits)
        text_hits = @($TextHits)
        explicit_spt0233_hits = $ExplicitSpt0233.Count
        category_evidence_count = $CategoryEvidence.Count
        decision = $Decision
        next_package = $NextPackage
        purpose = $Purpose
        destructive_actions = 0
        commit = $false
        push = $false
    }

    [System.IO.File]::WriteAllText(
        $ReportPath,
        ($Report | ConvertTo-Json -Depth 8) + "`n",
        (New-Object System.Text.UTF8Encoding($false))
    )

    Write-Host ""
    Write-Host "[6/6] FINAL SAFETY" -ForegroundColor Yellow

    $LocalAfter = Invoke-GitSingleLine -GitArguments @("rev-parse","HEAD")
    $StagedAfter = Invoke-GitLines -GitArguments @("diff","--cached","--name-only")
    $DeletedAfter = Invoke-GitLines -GitArguments @("ls-files","--deleted")

    Write-Host "HEAD AFTER      : $LocalAfter"
    Write-Host "STAGED AFTER    : $($StagedAfter.Count)"
    Write-Host "DELETED TRACKED : $($DeletedAfter.Count)"
    Write-Host "REPORT          : $ReportPath"

    if ($LocalAfter -ne $ExpectedHead) {
        Stop-Prepare "HEAD changed during PREPARE."
    }

    if ($StagedAfter.Count -ne 0) {
        Stop-Prepare "Staging changed during PREPARE."
    }

    if ($DeletedAfter.Count -ne 0) {
        Stop-Prepare "Tracked deletions detected during PREPARE."
    }

    if ($Decision -ne "CONFIRMED") {
        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Yellow
        Write-Host " SPT-023 CONTINUATION : NOMENCLATURE NOT YET CONFIRMED" -ForegroundColor Yellow
        Write-Host " CERTIFIED BASELINE   : PRESERVED" -ForegroundColor Green
        Write-Host " SPT-023.2            : PRESERVED / NOT REOPENED" -ForegroundColor Green
        Write-Host " SOURCE MODIFICATIONS : 0" -ForegroundColor Green
        Write-Host "======================================================================" -ForegroundColor Yellow
        exit 10
    }

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host " SPT-023 CONTINUATION PREPARE v1.0.1 : PASS" -ForegroundColor Green
    Write-Host " NEXT PACKAGE                         : SPT-023.3" -ForegroundColor Green
    Write-Host " PURPOSE                              : CATEGORY ENGINE / CATEGORIZATION" -ForegroundColor Green
    Write-Host " CERTIFIED BASELINE                   : $ExpectedHead" -ForegroundColor Green
    Write-Host " SPT-023.2                            : PRESERVED / NOT REOPENED" -ForegroundColor Green
    Write-Host " READY FOR IMPLEMENTATION             : YES" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green
    exit 0
}
catch {
    Stop-Prepare $_.Exception.Message
}
