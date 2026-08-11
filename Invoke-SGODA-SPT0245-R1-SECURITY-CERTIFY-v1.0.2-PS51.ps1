#requires -Version 5.1
<#
SGODA-PUINAVE
SPT-024.5-R1 SECURITY CERTIFY v1.0.2 PS5.1
Purpose:
 - Recover the failed v1.0.1 transaction without rebuilding SPT-024.5 from scratch.
 - Correct the test/production-scope contract mismatch found in v1.0.1.
 - Revalidate targeted + institutional suites.
 - Preserve SPT-023 and SPT-024.1-.4.
 - Publish only after every blocking gate passes.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "54400774e87d6340e5f114facf2d80ffa5d9ebdc"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT0245-R1-SECURITY-CERTIFY-v1.0.2-PS51.ps1"
$TestFile = "tests/integration/test_spt0245_automation_security_layer1.py"
$ModuleDir = "src/sgoda/integration/spt0245"
$PolicyFile = "config/integration/spt0245/automation-security-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.5/SGD-SPT024.5-Capa1-n8n-Automatizacion-Workflows.md"
$ArtifactDir = "artifacts/development/SPT-024.5-R1-v1.0.2"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.5 R1 v1.0.2 : HOLD" -ForegroundColor Red
    Write-Host " REASON               : $Message" -ForegroundColor Red
    Write-Host " TRANSACTION          : NOT PUBLISHED" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    exit 1
}
function Step([int]$N,[string]$Text) {
    Write-Host ""
    Write-Host ("[{0}/14] {1}" -f $N,$Text) -ForegroundColor Cyan
}
function Git([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args) {
    & git @Args
    if ($LASTEXITCODE -ne 0) { throw "git $($Args -join ' ') failed ($LASTEXITCODE)" }
}
function Get-Python {
    $candidates = @(
        (Join-Path $PWD ".venv\Scripts\python.exe"),
        (Join-Path $PWD "venv\Scripts\python.exe")
    )
    foreach($p in $candidates){ if(Test-Path -LiteralPath $p){ return $p } }
    $cmd = Get-Command python.exe -ErrorAction SilentlyContinue
    if($cmd){ return $cmd.Source }
    throw "Python executable not found."
}
function Assert-Last([string]$Label) {
    if($LASTEXITCODE -ne 0){ Fail "$Label failed with exit code $LASTEXITCODE." }
}

try {
    Step 1 "AUTHORITATIVE BASELINE / RESUME / WORKTREE SAFETY"
    if(-not (Test-Path ".git")) { Fail "Run this master from the SGODA-PUINAVE repository root." }

    Git fetch origin $Branch
    $local = (& git rev-parse HEAD).Trim()
    $remote = (& git rev-parse "origin/$Branch").Trim()
    $staged = @(& git diff --cached --name-only)
    $deleted = @(& git -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $local"
    Write-Host "REMOTE HEAD     : $remote"
    Write-Host "STAGED          : $($staged.Count)"
    Write-Host "DELETED TRACKED : $($deleted.Count)"

    if($local -ne $ExpectedBaseline){ Fail "Unexpected local baseline. Expected $ExpectedBaseline, found $local." }
    if($remote -ne $ExpectedBaseline){ Fail "Unexpected remote baseline. Expected $ExpectedBaseline, found $remote." }
    if($staged.Count -ne 0){ Fail "Pre-existing staged changes detected." }
    if($deleted.Count -ne 0){ Fail "Tracked deletions detected." }

    $runtime = "artifacts/runtime/sgd002-auto/state.json"
    if(Test-Path $runtime){ Write-Host "RUNTIME PRESERVED : $runtime" }
    Write-Host "BASELINE : PASS"

    Step 2 "RECOVER FAILED v1.0.1 OUTPUTS WITHOUT REBUILD"
    $required = @(
        "$ModuleDir/__init__.py",
        "$ModuleDir/models.py",
        "$ModuleDir/policy.py",
        "$ModuleDir/workflow_guard.py",
        "$ModuleDir/audit.py",
        "$ModuleDir/gate.py",
        "$ModuleDir/service.py",
        $TestFile,
        $PolicyFile,
        $DocFile
    )
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath $_) })
    if($missing.Count -gt 0){
        Write-Host "Missing failed-run outputs:" -ForegroundColor Yellow
        $missing | ForEach-Object { Write-Host "  $_" }
        Fail "v1.0.1 outputs are incomplete. This recovery master intentionally does not rebuild SPT-024.5."
    }
    Write-Host "SPT-024.5 v1.0.1 OUTPUTS : RECOVERED"
    Write-Host "SPT-024.5 REBUILD         : NO"

    Step 3 "FREEZE CLOSED COMPONENTS"
    # Closed components are protected by allowing publication only of the exact SPT-024.5 target set.
    $preStatus = @(& git status --porcelain=v1)
    $foreign = @()
    foreach($line in $preStatus){
        if($line.Length -lt 4){ continue }
        $p = $line.Substring(3).Trim('"').Replace('\','/')
        if($p -eq $runtime){ continue }
        $allowedPrefix = @(
            "src/sgoda/integration/spt0245/",
            "tests/integration/test_spt0245_automation_security_layer1.py",
            "docs/06_Tecnologia/SPT-024/SPT-024.5/",
            "config/integration/spt0245/",
            "artifacts/development/SPT-024.5",
            "Invoke-SGODA-SPT0245-"
        )
        $ok = $false
        foreach($a in $allowedPrefix){ if($p.StartsWith($a)){ $ok=$true; break } }
        if(-not $ok){ $foreign += $p }
    }
    if($foreign.Count -gt 0){
        Write-Host ($foreign -join "`n") -ForegroundColor Yellow
        Fail "Unexpected non-SPT-024.5 worktree changes detected."
    }
    Write-Host "SPT-023 + SPT-024.1-.4 : PROTECTED"

    Step 4 "REPAIR v1.0.1 TEST / PRODUCTION-SCOPE CONTRACT"
    $raw = Get-Content -LiteralPath $TestFile -Raw -Encoding UTF8
    $before = $raw

    # v1.0.1 correctly restricted the auditor to production workflow scope.
    # The tests, however, still wrote fixtures to tmp_path/workflows.
    # Move every such fixture into the same production-relative scope.
    $raw = $raw.Replace('tmp_path / "workflows"', 'tmp_path / "automation" / "n8n" / "workflows"')
    $raw = $raw.Replace("tmp_path / 'workflows'", "tmp_path / 'automation' / 'n8n' / 'workflows'")

    # R1 added AUT-PRODUCTION-SCOPE, so the final blocking-control contract is 8.
    $raw = $raw.Replace("len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS) == 7",
                        "len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS) == 8")

    if($raw -eq $before){ Fail "No known v1.0.1 contract mismatch was found in the targeted test file." }

    [System.IO.File]::WriteAllText(
        (Join-Path $PWD $TestFile),
        $raw,
        (New-Object System.Text.UTF8Encoding($false))
    )

    # Hard assertions: no legacy fixture root and no stale gate count may remain.
    $verify = Get-Content -LiteralPath $TestFile -Raw -Encoding UTF8
    if($verify -match 'tmp_path\s*/\s*["'']workflows["'']'){
        Fail "Legacy tmp_path/workflows fixture contract remains after remediation."
    }
    if($verify -match 'REQUIRED_BLOCKING_CONTROLS\)\s*==\s*7'){
        Fail "Stale 7-control gate expectation remains after remediation."
    }
    Write-Host "FIXTURE PRODUCTION SCOPE : CORRECTED"
    Write-Host "BLOCKING CONTROL COUNT   : 8"
    Write-Host "MANUAL EDITING           : NOT REQUIRED"

    Step 5 "PYTHON IMPORT + TARGETED TEST PREVALIDATION"
    $Py = Get-Python
    $env:PYTHONPATH = (Join-Path $PWD "src")
    & $Py -c "import sgoda.integration.spt0245; from sgoda.integration.spt0245.gate import AutomationSecurityGate; assert len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS)==8; print('SPT0245_R1_IMPORT=PASS'); print('BLOCKING_CONTROLS=8')"
    Assert-Last "SPT-024.5 import/gate contract"

    & $Py -m pytest $TestFile -q
    Assert-Last "SPT-024.5 targeted tests"
    Write-Host "TARGETED TESTS : PASS"

    Step 6 "INSTITUTIONAL SUITE + COMPILEALL"
    & $Py -m pytest -q
    Assert-Last "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    & $Py -m compileall -q src
    Assert-Last "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 7 "SECURITY CONTRACT REGRESSION GATES"
    # Explicitly execute the security-focused tests by semantic selector as an
    # additional anti-regression gate. If selectors do not match, full targeted
    # suite above still remains authoritative.
    $selectors = @(
        "plaintext_secret",
        "unauthenticated_webhook",
        "unsafe_command",
        "surface_reports_runtime_state",
        "surface_reports_secret_reference_only",
        "surface_reports_webhook",
        "surface_reports_command_safety"
    )
    foreach($s in $selectors){
        & $Py -m pytest $TestFile -q -k $s
        Assert-Last "Security regression selector '$s'"
    }
    Write-Host "SECRET INDIRECTION     : PASS"
    Write-Host "WEBHOOK AUTH           : PASS"
    Write-Host "COMMAND EXECUTION      : PASS"
    Write-Host "WORKFLOW RUNTIME STATE : PASS"

    Step 8 "NON-DESTRUCTIVE AUTOMATION SECURITY ASSESSMENT"
    # No n8n process, workflow or webhook is started/called here.
    # We validate that the real repository workflows are discoverable by the
    # production-scope auditor and that the gate can be constructed.
    $probe = @'
from pathlib import Path
from sgoda.integration.spt0245.audit import AutomationSecurityAuditor
from sgoda.integration.spt0245.gate import AutomationSecurityGate

root = Path.cwd()
auditor = AutomationSecurityAuditor(root)
surfaces = auditor.discover_surfaces()
controls, audited = auditor.audit()

if len(surfaces) == 0:
    raise SystemExit("No production automation/workflow surfaces discovered.")

failed = [c.control_id for c in controls if getattr(c, "blocking", False) and not getattr(c, "passed", False)]
print("WORKFLOW_SURFACES=%d" % len(surfaces))
print("BLOCKING_CONTROLS=%d" % len(AutomationSecurityGate.REQUIRED_BLOCKING_CONTROLS))
print("FAILED_BLOCKING_CONTROLS=%d" % len(failed))
print("FAILED_CONTROL_IDS=%s" % ",".join(failed))
if failed:
    raise SystemExit(20)
print("AUTOMATION_SECURITY_STATUS=AUTOMATION_SECURITY_GATE_PASS")
'@
    & $Py -c $probe
    Assert-Last "Production automation security assessment"
    Write-Host "N8N STARTED BY GATE       : NO"
    Write-Host "WORKFLOW EXECUTED BY GATE : NO"
    Write-Host "WEBHOOK CALLED BY GATE    : NO"
    Write-Host "SECRET VALUES EXPOSED     : NO"
    Write-Host "AUTOMATION SECURITY GATE  : PASS"

    Step 9 "PRESERVATION GATE"
    # Tracked files from the certified baseline must remain untouched.
    $changedTracked = @(& git diff --name-only $ExpectedBaseline --)
    $badTracked = @($changedTracked | Where-Object {
        $p=$_.Replace('\','/')
        -not (
            $p.StartsWith("src/sgoda/integration/spt0245/") -or
            $p -eq $TestFile -or
            $p.StartsWith("docs/06_Tecnologia/SPT-024/SPT-024.5/") -or
            $p.StartsWith("config/integration/spt0245/") -or
            $p.StartsWith("artifacts/development/SPT-024.5")
        )
    })
    if($badTracked.Count -gt 0){
        $badTracked | ForEach-Object { Write-Host "PROTECTED CHANGE : $_" -ForegroundColor Red }
        Fail "A closed component changed."
    }
    Write-Host "SPT-023.1-.7 + SPT-024.1-.4 : PRESERVED"

    Step 10 "EVIDENCE"
    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
    $evidence = [ordered]@{
        component = "SPT-024.5-R1"
        version = "1.0.2"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        authoritative_baseline = $ExpectedBaseline
        recovery = [ordered]@{
            source_failed_master = "Invoke-SGODA-SPT0245-R1-SECURITY-CERTIFY-v1.0.1-PS51.ps1"
            rebuild = $false
            repair = "test-production-scope-contract"
        }
        gates = [ordered]@{
            python_import = "PASS"
            blocking_controls = 8
            targeted_tests = "PASS"
            institutional_suite = "PASS"
            compileall = "PASS"
            production_security_assessment = "PASS"
            n8n_started = $false
            workflow_executed = $false
            webhook_called = $false
            secret_values_exposed = $false
            closed_components_preserved = $true
        }
        publication = "PENDING_CONTROLLED_COMMIT"
    }
    $json = $evidence | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText(
        (Join-Path $PWD $EvidenceFile),
        $json + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host "EVIDENCE : CREATED"

    Step 11 "EXACT CONTROLLED STAGING"
    # Stage only the recovered/certified SPT-024.5 transaction and this master.
    $stageTargets = @(
        $SelfName,
        $ModuleDir,
        $TestFile,
        $PolicyFile,
        "docs/06_Tecnologia/SPT-024/SPT-024.5",
        $ArtifactDir
    )
    foreach($t in $stageTargets){
        if(Test-Path -LiteralPath $t){ & git add -- $t; Assert-Last "git add $t" }
    }

    $stagedNow = @(& git diff --cached --name-only)
    if($stagedNow.Count -eq 0){ Fail "Nothing was staged." }

    $unexpected = @($stagedNow | Where-Object {
        $p=$_.Replace('\','/')
        -not (
            $p -eq $SelfName -or
            $p.StartsWith("src/sgoda/integration/spt0245/") -or
            $p -eq $TestFile -or
            $p.StartsWith("docs/06_Tecnologia/SPT-024/SPT-024.5/") -or
            $p.StartsWith("config/integration/spt0245/") -or
            $p.StartsWith("artifacts/development/SPT-024.5-R1-v1.0.2/")
        )
    })
    Write-Host "STAGED     : $($stagedNow.Count)"
    Write-Host "UNEXPECTED : $($unexpected.Count)"
    if($unexpected.Count -gt 0){
        & git reset
        Fail "Unexpected file entered controlled staging."
    }
    Write-Host "STAGING QUALITY : PASS"

    Step 12 "FINAL REMOTE GATE"
    Git fetch origin $Branch
    $local2 = (& git rev-parse HEAD).Trim()
    $remote2 = (& git rev-parse "origin/$Branch").Trim()
    if($local2 -ne $ExpectedBaseline -or $remote2 -ne $ExpectedBaseline){
        & git reset
        Fail "Authoritative baseline changed before publication."
    }
    Write-Host "REMOTE GATE : PASS"

    Step 13 "COMMIT + PUSH"
    & git commit -m "feat(spt-024.5): certify automation and workflow security"
    Assert-Last "git commit"
    $newCommit = (& git rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $newCommit"
    & git push origin $Branch
    Assert-Last "git push"

    Step 14 "AUTHORITATIVE REMOTE VERIFICATION"
    Git fetch origin $Branch
    $finalLocal = (& git rev-parse HEAD).Trim()
    $finalRemote = (& git rev-parse "origin/$Branch").Trim()
    $aheadBehind = (& git rev-list --left-right --count "origin/$Branch...HEAD").Trim() -split "\s+"
    $finalStaged = @(& git diff --cached --name-only)
    $finalDeleted = @(& git -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $finalLocal"
    Write-Host "REMOTE HEAD     : $finalRemote"
    Write-Host "AHEAD           : $($aheadBehind[1])"
    Write-Host "BEHIND          : $($aheadBehind[0])"
    Write-Host "STAGED          : $($finalStaged.Count)"
    Write-Host "DELETED TRACKED : $($finalDeleted.Count)"

    if($finalLocal -ne $finalRemote){ Fail "Local/remote mismatch after push." }
    if($aheadBehind[0] -ne "0" -or $aheadBehind[1] -ne "0"){ Fail "Repository not synchronized after push." }
    if($finalStaged.Count -ne 0){ Fail "Staged changes remain after publication." }
    if($finalDeleted.Count -ne 0){ Fail "Tracked deletions remain after publication." }

    Write-Host ""
    Write-Host "SPT-024.5 R1 : SECURITY CERTIFIED" -ForegroundColor Green
    Write-Host "AUTOMATION_SECURITY_GATE=PASS" -ForegroundColor Green
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    exit 0
}
catch {
    Fail $_.Exception.Message
}
