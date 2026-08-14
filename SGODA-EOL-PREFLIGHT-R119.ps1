#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Root = (& git.exe rev-parse --show-toplevel).Trim()
if(-not $Root){ throw "Not inside a Git repository." }
Set-Location $Root

$ExpectedHead = "4d463840b2bae0bbc6f18ea869f37e792b69d450"

Write-Host ""
Write-Host "============================================================"
Write-Host " SGODA R119 - GLOBAL ATTRIBUTE-DRIVEN EOL PREFLIGHT"
Write-Host "============================================================"

$Head = (& git.exe rev-parse HEAD).Trim()
$Deleted = @(& git.exe ls-files --deleted)
$Staged = @(& git.exe -c core.quotepath=false diff --cached --name-only)

Write-Host "HEAD            : $Head"
Write-Host "STAGED          : $($Staged.Count)"
Write-Host "DELETED TRACKED : $($Deleted.Count)"

if($Head -ne $ExpectedHead){ throw "SAFETY HOLD: unexpected HEAD" }
if($Deleted.Count -ne 0){ throw "SAFETY HOLD: deleted tracked files detected" }

$TextExt = @(".ps1",".psm1",".psd1",".py",".json",".md",".txt",".yml",".yaml",".toml",".ini",".cfg")
$Candidates = @(
    & git.exe -c core.quotepath=false ls-files --others --exclude-standard |
    Where-Object {
        $Ext = [IO.Path]::GetExtension($_).ToLowerInvariant()
        $TextExt -contains $Ext
    }
)

$Problems = New-Object System.Collections.ArrayList
$Checked = 0

foreach($Path in $Candidates){
    if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ continue }

    $Attrs = @(& git.exe check-attr text eol -- $Path)
    $RequiredEol = ""

    foreach($Line in $Attrs){
        if($Line -match ': eol: (.+)$'){
            $RequiredEol = $Matches[1].Trim().ToLowerInvariant()
        }
    }

    if($RequiredEol -ne "lf" -and $RequiredEol -ne "crlf"){ continue }

    $Text = [IO.File]::ReadAllText((Join-Path $Root $Path), [Text.Encoding]::UTF8)
    $CrlfCount = [regex]::Matches($Text, "`r`n").Count
    $WithoutCrlf = $Text -replace "`r`n", ""
    $BareLfCount = [regex]::Matches($WithoutCrlf, "`n").Count

    $Conflict = $false
    $Reason = ""

    if($RequiredEol -eq "lf" -and $CrlfCount -gt 0){
        $Conflict = $true
        $Reason = "ATTR_LF_BUT_WORKTREE_HAS_CRLF"
    }
    elseif($RequiredEol -eq "crlf" -and $BareLfCount -gt 0){
        $Conflict = $true
        $Reason = "ATTR_CRLF_BUT_WORKTREE_HAS_LF"
    }

    $Checked++

    if($Conflict){
        [void]$Problems.Add([pscustomobject]@{
            Path = $Path
            RequiredEol = $RequiredEol
            CRLF = $CrlfCount
            BareLF = $BareLfCount
            Reason = $Reason
            SHA256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        })
    }
}

Write-Host ""
Write-Host "TEXT_CANDIDATES=$($Candidates.Count)"
Write-Host "ATTRIBUTE_EVALUATED=$Checked"
Write-Host "EOL_CONFLICTS=$($Problems.Count)"

if($Problems.Count -gt 0){
    Write-Host ""
    Write-Host "=== EOL CONFLICTS ===" -ForegroundColor Yellow
    $Problems | Sort-Object Path | Format-Table Path,RequiredEol,CRLF,BareLF,Reason,SHA256 -AutoSize

    $Report = Join-Path $Root "artifacts/development/SGODA-InstitutionalMasterSynchronization-TRANSACTION-RECOVERY-v1.1.9/r119-eol-conflicts.json"
    $Parent = Split-Path -Parent $Report
    if(-not (Test-Path -LiteralPath $Parent)){ New-Item -ItemType Directory -Force -Path $Parent | Out-Null }
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Report, ($Problems | ConvertTo-Json -Depth 8), $Utf8)
    Write-Host "EOL_REPORT=$Report"
}

$HeadAfter = (& git.exe rev-parse HEAD).Trim()
$StagedAfter = @(& git.exe -c core.quotepath=false diff --cached --name-only)
$DeletedAfter = @(& git.exe ls-files --deleted)

Write-Host ""
Write-Host "HEAD_AFTER=$HeadAfter"
Write-Host "STAGED_AFTER=$($StagedAfter.Count)"
Write-Host "DELETED_AFTER=$($DeletedAfter.Count)"
Write-Host "FILES_CONTENT_MODIFIED=NO"
Write-Host "COMMIT_PERFORMED=NO"
Write-Host "PUSH_PERFORMED=NO"
Write-Host "R119_GLOBAL_EOL_PREFLIGHT=PASS"
Write-Host "NEXT_ACTION=BUILD_SINGLE_ATTRIBUTE_DRIVEN_EOL_RECOVERY"
