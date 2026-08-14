#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedHead = "4d463840b2bae0bbc6f18ea869f37e792b69d450"
$RuntimeState = "artifacts/runtime/sgd002-auto/state.json"
$ExpectedRuntimeSha = "2037EDCA1DD34041FC4EB869A45F483ECBA8E38FB01294C541F5BBCEF8E917EB"

$Report = "artifacts/development/SGODA-InstitutionalMasterSynchronization-TRANSACTION-RECOVERY-v1.1.9/r119-eol-conflicts.json"
$EvidenceDir = "artifacts/development/SGODA-InstitutionalMasterSynchronization-TRANSACTION-RECOVERY-v1.1.9/eol-recovery"
$Manifest = "$EvidenceDir/r119-eol-normalization-manifest.json"

$LocalOnlyOversized = @(
    "artifacts/consolidation/PCI-002-v1.2.1/robocopy/staging-copy-attempt-1.log",
    "artifacts/consolidation/PCI-002-v1.2.1/robocopy/staging-copy-attempt-2.log",
    "artifacts/pmo/SPT-019.0-v1.1.0/runs/20260805-071813/institutional-inventory.json",
    "releases/SPT-019.0-v1.1.0/institutional-inventory.json"
)

function Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "SGODA R119 ATTRIBUTE-DRIVEN EOL RECOVERY : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason"
    Write-Host "COMMIT_PERFORMED=NO"
    Write-Host "PUSH_PERFORMED=NO"
    exit 1
}

function Get-Sha256 {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ Hold ("Missing file: "+$Path) }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-RequiredEol {
    param([string]$Path)
    $Lines = @(& git.exe check-attr eol -- $Path)
    foreach($Line in $Lines){
        if($Line -match ': eol: (.+)$'){
            return $Matches[1].Trim().ToLowerInvariant()
        }
    }
    return ""
}

function Test-JsonFile {
    param([string]$Path)
    try {
        $null = ([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8) | ConvertFrom-Json)
        return $true
    } catch {
        return $false
    }
}

function Test-PowerShellSyntax {
    param([string]$Path)
    try {
        $Tokens = $null
        $Errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            (Resolve-Path -LiteralPath $Path).Path,
            [ref]$Tokens,
            [ref]$Errors
        )
        return (@($Errors).Count -eq 0)
    } catch {
        return $false
    }
}

function Write-Utf8NoBom {
    param([string]$Path,[string]$Text)
    $Parent = Split-Path -Parent $Path
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path,$Text,$Utf8)
}

