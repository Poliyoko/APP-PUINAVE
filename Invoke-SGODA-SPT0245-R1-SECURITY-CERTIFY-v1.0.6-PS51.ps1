#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "54400774e87d6340e5f114facf2d80ffa5d9ebdc"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT0245-R1-SECURITY-CERTIFY-v1.0.6-PS51.ps1"
$TestFile = "tests/integration/test_spt0245_automation_security_layer1.py"
$ModuleDir = "src/sgoda/integration/spt0245"
$PolicyFile = "config/integration/spt0245/automation-security-policy.json"
$DocDir = "docs/06_Tecnologia/SPT-024/SPT-024.5"
$DocFile = "$DocDir/SGD-SPT024.5-Capa1-n8n-Automatizacion-Workflows.md"
$RuntimeFile = "artifacts/runtime/sgd002-auto/state.json"
$ArtifactDir = "artifacts/development/SPT-024.5-R1-v1.0.6"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.5 R1 v1.0.6 : HOLD" -ForegroundColor Red
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
function Is-TransactionPath {
    param([string]$PathValue)
    $p = Normalize-Path $PathValue
    if ($p -eq $SelfName) { return $true }
    if ($p.StartsWith("src/sgoda/integration/spt0245/")) { return $true }
    if ($p -eq $TestFile) { return $true }
    if ($p -eq $PolicyFile) { return $true }
    if ($p -eq $DocFile) { return $true }
    if ($p.StartsWith((Normalize-Path $ArtifactDir) + "/")) { return $true }
    return $false
}
function Is-AllowedPublishPath {
    param([string]$PathValue)
    return (Is-TransactionPath $PathValue)
}
function Get-WorktreeStatusRecords {
    $lines = @(& git.exe -c core.quotepath=false status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect worktree." }

    $records = @()
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
        $xy = $line.Substring(0,2)
        $pathPart = $line.Substring(3)
        if ($pathPart -match ' -> ') { $pathPart = ($pathPart -split ' -> ')[-1] }
        $pathPart = Normalize-Path $pathPart
        $records += [pscustomobject]@{ XY = $xy; Path = $pathPart }
    }
    return @($records)
}
function Get-PathFingerprint {
    param([Parameter(Mandatory=$true)][string]$PathValue)

    $native = $PathValue -replace '/', [IO.Path]::DirectorySeparatorChar
    if (-not (Test-Path -LiteralPath $native)) { return "MISSING" }

    $item = Get-Item -LiteralPath $native -Force
    if ($item.PSIsContainer) { return "DIRECTORY" }

    return (Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToUpperInvariant()
}
function New-PreservationSnapshot {
    $snapshot = @{}
    $records = @(Get-WorktreeStatusRecords)

    foreach ($record in $records) {
        $p = Normalize-Path $record.Path
        if ($p -eq $RuntimeFile) { continue }
        if (Is-TransactionPath $p) { continue }

        $snapshot[$p] = [ordered]@{
            status = [string]$record.XY
            sha256 = Get-PathFingerprint $p
        }
    }
    return $snapshot
}
function Assert-PreservationSnapshot {
    param(
        [Parameter(Mandatory=$true)][hashtable]$Snapshot,
        [string]$StageLabel = "PRESERVATION"
    )

    $currentRecords = @(Get-WorktreeStatusRecords)
    $current = @{}

    foreach ($record in $currentRecords) {
        $p = Normalize-Path $record.Path
        if ($p -eq $RuntimeFile) { continue }
        if (Is-TransactionPath $p) { continue }

        $current[$p] = [ordered]@{
            status = [string]$record.XY
            sha256 = Get-PathFingerprint $p
        }
    }

    $violations = @()
    $allPaths = @($Snapshot.Keys + $current.Keys | Sort-Object -Unique)

    foreach ($p in $allPaths) {
        if (-not $Snapshot.ContainsKey($p)) {
            $violations += "NEW OUTSIDE-SCOPE ITEM: $p"
            continue
        }
        if (-not $current.ContainsKey($p)) {
            $violations += "PREEXISTING ITEM DISAPPEARED: $p"
            continue
        }

        $before = $Snapshot[$p]
        $after = $current[$p]
        if ($before.status -ne $after.status) {
            $violations += "STATUS CHANGED: $p [$($before.status) -> $($after.status)]"
            continue
        }
        if ($before.sha256 -ne $after.sha256) {
            $violations += "CONTENT CHANGED: $p"
        }
    }

    if ($violations.Count -gt 0) {
        foreach ($v in $violations) { Write-Host $v -ForegroundColor Red }
        Stop-Hold "$StageLabel failed: pre-existing outside-scope worktree state changed."
    }

    Write-Host "PREEXISTING OUTSIDE-SCOPE ITEMS : $($Snapshot.Count)"
    Write-Host "PREEXISTING WORKTREE ITEMS       : PRESERVED"
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
        $PolicyFile,
        $DocFile
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

    Show-Step 3 "BASELINE SNAPSHOT / PREEXISTING WORKTREE PRESERVATION"
    # v1.0.4: pre-existing changes outside SPT-024.5 are historical state.
    # They are not deleted, restored, staged or published. Instead, freeze their
    # status + SHA-256 and require byte-for-byte preservation through publication.
    $PreexistingSnapshot = New-PreservationSnapshot
    Write-Host "PREEXISTING OUTSIDE-SCOPE ITEMS : $($PreexistingSnapshot.Count)"
    Write-Host "SNAPSHOT SHA-256                : ESTABLISHED"
    Write-Host "DESTRUCTIVE CLEANUP             : NO"
    Write-Host "SPT-023 + SPT-024.1-.4          : PRESERVATION ACTIVE"

    Show-Step 4 "REPAIR TEST / PRODUCTION-SCOPE + ACTIVE-WEBHOOK CONTRACT"
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

    # v1.0.5 semantic-contract repair:
    # AUT-WEBHOOK-AUTH intentionally blocks only ACTIVE unauthenticated webhooks.
    # The legacy negative test inherited workflow(active=False), so after the
    # production-scope migration it contradicted the certified auditor contract.
    # Repair only that named negative test; do not weaken the production control.
    $UnauthPattern = '(?ms)(def test_unauthenticated_webhook_fails\(tmp_path\):.*?workflow\()nodes=(\[\{"type": "n8n-nodes-base\.webhook"\}\])(\).*?assert \{c\.control_id: c for c in controls\}\["AUT-WEBHOOK-AUTH"\]\.passed is False)'
    if ($Raw -match $UnauthPattern) {
        $Raw = [regex]::Replace(
            $Raw,
            $UnauthPattern,
            '${1}active=True, nodes=${2}${3}',
            1
        )
    }

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

    $UnauthFunction = [regex]::Match(
        $VerifyText,
        '(?ms)def test_unauthenticated_webhook_fails\(tmp_path\):(.*?)(?=\r?\ndef test_|\z)'
    )
    if (-not $UnauthFunction.Success) {
        Stop-Hold "Required unauthenticated-webhook regression test was not found."
    }
    if ($UnauthFunction.Value -notmatch 'workflow\(\s*active=True\s*,\s*nodes=') {
        Stop-Hold "Unauthenticated-webhook negative test is not explicitly active=True."
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

    Show-Step 9 "SHA-256 / CLOSED COMPONENT + WORKTREE PRESERVATION GATE"
    # First ensure every pre-existing outside-scope item is still exactly as found.
    Assert-PreservationSnapshot -Snapshot $PreexistingSnapshot -StageLabel "SHA-256 preservation gate"

    # Then ensure any tracked delta relative to the authoritative baseline belongs
    # exclusively to the SPT-024.5 transaction. Pre-existing tracked modifications
    # outside scope are allowed only because the snapshot above proves we did not
    # alter them during this execution.
    $ChangedTracked = @(& git.exe -c core.quotepath=false diff --name-only $ExpectedBaseline --)
    if ($LASTEXITCODE -ne 0) { throw "Unable to calculate preservation diff." }

    $TransactionTracked = @()
    $PreexistingTracked = @()
    foreach ($item in $ChangedTracked) {
        $p = Normalize-Path $item
        if (Is-TransactionPath $p) {
            $TransactionTracked += $p
        }
        elseif ($PreexistingSnapshot.ContainsKey($p)) {
            $PreexistingTracked += $p
        }
        elseif ($p -ne $RuntimeFile) {
            Stop-Hold "New tracked change outside SPT-024.5 transaction detected: $p"
        }
    }

    Write-Host "TRANSACTION TRACKED DELTAS : $($TransactionTracked.Count)"
    Write-Host "PREEXISTING TRACKED DELTAS : $($PreexistingTracked.Count)"
    Write-Host "SPT-023.1-.7 + SPT-024.1-.4 : PRESERVED"

    Show-Step 10 "EVIDENCE"
    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

    $Evidence = [ordered]@{
        component = "SPT-024.5-R1"
        version = "1.0.6"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        authoritative_baseline = $ExpectedBaseline
        recovery = [ordered]@{
            rebuild = $false
            source_state = "failed-run outputs reused"
            v102_failure = "PowerShell command-wrapper recursion / call-depth overflow"
            v103_fix = "direct git.exe invocation through non-colliding Invoke-Native wrapper"
            v104_fix = "pre-existing outside-scope worktree snapshot with status and SHA-256 preservation"
            v105_fix = "align unauthenticated webhook negative regression with active-runtime security semantics; production gate unchanged"
            v106_fix = "canonical LF evidence serialization compatible with repository safecrlf policy"
            preexisting_outside_scope_items = $PreexistingSnapshot.Count
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
            preexisting_worktree_preserved = $true
        }
        publication = "PENDING_CONTROLLED_COMMIT"
    }

    $EvidenceJson = $Evidence | ConvertTo-Json -Depth 10
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    # v1.0.6: repository Git policy rejects CRLF for this JSON path.
    # Serialize canonically as UTF-8 without BOM + LF so git add cannot fail
    # with "CRLF would be replaced by LF".
    $EvidenceCanonical = (($EvidenceJson -replace "`r`n", "`n") -replace "`r", "`n") + "`n"
    [System.IO.File]::WriteAllText((Join-Path $PWD $EvidenceFile), $EvidenceCanonical, $Utf8NoBom)
    Write-Host "EVIDENCE : CREATED (UTF-8 NO BOM / LF)"

    Show-Step 11 "EXACT CONTROLLED STAGING"

    # v1.0.6: canonicalize text files created/modified by THIS transaction only.
    # No closed component or pre-existing outside-scope item is touched.
    $CanonicalLfFiles = @(
        $SelfName,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $EvidenceFile
    )
    $CanonicalLfFiles += @(
        Get-ChildItem -LiteralPath $ModuleDir -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName.Substring($PWD.Path.Length + 1) }
    )
    foreach ($RelFile in ($CanonicalLfFiles | Select-Object -Unique)) {
        $AbsFile = Join-Path $PWD $RelFile
        if (Test-Path -LiteralPath $AbsFile -PathType Leaf) {
            $Bytes = [System.IO.File]::ReadAllBytes($AbsFile)
            $HasNul = $false
            foreach ($b in $Bytes) {
                if ($b -eq 0) { $HasNul = $true; break }
            }
            if (-not $HasNul) {
                $Txt = [System.IO.File]::ReadAllText($AbsFile, [System.Text.Encoding]::UTF8)
                $Txt = ($Txt -replace "`r`n", "`n") -replace "`r", "`n"
                [System.IO.File]::WriteAllText($AbsFile, $Txt, $Utf8NoBom)
            }
        }
    }
    Write-Host "TRANSACTION LINE ENDINGS : CANONICAL LF"

    $StageTargets = @(
        $SelfName,
        $ModuleDir,
        $TestFile,
        $PolicyFile,
        $DocFile,
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
    Assert-PreservationSnapshot -Snapshot $PreexistingSnapshot -StageLabel "Post-staging preservation gate"

    Show-Step 12 "FINAL REMOTE GATE"
    Invoke-Native -FilePath "git.exe" -ArgumentList @("fetch","origin",$Branch) -Label "final git fetch"

    $LocalBeforePublish = (& git.exe rev-parse HEAD).Trim()
    $RemoteBeforePublish = (& git.exe rev-parse ("origin/" + $Branch)).Trim()

    if ($LocalBeforePublish -ne $ExpectedBaseline -or $RemoteBeforePublish -ne $ExpectedBaseline) {
        & git.exe reset
        Stop-Hold "Authoritative baseline changed before publication."
    }
    Write-Host "REMOTE GATE : PASS"
    Assert-PreservationSnapshot -Snapshot $PreexistingSnapshot -StageLabel "Pre-commit preservation gate"

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
    Assert-PreservationSnapshot -Snapshot $PreexistingSnapshot -StageLabel "Post-publication preservation gate"

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host " SPT-024.5 R1 : SECURITY CERTIFIED" -ForegroundColor Green
    Write-Host " AUTOMATION_SECURITY_GATE=PASS" -ForegroundColor Green
    Write-Host " PREEXISTING_WORKTREE_PRESERVED=YES" -ForegroundColor Green
    Write-Host " FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    exit 0
}
catch {
    Stop-Hold $_.Exception.Message
}
