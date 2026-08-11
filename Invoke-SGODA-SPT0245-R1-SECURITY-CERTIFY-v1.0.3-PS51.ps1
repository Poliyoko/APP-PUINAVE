#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "54400774e87d6340e5f114facf2d80ffa5d9ebdc"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT0245-R1-SECURITY-CERTIFY-v1.0.3-PS51.ps1"
$TestFile = "tests/integration/test_spt0245_automation_security_layer1.py"
$ModuleDir = "src/sgoda/integration/spt0245"
$PolicyFile = "config/integration/spt0245/automation-security-policy.json"
$DocDir = "docs/06_Tecnologia/SPT-024/SPT-024.5"
$RuntimeFile = "artifacts/runtime/sgd002-auto/state.json"
$ArtifactDir = "artifacts/development/SPT-024.5-R1-v1.0.3"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.5 R1 v1.0.3 : HOLD" -ForegroundColor Red
    Write-Host " REASON               : $Reason" -ForegroundColor Red
    Write-Host " TRANSACTION          : NOT PUBLISHED" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    exit 1
}
function Show-Step {
    param([int]$Number,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/14] {1}" -f $Number,$Text) -ForegroundColor Cyan
}
function Invoke-Native {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$false)][string[]]$ArgumentList = @(),
        [Parameter(Mandatory=$false)][string]$Label = "Native command"
    )
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}
function Get-PythonExecutable {
    $candidate = Join-Path $PWD ".venv\Scripts\python.exe"
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    $candidate = Join-Path $PWD "venv\Scripts\python.exe"
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    $cmd = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }
    throw "Python executable not found."
}
function Normalize-Path {
    param([string]$PathValue)
    return ($PathValue.Trim('"') -replace '\\','/')
}
function Is-AllowedWorktreePath {
    param([string]$PathValue)
    $p = Normalize-Path $PathValue
    if ($p -eq $RuntimeFile) { return $true }
    if ($p -eq $SelfName) { return $true }
    if ($p -like "Invoke-SGODA-SPT0245-*") { return $true }
    if ($p.StartsWith("src/sgoda/integration/spt0245/")) { return $true }
    if ($p -eq $TestFile) { return $true }
    if ($p.StartsWith("docs/06_Tecnologia/SPT-024/SPT-024.5/")) { return $true }
    if ($p.StartsWith("config/integration/spt0245/")) { return $true }
    if ($p.StartsWith("artifacts/development/SPT-024.5")) { return $true }
    return $false
}
function Is-AllowedPublishPath {
    param([string]$PathValue)
    $p = Normalize-Path $PathValue
    if ($p -eq $SelfName) { return $true }
    if ($p.StartsWith("src/sgoda/integration/spt0245/")) { return $true }
    if ($p -eq $TestFile) { return $true }
    if ($p.StartsWith("docs/06_Tecnologia/SPT-024/SPT-024.5/")) { return $true }
    if ($p.StartsWith("config/integration/spt0245/")) { return $true }
    if ($p.StartsWith("artifacts/development/SPT-024.5-R1-v1.0.3/")) { return $true }
    return $false
}