try {
    $Root = (& git.exe rev-parse --show-toplevel).Trim()
    if(-not $Root){ Hold "Not inside repository" }
    Set-Location $Root

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " SGODA R119 - SINGLE ATTRIBUTE-DRIVEN EOL RECOVERY"
    Write-Host "============================================================"

    Write-Host ""
    Write-Host "[1/8] AUTHORITATIVE SAFETY"

    $Head = (& git.exe rev-parse HEAD).Trim()
    $Deleted = @(& git.exe ls-files --deleted)
    $Staged = @(& git.exe -c core.quotepath=false diff --cached --name-only)

    Write-Host "HEAD            : $Head"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if($Head -ne $ExpectedHead){ Hold "Unexpected HEAD" }
    if($Deleted.Count -ne 0){ Hold "Deleted tracked files detected" }
    if($Staged.Count -ne 1 -or $Staged[0] -ne $RuntimeState){ Hold "Expected exactly one staged runtime state file" }
    if((Get-Sha256 $RuntimeState) -ne $ExpectedRuntimeSha){ Hold "Runtime state SHA-256 changed" }

    Write-Host "BASELINE_GATE=PASS"
    Write-Host "RUNTIME_PRESTAGED_GATE=PASS"

    Write-Host ""
    Write-Host "[2/8] LOAD PREFLIGHT REPORT"

    if(-not(Test-Path -LiteralPath $Report -PathType Leaf)){ Hold "EOL preflight report missing" }

    $Items = @([IO.File]::ReadAllText((Join-Path $Root $Report),[Text.Encoding]::UTF8) | ConvertFrom-Json)
    Write-Host "PREFLIGHT_CONFLICTS=$($Items.Count)"

    if($Items.Count -ne 83){ Hold ("Expected 83 conflicts, found "+$Items.Count) }

    Write-Host "PREFLIGHT_REPORT=PASS"

    Write-Host ""
    Write-Host "[3/8] CLASSIFY NORMALIZATION TARGETS"

    $Targets = New-Object System.Collections.ArrayList
    $ExcludedOversized = New-Object System.Collections.ArrayList
    $ExcludedMissing = New-Object System.Collections.ArrayList

    foreach($Item in $Items){
        $P = [string]$Item.Path
        if($LocalOnlyOversized -contains $P){
            [void]$ExcludedOversized.Add($P)
            continue
        }
        if(-not(Test-Path -LiteralPath $P -PathType Leaf)){
            [void]$ExcludedMissing.Add($P)
            continue
        }
        $Bytes = (Get-Item -LiteralPath $P).Length
        if($Bytes -ge 100MB){
            [void]$ExcludedOversized.Add($P)
            continue
        }
        [void]$Targets.Add($P)
    }

    Write-Host "NORMALIZATION_TARGETS=$($Targets.Count)"
    Write-Host "EXCLUDED_OVERSIZED=$($ExcludedOversized.Count)"
    Write-Host "EXCLUDED_MISSING=$($ExcludedMissing.Count)"

    if($ExcludedMissing.Count -ne 0){ Hold "Missing EOL target files detected" }

    Write-Host "TARGET_CLASSIFICATION=PASS"

    Write-Host ""
    Write-Host "[4/8] PRE-NORMALIZATION VALIDATION / SHA-256"

    $Records = @()

    foreach($P in $Targets){
        $Required = Get-RequiredEol $P
        if($Required -ne "lf" -and $Required -ne "crlf"){ Hold ("No explicit eol attribute for "+$P) }

        $Ext = [IO.Path]::GetExtension($P).ToLowerInvariant()
        $JsonBefore = $null
        $PsBefore = $null

        if($Ext -eq ".json"){
            $JsonBefore = Test-JsonFile $P
            if(-not $JsonBefore){ Hold ("Invalid JSON before normalization: "+$P) }
        }
        elseif($Ext -eq ".ps1" -or $Ext -eq ".psm1" -or $Ext -eq ".psd1"){
            $PsBefore = Test-PowerShellSyntax $P
            if(-not $PsBefore){ Hold ("PowerShell syntax invalid before normalization: "+$P) }
        }

        $Records += [ordered]@{
            path = $P
            required_eol = $Required
            sha256_before = Get-Sha256 $P
            json_before = $JsonBefore
            powershell_syntax_before = $PsBefore
            sha256_after = $null
            json_after = $null
            powershell_syntax_after = $null
            normalized = $false
        }
    }

    Write-Host "PREVALIDATED_TARGETS=$($Records.Count)"
    Write-Host "PRE_NORMALIZATION_GATE=PASS"

    Write-Host ""
    Write-Host "[5/8] ATTRIBUTE-DRIVEN NORMALIZATION"

    for($i=0;$i -lt $Records.Count;$i++){
        $R = $Records[$i]
        $P = [string]$R.path
        $Required = [string]$R.required_eol

        $Text = [IO.File]::ReadAllText((Join-Path $Root $P),[Text.Encoding]::UTF8)
        $CanonicalLf = (($Text -replace "`r`n","`n") -replace "`r","`n")

        if($Required -eq "lf"){
            $Output = $CanonicalLf
        } else {
            $Output = $CanonicalLf -replace "`n","`r`n"
        }

        Write-Utf8NoBom (Join-Path $Root $P) $Output
        $R.normalized = $true
        $R.sha256_after = Get-Sha256 $P

        $Ext = [IO.Path]::GetExtension($P).ToLowerInvariant()

        if($Ext -eq ".json"){
            $R.json_after = Test-JsonFile $P
            if(-not $R.json_after){ Hold ("Invalid JSON after normalization: "+$P) }
        }
        elseif($Ext -eq ".ps1" -or $Ext -eq ".psm1" -or $Ext -eq ".psd1"){
            $R.powershell_syntax_after = Test-PowerShellSyntax $P
            if(-not $R.powershell_syntax_after){ Hold ("PowerShell syntax invalid after normalization: "+$P) }
        }
    }

    Write-Host "NORMALIZED=$($Records.Count)"
    Write-Host "NORMALIZATION_APPLIED=PASS"

    Write-Host ""
    Write-Host "[6/8] POST-NORMALIZATION ATTRIBUTE GATE"

    $Remaining = New-Object System.Collections.ArrayList

    foreach($R in $Records){
        $P = [string]$R.path
        $Required = [string]$R.required_eol
        $Text = [IO.File]::ReadAllText((Join-Path $Root $P),[Text.Encoding]::UTF8)
        $CrlfCount = [regex]::Matches($Text,"`r`n").Count
        $WithoutCrlf = $Text -replace "`r`n",""
        $BareLfCount = [regex]::Matches($WithoutCrlf,"`n").Count

        if($Required -eq "lf" -and $CrlfCount -gt 0){ [void]$Remaining.Add($P) }
        if($Required -eq "crlf" -and $BareLfCount -gt 0){ [void]$Remaining.Add($P) }
    }

    Write-Host "REMAINING_EOL_CONFLICTS=$($Remaining.Count)"
    if($Remaining.Count -ne 0){
        $Remaining | ForEach-Object { Write-Host ("REMAINING="+$_) }
        Hold "EOL conflicts remain after normalization"
    }

    Write-Host "ATTRIBUTE_EOL_GATE=PASS"

    Write-Host ""
    Write-Host "[7/8] WRITE NON-DESTRUCTIVE EVIDENCE"

    $ManifestObj = [ordered]@{
        component = "SGODA-R119-EOL-RECOVERY"
        baseline = $ExpectedHead
        preflight_conflicts = $Items.Count
        normalized_targets = $Records.Count
        excluded_oversized = @($ExcludedOversized)
        local_oversized_policy = "KEEP_LOCAL_UNTRACKED"
        remaining_conflicts = $Remaining.Count
        runtime_staged_preserved = $true
        commit_performed = $false
        push_performed = $false
        records = $Records
    }

    Write-Utf8NoBom (Join-Path $Root $Manifest) ($ManifestObj | ConvertTo-Json -Depth 12)
    Write-Host "EOL_MANIFEST=$Manifest"
    Write-Host "EVIDENCE=CREATED"

    Write-Host ""
    Write-Host "[8/8] FINAL SAFETY"

    $FinalHead = (& git.exe rev-parse HEAD).Trim()
    $FinalDeleted = @(& git.exe ls-files --deleted)
    $FinalStaged = @(& git.exe -c core.quotepath=false diff --cached --name-only)

    Write-Host "HEAD_AFTER=$FinalHead"
    Write-Host "STAGED_AFTER=$($FinalStaged.Count)"
    Write-Host "DELETED_AFTER=$($FinalDeleted.Count)"

    if($FinalHead -ne $ExpectedHead){ Hold "HEAD changed unexpectedly" }
    if($FinalDeleted.Count -ne 0){ Hold "Tracked deletions detected after normalization" }
    if($FinalStaged.Count -ne 1 -or $FinalStaged[0] -ne $RuntimeState){ Hold "Runtime staging prerequisite was not preserved" }

    Write-Host ""
    Write-Host "R119_ATTRIBUTE_DRIVEN_EOL_RECOVERY=PASS" -ForegroundColor Green
    Write-Host "PREFLIGHT_CONFLICTS=83"
    Write-Host "NORMALIZED_TARGETS=$($Records.Count)"
    Write-Host "OVERSIZED_ORIGINALS_MODIFIED=NO"
    Write-Host "REMAINING_EOL_CONFLICTS=0"
    Write-Host "RUNTIME_PRESTAGED_PRESERVED=YES"
    Write-Host "FILES_DELETED=NO"
    Write-Host "COMMIT_PERFORMED=NO"
    Write-Host "PUSH_PERFORMED=NO"
    Write-Host "NEXT_ACTION=BUILD_R119_FINAL_PUBLICATION_RECOVERY"
    exit 0
}
catch {
    Hold $_.Exception.Message
}
