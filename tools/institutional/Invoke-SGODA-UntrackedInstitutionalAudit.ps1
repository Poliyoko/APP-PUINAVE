param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory=$true)]
    [string]$ExpectedHead
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Set-Location $ProjectRoot

function Stop-Audit {
    param([string]$Message)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host " SGODA UNTRACKED AUDIT : HOLD" -ForegroundColor Red
    Write-Host " $Message" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red

    exit 20
}

function Get-NormalizedPath {
    param([string]$Path)

    return $Path.Replace("\","/")
}

function Get-Category {
    param([string]$Path)

    $P = Get-NormalizedPath $Path

    if ($P -match '^\.runtime/') {
        return "RUNTIME_TRANSIENT"
    }

    if ($P -match '^artifacts/runtime/') {
        return "RUNTIME_TRANSIENT"
    }

    if ($P -match '(?i)(^|/)(__pycache__|\.pytest_cache|\.mypy_cache|\.ruff_cache|node_modules)(/|$)') {
        return "CACHE_TRANSIENT"
    }

    if ($P -match '(?i)(^|/)(repository-backup|registry-backup|backup|backups)(/|$)') {
        return "BACKUP_REVIEW"
    }

    if ($P -match '(?i)\.(tmp|temp|lock|swp|bak)$') {
        return "TEMPORARY"
    }

    if ($P -match '^artifacts/development/') {
        return "DEVELOPMENT_EVIDENCE"
    }

    if ($P -match '^artifacts/publication/') {
        return "PUBLICATION_EVIDENCE"
    }

    if ($P -match '^artifacts/pmo/') {
        return "PMO_EVIDENCE"
    }

    if ($P -match '^artifacts/reconciliation/') {
        return "RECONCILIATION_EVIDENCE"
    }

    if ($P -match '^artifacts/repair/') {
        return "REPAIR_EVIDENCE"
    }

    if ($P -match '^artifacts/consolidation/') {
        return "CONSOLIDATION_EVIDENCE"
    }

    if ($P -match '^releases/') {
        return "RELEASE_CANDIDATE"
    }

    if ($P -match '^docs/') {
        return "DOCUMENTATION_CANDIDATE"
    }

    if ($P -match '^src/') {
        return "SOURCE_CANDIDATE"
    }

    if ($P -match '^tests/') {
        return "TEST_CANDIDATE"
    }

    if ($P -match '^tools/') {
        return "TOOL_CANDIDATE"
    }

    return "OTHER_REVIEW"
}

function Get-Decision {
    param(
        [string]$Category,
        [long]$Size,
        [bool]$DuplicateTracked,
        [bool]$PotentialSecret,
        [bool]$ValidationFailure
    )

    if ($PotentialSecret) {
        return "HOLD_SECRET_REVIEW"
    }

    if ($Size -ge 100MB) {
        return "PRESERVE_OUTSIDE_NORMAL_GIT"
    }

    if ($ValidationFailure) {
        return "HOLD_VALIDATION"
    }

    if ($Category -in @(
        "RUNTIME_TRANSIENT",
        "CACHE_TRANSIENT",
        "TEMPORARY"
    )) {
        return "IGNORE_POLICY_CANDIDATE"
    }

    if (
        $Category -eq "BACKUP_REVIEW" -and
        $DuplicateTracked
    ) {
        return "REDUNDANT_BACKUP_CANDIDATE"
    }

    if ($DuplicateTracked) {
        return "DUPLICATE_REVIEW"
    }

    if ($Category -in @(
        "DEVELOPMENT_EVIDENCE",
        "PUBLICATION_EVIDENCE",
        "PMO_EVIDENCE",
        "RECONCILIATION_EVIDENCE",
        "REPAIR_EVIDENCE",
        "CONSOLIDATION_EVIDENCE",
        "RELEASE_CANDIDATE",
        "DOCUMENTATION_CANDIDATE",
        "SOURCE_CANDIDATE",
        "TEST_CANDIDATE",
        "TOOL_CANDIDATE"
    )) {
        return "PRESERVE_AND_REVIEW_FOR_VERSIONING"
    }

    return "MANUAL_CLASSIFICATION_REQUIRED"
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " SGODA-PUINAVE - INSTITUTIONAL UNTRACKED AUDITOR" -ForegroundColor Cyan
Write-Host " AUTOMATED / NON-DESTRUCTIVE / SINGLE-PASS" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------
# 1. Certified Git baseline
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[1/12] CERTIFIED BASELINE" -ForegroundColor Yellow

$HeadBefore = (git rev-parse HEAD).Trim()
$StagedBefore = @(git diff --cached --name-only)
$DeletedBefore = @(git ls-files --deleted)

Write-Host "HEAD            : $HeadBefore"
Write-Host "STAGED          : $($StagedBefore.Count)"
Write-Host "DELETED TRACKED : $($DeletedBefore.Count)"

if ($HeadBefore -ne $ExpectedHead) {
    Stop-Audit "Published HEAD changed."
}

if ($StagedBefore.Count -ne 0) {
    Stop-Audit "Staging must be clean before audit."
}

if ($DeletedBefore.Count -ne 0) {
    Stop-Audit "Tracked deletions detected."
}

$Branch = (git branch --show-current).Trim()
$Origin = (git remote get-url origin).Trim()

Write-Host "BRANCH : $Branch"
Write-Host "ORIGIN : $Origin"

# ---------------------------------------------------------------------
# 2. Untracked inventory
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[2/12] UNTRACKED INVENTORY" -ForegroundColor Yellow

$Untracked = @(
    git `
        -c core.longpaths=true `
        -c core.quotepath=false `
        ls-files `
        --others `
        --exclude-standard
)

Write-Host "UNTRACKED DISCOVERED : $($Untracked.Count)"

if ($Untracked.Count -eq 0) {

    Write-Host ""
    Write-Host "NO UNTRACKED FILES FOUND." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------
# 3. Audit output directory
# ---------------------------------------------------------------------

$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")

$AuditRoot = Join-Path `
    $ProjectRoot `
    "artifacts\audit\untracked-institutional-audit\$RunId"

New-Item `
    -ItemType Directory `
    -Path $AuditRoot `
    -Force |
Out-Null

$InventoryCsv = Join-Path $AuditRoot "untracked-inventory.csv"
$InventoryJson = Join-Path $AuditRoot "untracked-inventory.json"
$SummaryJson = Join-Path $AuditRoot "audit-summary.json"
$SummaryMd = Join-Path $AuditRoot "audit-summary.md"
$PlanJson = Join-Path $AuditRoot "reconciliation-plan.json"
$ManifestCsv = Join-Path $AuditRoot "sha256-manifest.csv"

Write-Host "AUDIT RUN : $RunId"

# ---------------------------------------------------------------------
# 4. Tracked-path index
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[3/12] BUILDING TRACKED INDEX" -ForegroundColor Yellow

$Tracked = @(
    git `
        -c core.longpaths=true `
        -c core.quotepath=false `
        ls-files
)

$TrackedLookup = @{}

foreach ($Path in $Tracked) {
    $TrackedLookup[(Get-NormalizedPath $Path).ToLowerInvariant()] = $true
}

Write-Host "TRACKED FILES : $($Tracked.Count)"

# ---------------------------------------------------------------------
# 5. Analyze every untracked file
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[4/12] ANALYZING ALL UNTRACKED FILES" -ForegroundColor Yellow

$Results = New-Object System.Collections.ArrayList

$Index = 0

foreach ($RelativePathRaw in $Untracked) {

    $Index++

    $RelativePath = Get-NormalizedPath $RelativePathRaw
    $FullPath = Join-Path $ProjectRoot $RelativePathRaw

    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
        continue
    }

    $File = Get-Item -LiteralPath $FullPath

    $Category = Get-Category $RelativePath

    $Hash = ""
    $HashError = ""

    try {
        $Hash = (
            Get-FileHash `
                -LiteralPath $FullPath `
                -Algorithm SHA256
        ).Hash
    }
    catch {
        $HashError = $_.Exception.Message
    }

    $PathLength = $FullPath.Length

    $LongPath = ($PathLength -ge 240)

    # -------------------------------------------------------------
    # Logical root-equivalent duplicate detection.
    # Especially useful for backup artifacts.
    # -------------------------------------------------------------

    $DuplicateTracked = $false
    $DuplicateOf = ""

    $BackupMarkers = @(
        "/repository-backup/",
        "/registry-backup/",
        "/backup/",
        "/backups/"
    )

    foreach ($Marker in $BackupMarkers) {

        $MarkerIndex = $RelativePath.ToLowerInvariant().LastIndexOf(
            $Marker.ToLowerInvariant()
        )

        if ($MarkerIndex -lt 0) {
            continue
        }

        $CandidateRelative = $RelativePath.Substring(
            $MarkerIndex + $Marker.Length
        )

        if ([string]::IsNullOrWhiteSpace($CandidateRelative)) {
            continue
        }

        $CandidateKey = $CandidateRelative.ToLowerInvariant()

        if (-not $TrackedLookup.ContainsKey($CandidateKey)) {
            continue
        }

        $CandidateFull = Join-Path $ProjectRoot $CandidateRelative

        if (-not (Test-Path -LiteralPath $CandidateFull -PathType Leaf)) {
            continue
        }

        try {

            $CandidateHash = (
                Get-FileHash `
                    -LiteralPath $CandidateFull `
                    -Algorithm SHA256
            ).Hash

            if ($Hash -and $CandidateHash -eq $Hash) {
                $DuplicateTracked = $true
                $DuplicateOf = $CandidateRelative
                break
            }
        }
        catch {
        }
    }

    # -------------------------------------------------------------
    # File validation.
    # -------------------------------------------------------------

    $ValidationStatus = "NOT_REQUIRED"
    $ValidationError = ""
    $ValidationFailure = $false

    $Extension = $File.Extension.ToLowerInvariant()

    if ($Extension -eq ".json") {

        try {

            $null = Get-Content `
                -LiteralPath $FullPath `
                -Raw `
                -Encoding UTF8 |
            ConvertFrom-Json

            $ValidationStatus = "PASS_JSON"
        }
        catch {

            $ValidationStatus = "FAIL_JSON"
            $ValidationError = $_.Exception.Message
            $ValidationFailure = $true
        }
    }

    if ($Extension -eq ".ps1") {

        $Tokens = $null
        $Errors = $null

        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $FullPath,
            [ref]$Tokens,
            [ref]$Errors
        )

        if ($Errors.Count -eq 0) {
            $ValidationStatus = "PASS_PS51_SYNTAX"
        }
        else {

            $ValidationStatus = "FAIL_PS51_SYNTAX"

            $ValidationError = (
                $Errors |
                ForEach-Object { $_.Message }
            ) -join " | "

            $ValidationFailure = $true
        }
    }

    # -------------------------------------------------------------
    # EOL inspection for relevant text files.
    # -------------------------------------------------------------

    $ExpectedEol = ""
    $ActualEol = "NOT_CHECKED"
    $EolStatus = "NOT_REQUIRED"

    if ($Extension -in @(
        ".ps1",".psm1",".psd1",
        ".md",".json",".jsonl",
        ".yaml",".yml",".toml",
        ".ini",".py",".sql",".sh"
    )) {

        $Attr = @(
            git check-attr eol -- "$RelativePath"
        ) -join ""

        if ($Attr -match ': eol: crlf$') {
            $ExpectedEol = "crlf"
        }

        if ($Attr -match ': eol: lf$') {
            $ExpectedEol = "lf"
        }

        try {

            $Bytes = [System.IO.File]::ReadAllBytes($FullPath)

            $CrLfCount = 0
            $LfOnlyCount = 0

            for ($i = 0; $i -lt $Bytes.Length; $i++) {

                if ($Bytes[$i] -ne 10) {
                    continue
                }

                if ($i -gt 0 -and $Bytes[$i - 1] -eq 13) {
                    $CrLfCount++
                }
                else {
                    $LfOnlyCount++
                }
            }

            if ($CrLfCount -gt 0 -and $LfOnlyCount -gt 0) {
                $ActualEol = "mixed"
            }
            elseif ($CrLfCount -gt 0) {
                $ActualEol = "crlf"
            }
            elseif ($LfOnlyCount -gt 0) {
                $ActualEol = "lf"
            }
            else {
                $ActualEol = "none"
            }

            if (
                $ExpectedEol -and
                $ActualEol -ne "none" -and
                $ActualEol -ne $ExpectedEol
            ) {
                $EolStatus = "MISMATCH"
            }
            else {
                $EolStatus = "PASS"
            }
        }
        catch {

            $ActualEol = "ERROR"
            $EolStatus = "REVIEW"
        }
    }

    # -------------------------------------------------------------
    # Potential secrets.
    # Restricted to reasonably sized text-like files.
    # -------------------------------------------------------------

    $PotentialSecret = $false
    $SecretSignature = ""

    if (
        $File.Length -le 5MB -and
        $Extension -in @(
            ".ps1",".psm1",".psd1",".py",
            ".json",".jsonl",".md",".txt",
            ".yaml",".yml",".toml",".ini",
            ".cfg",".env"
        )
    ) {

        $Patterns = @(
            '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
            '(?i)ghp_[A-Za-z0-9]{20,}',
            '(?i)github_token\s*[:=]',
            '(?i)aws_secret_access_key\s*[:=]',
            '(?i)client_secret\s*[:=]\s*["''][^"'']{8,}',
            '(?i)password\s*[:=]\s*["''][^"'']{8,}'
        )

        foreach ($Pattern in $Patterns) {

            $Match = Select-String `
                -LiteralPath $FullPath `
                -Pattern $Pattern `
                -Quiet `
                -ErrorAction SilentlyContinue

            if ($Match) {

                $PotentialSecret = $true
                $SecretSignature = $Pattern
                break
            }
        }
    }

    $Decision = Get-Decision `
        -Category $Category `
        -Size $File.Length `
        -DuplicateTracked $DuplicateTracked `
        -PotentialSecret $PotentialSecret `
        -ValidationFailure $ValidationFailure

    $Record = [PSCustomObject]@{
        Path                = $RelativePath
        Category            = $Category
        Decision            = $Decision
        Bytes               = $File.Length
        SizeMB              = [math]::Round(($File.Length / 1MB),3)
        SHA256              = $Hash
        HashError           = $HashError
        DuplicateTracked    = $DuplicateTracked
        DuplicateOf         = $DuplicateOf
        PathLength          = $PathLength
        LongPath            = $LongPath
        Extension           = $Extension
        Validation          = $ValidationStatus
        ValidationError     = $ValidationError
        ExpectedEol         = $ExpectedEol
        ActualEol           = $ActualEol
        EolStatus           = $EolStatus
        PotentialSecret     = $PotentialSecret
        SecretSignature     = $SecretSignature
    }

    [void]$Results.Add($Record)

    if (($Index % 100) -eq 0) {
        Write-Host ("ANALYZED : {0}/{1}" -f $Index,$Untracked.Count)
    }
}

Write-Host "ANALYZED TOTAL : $($Results.Count)" -ForegroundColor Green

# ---------------------------------------------------------------------
# 6. Detect SHA duplicates within untracked universe
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[5/12] DUPLICATE ANALYSIS" -ForegroundColor Yellow

$HashGroups = @(
    $Results |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.SHA256)
    } |
    Group-Object SHA256 |
    Where-Object {
        $_.Count -gt 1
    }
)

$DuplicateFileCount = (
    $HashGroups |
    ForEach-Object { $_.Count } |
    Measure-Object -Sum
).Sum

if ($null -eq $DuplicateFileCount) {
    $DuplicateFileCount = 0
}

Write-Host "DUPLICATE HASH GROUPS : $($HashGroups.Count)"
Write-Host "FILES IN DUP GROUPS   : $DuplicateFileCount"

# ---------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[6/12] CATEGORY SUMMARY" -ForegroundColor Yellow

$CategorySummary = @(
    $Results |
    Group-Object Category |
    Sort-Object Count -Descending |
    ForEach-Object {

        [PSCustomObject]@{
            Category = $_.Name
            Count    = $_.Count
        }
    }
)

$CategorySummary |
Format-Table -AutoSize

Write-Host ""
Write-Host "[7/12] DECISION SUMMARY" -ForegroundColor Yellow

$DecisionSummary = @(
    $Results |
    Group-Object Decision |
    Sort-Object Count -Descending |
    ForEach-Object {

        [PSCustomObject]@{
            Decision = $_.Name
            Count    = $_.Count
        }
    }
)

$DecisionSummary |
Format-Table -AutoSize

# ---------------------------------------------------------------------
# 8. Critical findings
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[8/12] CRITICAL FINDINGS" -ForegroundColor Yellow

$Oversized = @(
    $Results |
    Where-Object { $_.Bytes -ge 100MB }
)

$Large = @(
    $Results |
    Where-Object {
        $_.Bytes -ge 25MB -and
        $_.Bytes -lt 100MB
    }
)

$Secrets = @(
    $Results |
    Where-Object { $_.PotentialSecret }
)

$Invalid = @(
    $Results |
    Where-Object {
        $_.Validation -like "FAIL_*"
    }
)

$LongPaths = @(
    $Results |
    Where-Object { $_.LongPath }
)

$EolMismatch = @(
    $Results |
    Where-Object {
        $_.EolStatus -eq "MISMATCH"
    }
)

$TrackedDuplicates = @(
    $Results |
    Where-Object { $_.DuplicateTracked }
)

Write-Host ">=100MB              : $($Oversized.Count)"
Write-Host "25-99MB              : $($Large.Count)"
Write-Host "POTENTIAL SECRETS    : $($Secrets.Count)"
Write-Host "VALIDATION FAILURES  : $($Invalid.Count)"
Write-Host "LONG PATHS >=240     : $($LongPaths.Count)"
Write-Host "EOL MISMATCHES       : $($EolMismatch.Count)"
Write-Host "TRACKED DUPLICATES   : $($TrackedDuplicates.Count)"

# ---------------------------------------------------------------------
# 9. Persist complete audit
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[9/12] WRITING AUDIT EVIDENCE" -ForegroundColor Yellow

$Results |
Export-Csv `
    -LiteralPath $InventoryCsv `
    -NoTypeInformation `
    -Encoding UTF8

$Results |
ConvertTo-Json -Depth 6 |
Set-Content `
    -LiteralPath $InventoryJson `
    -Encoding UTF8

$Results |
Select-Object Path,SHA256,Bytes |
Export-Csv `
    -LiteralPath $ManifestCsv `
    -NoTypeInformation `
    -Encoding UTF8

$Summary = [ordered]@{
    schema_version              = "1.0.0"
    audit                       = "SGODA-Untracked-Institutional-Audit"
    generated_utc               = (Get-Date).ToUniversalTime().ToString("o")
    repository                  = $Origin
    branch                      = $Branch
    certified_head              = $HeadBefore
    untracked_detected          = $Untracked.Count
    files_analyzed              = $Results.Count
    categories                  = $CategorySummary
    decisions                   = $DecisionSummary
    duplicate_hash_groups       = $HashGroups.Count
    files_in_duplicate_groups   = $DuplicateFileCount
    tracked_duplicates          = $TrackedDuplicates.Count
    oversized_100mb             = $Oversized.Count
    large_25_99mb               = $Large.Count
    potential_secrets           = $Secrets.Count
    validation_failures         = $Invalid.Count
    long_paths                  = $LongPaths.Count
    eol_mismatches              = $EolMismatch.Count
    destructive_actions         = 0
    git_add                     = $false
    git_commit                  = $false
    git_push                    = $false
    files_deleted               = 0
}

$Summary |
ConvertTo-Json -Depth 8 |
Set-Content `
    -LiteralPath $SummaryJson `
    -Encoding UTF8

$Plan = [ordered]@{
    schema_version = "1.0.0"
    source_audit   = $RunId

    hold = @(
        $Results |
        Where-Object {
            $_.Decision -like "HOLD_*"
        }
    )

    preserve_and_review_for_versioning = @(
        $Results |
        Where-Object {
            $_.Decision -eq "PRESERVE_AND_REVIEW_FOR_VERSIONING"
        }
    )

    ignore_policy_candidates = @(
        $Results |
        Where-Object {
            $_.Decision -eq "IGNORE_POLICY_CANDIDATE"
        }
    )

    redundant_backup_candidates = @(
        $Results |
        Where-Object {
            $_.Decision -eq "REDUNDANT_BACKUP_CANDIDATE"
        }
    )

    duplicate_review = @(
        $Results |
        Where-Object {
            $_.Decision -eq "DUPLICATE_REVIEW"
        }
    )

    preserve_outside_normal_git = @(
        $Results |
        Where-Object {
            $_.Decision -eq "PRESERVE_OUTSIDE_NORMAL_GIT"
        }
    )

    manual_classification_required = @(
        $Results |
        Where-Object {
            $_.Decision -eq "MANUAL_CLASSIFICATION_REQUIRED"
        }
    )
}

$Plan |
ConvertTo-Json -Depth 8 |
Set-Content `
    -LiteralPath $PlanJson `
    -Encoding UTF8

$Md = New-Object System.Collections.Generic.List[string]

$Md.Add("# SGODA-PUINAVE - Auditoria Institucional de Archivos Untracked")
$Md.Add("")
$Md.Add("**Run:** $RunId")
$Md.Add("")
$Md.Add("**HEAD certificado:** $HeadBefore")
$Md.Add("")
$Md.Add("**Archivos detectados:** $($Untracked.Count)")
$Md.Add("")
$Md.Add("**Archivos analizados:** $($Results.Count)")
$Md.Add("")
$Md.Add("## Hallazgos críticos")
$Md.Add("")
$Md.Add("- Archivos >=100 MB: $($Oversized.Count)")
$Md.Add("- Archivos 25-99 MB: $($Large.Count)")
$Md.Add("- Posibles secretos: $($Secrets.Count)")
$Md.Add("- Fallos de validacion: $($Invalid.Count)")
$Md.Add("- Rutas largas: $($LongPaths.Count)")
$Md.Add("- EOL inconsistentes: $($EolMismatch.Count)")
$Md.Add("- Duplicados de archivos tracked: $($TrackedDuplicates.Count)")
$Md.Add("- Grupos SHA-256 duplicados: $($HashGroups.Count)")
$Md.Add("")
$Md.Add("## Seguridad")
$Md.Add("")
$Md.Add("- Archivos eliminados: 0")
$Md.Add("- Git add: NO")
$Md.Add("- Commit: NO")
$Md.Add("- Push: NO")
$Md.Add("- Reset/Clean/Restore de worktree: NO")

[System.IO.File]::WriteAllLines(
    $SummaryMd,
    $Md.ToArray(),
    (New-Object System.Text.UTF8Encoding($false))
)

# ---------------------------------------------------------------------
# 10. Recheck Git baseline after analysis
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[10/12] POST-AUDIT GIT SAFETY" -ForegroundColor Yellow

$HeadAfter = (git rev-parse HEAD).Trim()
$StagedAfter = @(git diff --cached --name-only)
$DeletedAfter = @(git ls-files --deleted)

Write-Host "HEAD BEFORE      : $HeadBefore"
Write-Host "HEAD AFTER       : $HeadAfter"
Write-Host "STAGED AFTER     : $($StagedAfter.Count)"
Write-Host "DELETED TRACKED  : $($DeletedAfter.Count)"

if ($HeadAfter -ne $HeadBefore) {
    Stop-Audit "HEAD changed during audit."
}

if ($StagedAfter.Count -ne 0) {
    Stop-Audit "Audit unexpectedly changed staging."
}

if ($DeletedAfter.Count -ne 0) {
    Stop-Audit "Audit caused tracked deletions."
}

# ---------------------------------------------------------------------
# 11. Output exact reconciliation priorities
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[11/12] RECONCILIATION PRIORITIES" -ForegroundColor Yellow

Write-Host "HOLD SECRET REVIEW          : $($Secrets.Count)"
Write-Host "HOLD VALIDATION             : $($Invalid.Count)"
Write-Host ">=100MB OUTSIDE NORMAL GIT  : $($Oversized.Count)"
Write-Host "REDUNDANT TRACKED DUPLICATES: $($TrackedDuplicates.Count)"
Write-Host "EOL MISMATCH                : $($EolMismatch.Count)"

$VersionCandidates = @(
    $Results |
    Where-Object {
        $_.Decision -eq "PRESERVE_AND_REVIEW_FOR_VERSIONING"
    }
)

$IgnoreCandidates = @(
    $Results |
    Where-Object {
        $_.Decision -eq "IGNORE_POLICY_CANDIDATE"
    }
)

Write-Host "VERSIONING CANDIDATES       : $($VersionCandidates.Count)"
Write-Host "IGNORE POLICY CANDIDATES    : $($IgnoreCandidates.Count)"

# ---------------------------------------------------------------------
# 12. Final institutional decision
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "[12/12] FINAL DECISION" -ForegroundColor Yellow

$BlockingFindings = (
    $Secrets.Count +
    $Invalid.Count
)

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host " SGODA UNTRACKED INSTITUTIONAL AUDIT : COMPLETE" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
Write-Host " UNTRACKED DISCOVERED     : $($Untracked.Count)"
Write-Host " FILES ANALYZED           : $($Results.Count)"
Write-Host " BLOCKING FINDINGS        : $BlockingFindings"
Write-Host " >=100MB                  : $($Oversized.Count)"
Write-Host " LONG PATHS               : $($LongPaths.Count)"
Write-Host " DUPLICATE HASH GROUPS    : $($HashGroups.Count)"
Write-Host " VERSIONING CANDIDATES    : $($VersionCandidates.Count)"
Write-Host " IGNORE CANDIDATES        : $($IgnoreCandidates.Count)"
Write-Host ""
Write-Host " AUDIT ROOT:"
Write-Host " $AuditRoot"
Write-Host ""
Write-Host " GENERATED:"
Write-Host " - untracked-inventory.csv"
Write-Host " - untracked-inventory.json"
Write-Host " - sha256-manifest.csv"
Write-Host " - audit-summary.json"
Write-Host " - audit-summary.md"
Write-Host " - reconciliation-plan.json"
Write-Host ""
Write-Host " DESTRUCTIVE ACTIONS      : 0" -ForegroundColor Green
Write-Host " GIT ADD                  : NO" -ForegroundColor Green
Write-Host " GIT COMMIT               : NO" -ForegroundColor Green
Write-Host " GIT PUSH                 : NO" -ForegroundColor Green
Write-Host " HEAD PRESERVED           : YES" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green

exit 0