try {
    Show-Step 1 "AUTHORITATIVE BASELINE / RESUME / WORKTREE SAFETY"

    if (-not (Test-Path -LiteralPath ".git")) {
        Stop-Hold "Master must be executed from the official repository root."
    }

    # IMPORTANT v1.0.3 FIX:
    # Never define a PowerShell function named Git/git. PowerShell command names
    # are case-insensitive, so the previous wrapper recursively invoked itself,
    # causing the call-depth overflow before baseline diagnostics.
    Invoke-Native -FilePath "git.exe" -ArgumentList @("fetch","origin",$Branch) -Label "git fetch"

    $LocalHead = (& git.exe rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Unable to resolve local HEAD." }

    $RemoteHead = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Unable to resolve remote HEAD." }

    $Staged = @(& git.exe diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect staged files." }

    $Deleted = @(& git.exe -c core.quotepath=false ls-files --deleted)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect tracked deletions." }

    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if ($LocalHead -ne $ExpectedBaseline) {
        Stop-Hold "Unexpected local baseline. Expected $ExpectedBaseline; found $LocalHead."
    }
    if ($RemoteHead -ne $ExpectedBaseline) {
        Stop-Hold "Unexpected remote baseline. Expected $ExpectedBaseline; found $RemoteHead."
    }
    if ($Staged.Count -ne 0) { Stop-Hold "Pre-existing staged changes detected." }
    if ($Deleted.Count -ne 0) { Stop-Hold "Tracked deletions detected." }

    if (Test-Path -LiteralPath $RuntimeFile) {
        Write-Host "RUNTIME PRESERVED : $RuntimeFile"
    }
    Write-Host "BASELINE : PASS"
    Write-Host "POWERSHELL WRAPPER RECURSION : ELIMINATED"

    Show-Step 2 "RECOVER EXISTING SPT-024.5 FAILED-RUN OUTPUTS"
    $Required = @(
        "$ModuleDir/__init__.py",
        "$ModuleDir/models.py",
        "$ModuleDir/policy.py",
        "$ModuleDir/workflow_guard.py",
        "$ModuleDir/audit.py",
        "$ModuleDir/gate.py",
        "$ModuleDir/service.py",
        $TestFile,
        $PolicyFile
    )

    $Missing = @()
    foreach ($item in $Required) {
        if (-not (Test-Path -LiteralPath $item)) { $Missing += $item }
    }
    if ($Missing.Count -gt 0) {
        Write-Host "MISSING RECOVERY OUTPUTS:" -ForegroundColor Yellow
        foreach ($item in $Missing) { Write-Host "  $item" }
        Stop-Hold "Existing SPT-024.5 failed-run outputs are incomplete; no destructive rebuild was attempted."
    }

    Write-Host "SPT-024.5 EXISTING OUTPUTS : REUSED"
    Write-Host "SPT-024.5 REBUILD          : NO"

    Show-Step 3 "CLOSED-COMPONENT WORKTREE PRESERVATION"
    $StatusLines = @(& git.exe status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect worktree." }

    $Unexpected = @()
    foreach ($line in $StatusLines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Length -lt 4) { continue }
        $pathPart = $line.Substring(3)
        if ($pathPart -match ' -> ') { $pathPart = ($pathPart -split ' -> ')[-1] }
        if (-not (Is-AllowedWorktreePath $pathPart)) {
            $Unexpected += (Normalize-Path $pathPart)
        }
    }
    if ($Unexpected.Count -gt 0) {
        foreach ($item in $Unexpected) { Write-Host "UNEXPECTED CHANGE : $item" -ForegroundColor Yellow }
        Stop-Hold "Unexpected changes outside the SPT-024.5 recovery scope."
    }
    Write-Host "SPT-023 + SPT-024.1-.4 : PRESERVATION SCOPE PASS"

    Show-Step 4 "REPAIR TEST / PRODUCTION-SCOPE CONTRACT"
    $Raw = Get-Content -LiteralPath $TestFile -Raw -Encoding UTF8
    $Original = $Raw

    # v1.0.1 production auditor intentionally scopes workflows below:
    # automation/n8n/workflows. Tests must create fixtures in that same scope.
    $Raw = $Raw.Replace('tmp_path / "workflows"', 'tmp_path / "automation" / "n8n" / "workflows"')
    $Raw = $Raw.Replace("tmp_path / 'workflows'", "tmp_path / 'automation' / 'n8n' / 'workflows'")

    # v1.0.1 added AUT-PRODUCTION-SCOPE to the blocking contract.
    $Raw = $Raw.Replace(
        "len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS) == 7",
        "len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS) == 8"
    )

    if ($Raw -ne $Original) {
        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText((Join-Path $PWD $TestFile), $Raw, $Utf8NoBom)
        Write-Host "TEST CONTRACT : REMEDIATED"
    }
    else {
        Write-Host "TEST CONTRACT : ALREADY REMEDIATED"
    }

    $VerifyText = Get-Content -LiteralPath $TestFile -Raw -Encoding UTF8
    if ($VerifyText -match 'tmp_path\s*/\s*["'']workflows["'']') {
        Stop-Hold "Legacy tmp_path/workflows fixtures remain."
    }
    if ($VerifyText -match 'REQUIRED_BLOCKING_CONTROLS\)\s*==\s*7') {
        Stop-Hold "Legacy 7-control gate expectation remains."
    }

    Write-Host "PRODUCTION FIXTURE ROOT : automation/n8n/workflows"
    Write-Host "BLOCKING CONTROL COUNT  : 8"

    Show-Step 5 "PYTHON IMPORT + TARGETED TESTS"
    $Python = Get-PythonExecutable
    $env:PYTHONPATH = (Join-Path $PWD "src")

    Invoke-Native -FilePath $Python -ArgumentList @(
        "-c",
        "import sgoda.integration.spt0245; from sgoda.integration.spt0245.gate import AutomationSecurityGate; assert len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS)==8; print('SPT0245_R1_IMPORT=PASS'); print('BLOCKING_CONTROLS=8')"
    ) -Label "SPT-024.5 import/gate validation"

    Invoke-Native -FilePath $Python -ArgumentList @("-m","pytest",$TestFile,"-q") -Label "SPT-024.5 targeted tests"
    Write-Host "TARGETED TESTS : PASS"

    Show-Step 6 "INSTITUTIONAL SUITE + COMPILEALL"
    Invoke-Native -FilePath $Python -ArgumentList @("-m","pytest","-q") -Label "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    Invoke-Native -FilePath $Python -ArgumentList @("-m","compileall","-q","src") -Label "Python compileall"
    Write-Host "COMPILEALL : PASS"

    Show-Step 7 "SECURITY REGRESSION TESTS"
    $Selectors = @(
        "plaintext_secret",
        "unauthenticated_webhook",
        "unsafe_command",
        "surface_reports_runtime_state",
        "surface_reports_secret_reference_only",
        "surface_reports_webhook",
        "surface_reports_command_safety"
    )
    foreach ($selector in $Selectors) {
        Invoke-Native -FilePath $Python -ArgumentList @("-m","pytest",$TestFile,"-q","-k",$selector) -Label ("Security regression " + $selector)
    }
    Write-Host "SECRET INDIRECTION : PASS"
    Write-Host "WEBHOOK AUTH       : PASS"
    Write-Host "COMMAND SAFETY     : PASS"
    Write-Host "SURFACE METADATA   : PASS"

    Show-Step 8 "PRODUCTION AUTOMATION SECURITY ASSESSMENT"
    $ProbePath = Join-Path $env:TEMP ("sgoda-spt0245-probe-" + [Guid]::NewGuid().ToString("N") + ".py")
    $ProbeCode = @'
from pathlib import Path
from sgoda.integration.spt0245.audit import AutomationSecurityAuditor
from sgoda.integration.spt0245.gate import AutomationSecurityGate

root = Path.cwd()
auditor = AutomationSecurityAuditor(root)
surfaces = auditor.discover_surfaces()
controls, audited = auditor.audit()

if not surfaces:
    raise SystemExit("No production workflow surfaces discovered.")

failed = [
    c.control_id
    for c in controls
    if getattr(c, "blocking", False) and not getattr(c, "passed", False)
]

print("WORKFLOW_SURFACES=%d" % len(surfaces))
print("BLOCKING_CONTROLS=%d" % len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS))
print("FAILED_BLOCKING_CONTROLS=%d" % len(failed))
print("FAILED_CONTROL_IDS=%s" % ",".join(failed))

if failed:
    raise SystemExit(20)

print("AUTOMATION_SECURITY_STATUS=AUTOMATION_SECURITY_GATE_PASS")
'@
    try {
        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ProbePath, $ProbeCode, $Utf8NoBom)
        Invoke-Native -FilePath $Python -ArgumentList @($ProbePath) -Label "Production automation security assessment"
    }
    finally {
        Remove-Item -LiteralPath $ProbePath -Force -ErrorAction SilentlyContinue
    }

    Write-Host "N8N STARTED BY GATE       : NO"
    Write-Host "WORKFLOW EXECUTED BY GATE : NO"
    Write-Host "WEBHOOK CALLED BY GATE    : NO"
    Write-Host "SECRET VALUES EXPOSED     : NO"
    Write-Host "AUTOMATION SECURITY GATE  : PASS"

    Show-Step 9 "SHA-256 / CLOSED COMPONENT PRESERVATION GATE"
    $ChangedTracked = @(& git.exe diff --name-only $ExpectedBaseline --)
    if ($LASTEXITCODE -ne 0) { throw "Unable to calculate preservation diff." }

    $ProtectedChanges = @()
    foreach ($item in $ChangedTracked) {
        $p = Normalize-Path $item
        if (-not (
            $p.StartsWith("src/sgoda/integration/spt0245/") -or
            $p -eq $TestFile -or
            $p.StartsWith("docs/06_Tecnologia/SPT-024/SPT-024.5/") -or
            $p.StartsWith("config/integration/spt0245/") -or
            $p.StartsWith("artifacts/development/SPT-024.5")
        )) {
            $ProtectedChanges += $p
        }
    }

    if ($ProtectedChanges.Count -gt 0) {
        foreach ($item in $ProtectedChanges) { Write-Host "PROTECTED CHANGE : $item" -ForegroundColor Red }
        Stop-Hold "A certified component outside SPT-024.5 changed."
    }
    Write-Host "SPT-023.1-.7 + SPT-024.1-.4 : PRESERVED"

    Show-Step 10 "EVIDENCE"
    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

    $Evidence = [ordered]@{
        component = "SPT-024.5-R1"
        version = "1.0.3"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        authoritative_baseline = $ExpectedBaseline
        recovery = [ordered]@{
            rebuild = $false
            source_state = "failed-run outputs reused"
            v102_failure = "PowerShell command-wrapper recursion / call-depth overflow"
            v103_fix = "direct git.exe invocation through non-colliding Invoke-Native wrapper"
            test_contract = "production workflow fixture scope + 8 blocking controls"
        }
        gates = [ordered]@{
            targeted_tests = "PASS"
            institutional_suite = "PASS"
            compileall = "PASS"
            production_automation_security = "PASS"
            blocking_controls = 8
            n8n_started_by_gate = $false
            workflow_executed_by_gate = $false
            webhook_called_by_gate = $false
            secret_values_exposed = $false
            closed_components_preserved = $true
        }
        publication = "PENDING_CONTROLLED_COMMIT"
    }

    $EvidenceJson = $Evidence | ConvertTo-Json -Depth 10
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $PWD $EvidenceFile), ($EvidenceJson + [Environment]::NewLine), $Utf8NoBom)
    Write-Host "EVIDENCE : CREATED"

    Show-Step 11 "EXACT CONTROLLED STAGING"
    $StageTargets = @(
        $SelfName,
        $ModuleDir,
        $TestFile,
        $PolicyFile,
        $DocDir,
        $ArtifactDir
    )

    foreach ($target in $StageTargets) {
        if (Test-Path -LiteralPath $target) {
            Invoke-Native -FilePath "git.exe" -ArgumentList @("add","--",$target) -Label ("git add " + $target)
        }
    }

    $StagedNow = @(& git.exe diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect controlled staging." }
    if ($StagedNow.Count -eq 0) { Stop-Hold "Controlled staging is empty." }

    $UnexpectedStaged = @()
    foreach ($item in $StagedNow) {
        if (-not (Is-AllowedPublishPath $item)) {
            $UnexpectedStaged += (Normalize-Path $item)
        }
    }

    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "UNEXPECTED : $($UnexpectedStaged.Count)"

    if ($UnexpectedStaged.Count -gt 0) {
        & git.exe reset
        foreach ($item in $UnexpectedStaged) { Write-Host "UNEXPECTED STAGED : $item" -ForegroundColor Red }
        Stop-Hold "Unexpected file entered controlled staging."
    }

    Write-Host "STAGING QUALITY : PASS"

    Show-Step 12 "FINAL REMOTE GATE"
    Invoke-Native -FilePath "git.exe" -ArgumentList @("fetch","origin",$Branch) -Label "final git fetch"

    $LocalBeforePublish = (& git.exe rev-parse HEAD).Trim()
    $RemoteBeforePublish = (& git.exe rev-parse ("origin/" + $Branch)).Trim()

    if ($LocalBeforePublish -ne $ExpectedBaseline -or $RemoteBeforePublish -ne $ExpectedBaseline) {
        & git.exe reset
        Stop-Hold "Authoritative baseline changed before publication."
    }
    Write-Host "REMOTE GATE : PASS"

    Show-Step 13 "COMMIT + PUSH"
    Invoke-Native -FilePath "git.exe" -ArgumentList @(
        "commit",
        "-m",
        "feat(spt-024.5): certify automation and workflow security"
    ) -Label "git commit"

    $NewCommit = (& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Invoke-Native -FilePath "git.exe" -ArgumentList @("push","origin",$Branch) -Label "git push"

    Show-Step 14 "AUTHORITATIVE REMOTE VERIFICATION"
    Invoke-Native -FilePath "git.exe" -ArgumentList @("fetch","origin",$Branch) -Label "verification git fetch"

    $FinalLocal = (& git.exe rev-parse HEAD).Trim()
    $FinalRemote = (& git.exe rev-parse ("origin/" + $Branch)).Trim()
    $CountsRaw = (& git.exe rev-list --left-right --count (("origin/" + $Branch) + "...HEAD")).Trim()
    $Counts = $CountsRaw -split '\s+'
    $FinalStaged = @(& git.exe diff --cached --name-only)
    $FinalDeleted = @(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $($Counts[0])"
    Write-Host "AHEAD           : $($Counts[1])"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if ($FinalLocal -ne $FinalRemote) { Stop-Hold "Local and remote HEAD differ after push." }
    if ($Counts[0] -ne "0" -or $Counts[1] -ne "0") { Stop-Hold "Repository is not synchronized after push." }
    if ($FinalStaged.Count -ne 0) { Stop-Hold "Staged files remain after publication." }
    if ($FinalDeleted.Count -ne 0) { Stop-Hold "Tracked deletions remain after publication." }

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host " SPT-024.5 R1 : SECURITY CERTIFIED" -ForegroundColor Green
    Write-Host " AUTOMATION_SECURITY_GATE=PASS" -ForegroundColor Green
    Write-Host " FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    exit 0
}
catch {
    Stop-Hold $_.Exception.Message
}
