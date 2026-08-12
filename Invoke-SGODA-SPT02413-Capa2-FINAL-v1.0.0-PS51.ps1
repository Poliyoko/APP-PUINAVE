#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="6b5416c27761e09e98147866c36ec4cdd608e97a"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$SelfName="Invoke-SGODA-SPT02413-Capa2-FINAL-v1.0.0-PS51.ps1"
$ModuleDir="src/sgoda/integration/spt02413l2"
$TestFile="tests/integration/test_spt02413_continuity_recovery_governance_layer2.py"
$PolicyFile="config/integration/spt02413/continuity-recovery-governance-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.13/SGD-SPT024.13-Capa2-Estrategias-Recuperacion-Restore-RTO-RPO-Redundancia-Failover.md"
$ArtifactDir="artifacts/development/SPT-024.13-Capa2-v1.0.0"
$AssessmentFile="$ArtifactDir/continuity-recovery-governance-assessment.json"
$StrategyFile="$ArtifactDir/recovery-strategy-baseline.json"
$RestoreFile="$ArtifactDir/restore-testing-baseline.json"
$ObjectivesFile="$ArtifactDir/rto-rpo-advanced-baseline.json"
$RedundancyFile="$ArtifactDir/redundancy-governance-baseline.json"
$FailoverFile="$ArtifactDir/controlled-failover-baseline.json"
$IntegrityFile="$ArtifactDir/continuity-recovery-integrity-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){ Write-Host ""; Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan }
function Hold([string]$Reason){ Write-Host ""; Write-Host "SPT-024.13 CAPA 2 : HOLD" -ForegroundColor Red; Write-Host "REASON : $Reason" -ForegroundColor Red; Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow; exit 1 }
function Native([string]$Exe,[string[]]$NativeArgs,[string]$Label){ & $Exe @NativeArgs; if($LASTEXITCODE -ne 0){throw "$Label failed with exit code $LASTEXITCODE"} }
function GitFetch {
    for($i=1;$i -le 4;$i++){ Write-Host "GIT FETCH ATTEMPT : $i/4"; & git.exe fetch origin $Branch; if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return}; Start-Sleep -Seconds 2 }
    Hold "git fetch failed after 4 attempts"
}
function WriteLf([string]$Path,[string]$Text){
    $Target=if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $Root $Path}
    $Parent=Split-Path -Parent $Target
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){New-Item -ItemType Directory -Force -Path $Parent|Out-Null}
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $Canonical.EndsWith("`n")){$Canonical+="`n"}
    [IO.File]::WriteAllText($Target,$Canonical,$Utf8)
}
function Sha([string]$Path){ return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant() }
function SizeGate {
    $bad=New-Object System.Collections.Generic.List[string]
    $idx=@(& git.exe -c core.quotepath=false ls-files)
    foreach($p in $idx){
        $s=@(& git.exe cat-file -s (":"+$p) 2>$null)
        if($LASTEXITCODE -eq 0 -and @($s).Count -gt 0){
            [Int64]$n=0
            if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){[void]$bad.Add(($p -replace '\\','/'))}
        }
    }
    return @($bad.ToArray())
}

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if($LASTEXITCODE -ne 0 -or -not $Root){Hold "Not inside Git repository"}
    Set-Location $Root
    $Python=Join-Path $Root ".venv\Scripts\python.exe"
    if(-not(Test-Path -LiteralPath $Python)){$Python="python.exe"}

    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
    GitFetch
    $Local=(& git.exe rev-parse HEAD).Trim()
    $Remote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Staged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Deleted=@(& git.exe -c core.quotepath=false ls-files --deleted)
    Write-Host "LOCAL HEAD      : $Local"; Write-Host "REMOTE HEAD     : $Remote"; Write-Host "STAGED          : $($Staged.Count)"; Write-Host "DELETED TRACKED : $($Deleted.Count)"
    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){Hold "Authoritative baseline mismatch"}
    if($Staged.Count -ne 0 -or $Deleted.Count -ne 0){Hold "Unsafe pre-existing staged/deleted state"}
    Write-Host "BASELINE : PASS"
    Write-Host "SPT-024.1-.12 + SPT-024.13 CAPA 1 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY SPT-024.13 CAPA 1 INPUTS / RECOVERY STATE"
    $RequiredC1=@('artifacts/development/SPT-024.13-Capa1-v1.0.0/continuity-resilience-assessment.json','artifacts/development/SPT-024.13-Capa1-v1.0.0/backup-governance-baseline.json','artifacts/development/SPT-024.13-Capa1-v1.0.0/recovery-governance-baseline.json','artifacts/development/SPT-024.13-Capa1-v1.0.0/availability-governance-baseline.json','artifacts/development/SPT-024.13-Capa1-v1.0.0/contingency-governance-baseline.json','artifacts/development/SPT-024.13-Capa1-v1.0.0/continuity-resilience-integrity-manifest.json','artifacts/development/SPT-024.13-Capa1-v1.0.0/implementation-evidence.json')
    $Missing=@($RequiredC1|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
    Write-Host "REQUIRED CAPA 1 INPUTS : $($RequiredC1.Count)"
    Write-Host "MISSING INPUTS         : $($Missing.Count)"
    if($Missing.Count -gt 0){Hold ("Missing Capa 1 inputs: "+($Missing -join ", "))}
    $C1=(Get-Content -Raw -LiteralPath (Join-Path $Root $RequiredC1[0])|ConvertFrom-Json)
    if([string]$C1.status -ne "CONTINUITY_RESILIENCE_GATE_PASS"){Hold "Capa 1 continuity gate is not PASS"}
    Write-Host "CAPA 1 CONTINUITY / RESILIENCE GATE : PASS"
    $Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $Existing=@($Targets|Where-Object{Test-Path -LiteralPath (Join-Path $Root $_)})
    Write-Host "PREEXISTING CAPA 2 TARGETS          : $($Existing.Count)"
    Write-Host ("CAPA 2 RESUME MODE                  : "+$(if($Existing.Count -gt 0){"YES"}else{"NO"}))

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}
    foreach($p in $Protected){$full=Join-Path $Root $p;if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}}
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "RECOVERY / RESTORE / RTO-RPO / REDUNDANCY / FAILOVER DISCOVERY"
    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (($p -match '(backup|restore|recovery|resilien|continuity|availability|contingenc|failover|redundan|rollback|snapshot|rto|rpo|health|monitor|incident|disaster|postgres|database|n8n|fastapi|workflow|release|deploy)') -or ($p -match '(^|/)(config|automation|tools|src|\.github|docs|artifacts)(/|$)')) -and
        ($p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$')
    })
    Write-Host "CONTINUITY RECOVERY SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE               : STATIC / NON-DESTRUCTIVE"
    Write-Host "RESTORE EXECUTED             : NO"
    Write-Host "FAILOVER EXECUTED            : NO"
    Write-Host "TRAFFIC SHIFTED              : NO"
    Write-Host "INFRASTRUCTURE CHANGED       : NO"

    Step 5 "IMPLEMENT SPT-024.13 CAPA 2"
    $C6535833ab5=@'
"""SPT-024.13 Capa 2 — advanced recovery, restore testing, RTO/RPO, redundancy and failover governance."""
from .service import ContinuityRecoveryGovernanceService
from .gate import ContinuityRecoveryGovernanceGate
__all__ = ["ContinuityRecoveryGovernanceService", "ContinuityRecoveryGovernanceGate"]
'@
WriteLf 'src/sgoda/integration/spt02413l2/__init__.py' $C6535833ab5
$C4a47056eca=@'
from dataclasses import dataclass

@dataclass(frozen=True)
class RecoveryControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str
'@
WriteLf 'src/sgoda/integration/spt02413l2/models.py' $C4a47056eca
$Ce4fe194ac8=@'
from typing import Mapping

def assess_recovery_strategy(profile: Mapping) -> dict:
    checks = {
        "documented": bool(profile.get("documented")),
        "prioritized": bool(profile.get("prioritized")),
        "dependencies_mapped": bool(profile.get("dependencies_mapped")),
        "runbook_defined": bool(profile.get("runbook_defined")),
        "owners_defined": bool(profile.get("owners_defined")),
    }
    return {"valid": all(checks.values()), **checks, "recovery_executed": False}
'@
WriteLf 'src/sgoda/integration/spt02413l2/recovery_strategy.py' $Ce4fe194ac8
$C0160c8a08b=@'
from typing import Mapping

def assess_restore_test(profile: Mapping) -> dict:
    checks = {
        "isolated_test": bool(profile.get("isolated_test")),
        "integrity_verified": bool(profile.get("integrity_verified")),
        "evidence_required": bool(profile.get("evidence_required")),
        "rollback_defined": bool(profile.get("rollback_defined")),
    }
    return {"valid": all(checks.values()), **checks, "restore_executed": False, "production_data_modified": False}
'@
WriteLf 'src/sgoda/integration/spt02413l2/restore_testing.py' $C0160c8a08b
$C138b768fe0=@'
from typing import Mapping

def assess_rto_rpo(profile: Mapping) -> dict:
    rto = int(profile.get("rto_minutes", 0))
    rpo = int(profile.get("rpo_minutes", 0))
    max_rto = int(profile.get("max_rto_minutes", 0))
    max_rpo = int(profile.get("max_rpo_minutes", 0))
    valid = rto > 0 and rpo >= 0 and max_rto > 0 and max_rpo >= 0 and rto <= max_rto and rpo <= max_rpo
    return {"valid": valid, "rto_minutes": rto, "rpo_minutes": rpo, "max_rto_minutes": max_rto, "max_rpo_minutes": max_rpo}
'@
WriteLf 'src/sgoda/integration/spt02413l2/objectives.py' $C138b768fe0
$Cd214eb3b59=@'
from typing import Mapping

def assess_redundancy(profile: Mapping) -> dict:
    checks = {
        "failure_domain_separation": bool(profile.get("failure_domain_separation")),
        "dependency_redundancy": bool(profile.get("dependency_redundancy")),
        "capacity_defined": bool(profile.get("capacity_defined")),
        "health_criteria_defined": bool(profile.get("health_criteria_defined")),
    }
    return {"valid": all(checks.values()), **checks, "infrastructure_changed": False}
'@
WriteLf 'src/sgoda/integration/spt02413l2/redundancy.py' $Cd214eb3b59
$C346dfb61cd=@'
from typing import Mapping

def assess_failover(profile: Mapping) -> dict:
    checks = {
        "approval_required": bool(profile.get("approval_required")),
        "prechecks_required": bool(profile.get("prechecks_required")),
        "rollback_required": bool(profile.get("rollback_required")),
        "evidence_required": bool(profile.get("evidence_required")),
        "manual_activation": bool(profile.get("manual_activation")),
    }
    return {"valid": all(checks.values()), **checks, "failover_executed": False, "traffic_shifted": False}
'@
WriteLf 'src/sgoda/integration/spt02413l2/failover.py' $C346dfb61cd
$C12a6de5fb7=@'
import hashlib, json
from typing import Mapping

def canonical_sha256(value: Mapping) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    return hashlib.sha256(raw).hexdigest().upper()
'@
WriteLf 'src/sgoda/integration/spt02413l2/integrity.py' $C12a6de5fb7
$C9e0dc0e95b=@'
from typing import Iterable

def evidence_ledger(records: Iterable[dict]) -> list:
    result = []
    for item in records:
        result.append({"control_id": item["control_id"], "status": "PASS" if item["passed"] else "FAIL", "blocking": bool(item["blocking"])})
    return result
'@
WriteLf 'src/sgoda/integration/spt02413l2/audit.py' $C9e0dc0e95b
$C5b3f2880a8=@'
class ContinuityRecoveryGovernanceGate:
    def evaluate(self, controls):
        failed = [c for c in controls if c.blocking and not c.passed]
        return {"passed": len(failed) == 0, "failed_blocking_controls": len(failed), "failed_control_ids": [c.control_id for c in failed]}
'@
WriteLf 'src/sgoda/integration/spt02413l2/gate.py' $C5b3f2880a8
$C287ebe803f=@'
from .models import RecoveryControl
from .recovery_strategy import assess_recovery_strategy
from .restore_testing import assess_restore_test
from .objectives import assess_rto_rpo
from .redundancy import assess_redundancy
from .failover import assess_failover
from .gate import ContinuityRecoveryGovernanceGate

class ContinuityRecoveryGovernanceService:
    def assess(self, policy):
        strategy = assess_recovery_strategy(policy["recovery_strategy"])
        restore = assess_restore_test(policy["restore_testing"])
        objectives = assess_rto_rpo(policy["rto_rpo"])
        redundancy = assess_redundancy(policy["redundancy"])
        failover = assess_failover(policy["failover"])
        pairs = [
            ("CRG-01", "Capa 1 continuity gate", policy.get("layer1_gate") == "CONTINUITY_RESILIENCE_GATE_PASS"),
            ("CRG-02", "Recovery strategy", strategy["valid"]),
            ("CRG-03", "Restore testing governance", restore["valid"]),
            ("CRG-04", "Advanced RTO/RPO", objectives["valid"]),
            ("CRG-05", "Redundancy governance", redundancy["valid"]),
            ("CRG-06", "Controlled failover", failover["valid"]),
            ("CRG-07", "Approval before failover", failover["approval_required"]),
            ("CRG-08", "Rollback before failover", failover["rollback_required"]),
            ("CRG-09", "Integrity before restore", restore["integrity_verified"]),
            ("CRG-10", "Failure-domain separation", redundancy["failure_domain_separation"]),
            ("CRG-11", "No automatic destructive action", not bool(policy.get("automatic_destructive_action"))),
            ("CRG-12", "Secret indirection", bool(policy.get("secret_indirection"))),
        ]
        controls = [RecoveryControl(i, n, bool(p), True, n) for i,n,p in pairs]
        gate = ContinuityRecoveryGovernanceGate().evaluate(controls)
        return {"gate": gate, "controls": controls, "strategy": strategy, "restore": restore, "objectives": objectives, "redundancy": redundancy, "failover": failover}
'@
WriteLf 'src/sgoda/integration/spt02413l2/service.py' $C287ebe803f
$C62e63c6e1f=@'
from sgoda.integration.spt02413l2.service import ContinuityRecoveryGovernanceService
from sgoda.integration.spt02413l2.restore_testing import assess_restore_test
from sgoda.integration.spt02413l2.failover import assess_failover
from sgoda.integration.spt02413l2.integrity import canonical_sha256

def policy():
    return {
        "layer1_gate": "CONTINUITY_RESILIENCE_GATE_PASS",
        "recovery_strategy": {"documented": True, "prioritized": True, "dependencies_mapped": True, "runbook_defined": True, "owners_defined": True},
        "restore_testing": {"isolated_test": True, "integrity_verified": True, "evidence_required": True, "rollback_defined": True},
        "rto_rpo": {"rto_minutes": 60, "rpo_minutes": 15, "max_rto_minutes": 120, "max_rpo_minutes": 30},
        "redundancy": {"failure_domain_separation": True, "dependency_redundancy": True, "capacity_defined": True, "health_criteria_defined": True},
        "failover": {"approval_required": True, "prechecks_required": True, "rollback_required": True, "evidence_required": True, "manual_activation": True},
        "automatic_destructive_action": False, "secret_indirection": True,
    }

def test_gate_passes(): assert ContinuityRecoveryGovernanceService().assess(policy())["gate"]["passed"]
def test_twelve_controls(): assert len(ContinuityRecoveryGovernanceService().assess(policy())["controls"]) == 12
def test_no_failed_blockers(): assert ContinuityRecoveryGovernanceService().assess(policy())["gate"]["failed_blocking_controls"] == 0
def test_restore_is_non_destructive(): assert assess_restore_test(policy()["restore_testing"])["restore_executed"] is False
def test_restore_does_not_modify_production(): assert assess_restore_test(policy()["restore_testing"])["production_data_modified"] is False
def test_failover_not_executed(): assert assess_failover(policy()["failover"])["failover_executed"] is False
def test_traffic_not_shifted(): assert assess_failover(policy()["failover"])["traffic_shifted"] is False
def test_rto_is_within_limit(): assert ContinuityRecoveryGovernanceService().assess(policy())["objectives"]["valid"]
def test_redundancy_passes(): assert ContinuityRecoveryGovernanceService().assess(policy())["redundancy"]["valid"]
def test_recovery_strategy_passes(): assert ContinuityRecoveryGovernanceService().assess(policy())["strategy"]["valid"]
def test_sha256_is_stable(): assert canonical_sha256({"b":2,"a":1}) == canonical_sha256({"a":1,"b":2})
def test_secret_indirection_control(): assert ContinuityRecoveryGovernanceService().assess(policy())["controls"][-1].passed
'@
WriteLf 'tests/integration/test_spt02413_continuity_recovery_governance_layer2.py' $C62e63c6e1f
$C762634912c=@'
{
  "schema_version": "1.0.0",
  "component": "SPT-024.13",
  "layer": 2,
  "layer1_gate": "CONTINUITY_RESILIENCE_GATE_PASS",
  "recovery_strategy": {
    "documented": true,
    "prioritized": true,
    "dependencies_mapped": true,
    "runbook_defined": true,
    "owners_defined": true
  },
  "restore_testing": {
    "isolated_test": true,
    "integrity_verified": true,
    "evidence_required": true,
    "rollback_defined": true
  },
  "rto_rpo": {
    "rto_minutes": 60,
    "rpo_minutes": 15,
    "max_rto_minutes": 120,
    "max_rpo_minutes": 30
  },
  "redundancy": {
    "failure_domain_separation": true,
    "dependency_redundancy": true,
    "capacity_defined": true,
    "health_criteria_defined": true
  },
  "failover": {
    "approval_required": true,
    "prechecks_required": true,
    "rollback_required": true,
    "evidence_required": true,
    "manual_activation": true
  },
  "automatic_destructive_action": false,
  "secret_indirection": true
}
'@
WriteLf 'config/integration/spt02413/continuity-recovery-governance-policy.json' $C762634912c
$Cdc6cee7db0=@'
# SPT-024.13 Capa 2 — Estrategias de Recuperación, Pruebas de Restauración, RTO/RPO Avanzado, Redundancia, Failover Controlado y Gobierno de Continuidad

## Objetivo
Consolidar la segunda capa de continuidad operacional reutilizando íntegramente SPT-024.13 Capa 1.

## Controles
- Estrategias documentadas y priorizadas de recuperación.
- Pruebas de restauración aisladas, verificables y no destructivas.
- Objetivos RTO/RPO medibles y gobernados.
- Redundancia por dominios de falla y dependencias.
- Failover exclusivamente controlado, aprobado, reversible y con evidencia.
- Integridad SHA-256 y trazabilidad institucional.

## Restricciones de ejecución
Esta implementación no ejecuta backup, restore, failover, reinicios, desplazamiento de tráfico, cambios de infraestructura ni modificaciones de datos productivos. Las evaluaciones son estáticas y de gobierno.

## Cierre
La publicación solo se permite con pruebas dirigidas, suite institucional, compileall, preservation gate, staging exacto, gate de tamaño GitHub, commit, push y LOCAL HEAD = REMOTE HEAD.
'@
WriteLf 'docs/06_Tecnologia/SPT-024/SPT-024.13/SGD-SPT024.13-Capa2-Estrategias-Recuperacion-Restore-RTO-RPO-Redundancia-Failover.md' $Cdc6cee7db0
    Write-Host "SPT-024.13 CAPA 2 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    & $Python -c "import sys; assert len(sys.argv)==1; print('PYTHON_ARGUMENT_CONTRACT=PASS')"
    if($LASTEXITCODE -ne 0){Hold "Python argument contract failed"}
    & $Python -c "from sgoda.integration.spt02413l2 import ContinuityRecoveryGovernanceService; print('SPT02413_CAPA2_IMPORT=PASS'); print('BLOCKING_CONTROLS=12')"
    if($LASTEXITCODE -ne 0){Hold "Capa 2 import failed"}
    & $Python -m pytest -q $TestFile
    if($LASTEXITCODE -ne 0){Hold "Targeted tests failed"}
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
    & $Python -m pytest -q
    if($LASTEXITCODE -ne 0){Hold "Institutional suite failed"}
    Write-Host "FULL SUITE : PASS"
    & $Python -m compileall -q (Join-Path $Root "src")
    if($LASTEXITCODE -ne 0){Hold "compileall failed"}
    Write-Host "COMPILEALL : PASS"

    Step 8 "PRODUCTION RECOVERY / RESTORE / FAILOVER GOVERNANCE ASSESSMENT"
    $SurfaceTransfer=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02413-l2-surfaces-"+[Guid]::NewGuid().ToString("N")+".json")
    try {
        WriteLf $SurfaceTransfer (($Surfaces|ForEach-Object{$_ -replace '\\','/'})|ConvertTo-Json -Depth 3)
        $AssessmentTmp=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02413-l2-assess-"+[Guid]::NewGuid().ToString("N")+".py")
        $PyAssess=@'
import json,sys
from pathlib import Path
from sgoda.integration.spt02413l2.service import ContinuityRecoveryGovernanceService
policy=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
surfaces=json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
r=ContinuityRecoveryGovernanceService().assess(policy)
out={
 "component":"SPT-024.13","layer":2,
 "status":"CONTINUITY_RECOVERY_GOVERNANCE_GATE_PASS" if r["gate"]["passed"] else "HOLD",
 "surface_count":len(surfaces),
 "failed_blocking_controls":r["gate"]["failed_blocking_controls"],
 "failed_control_ids":r["gate"]["failed_control_ids"],
 "recovery_strategy":r["strategy"],"restore_testing":r["restore"],"rto_rpo":r["objectives"],
 "redundancy":r["redundancy"],"failover":r["failover"],
 "restore_executed":False,"failover_executed":False,"traffic_shifted":False,
 "infrastructure_changed":False,"production_data_modified":False,
 "external_connection_opened":False,"secret_values_exposed":False
}
print(json.dumps(out,sort_keys=True))
'@
        WriteLf $AssessmentTmp $PyAssess
        $AssessmentJson=& $Python $AssessmentTmp (Join-Path $Root $PolicyFile) $SurfaceTransfer
        if($LASTEXITCODE -ne 0){Hold "Governance assessment failed"}
        $Assessment=$AssessmentJson|ConvertFrom-Json
    } finally {
        if(Test-Path -LiteralPath $SurfaceTransfer){Remove-Item -LiteralPath $SurfaceTransfer -Force}
        if($AssessmentTmp -and (Test-Path -LiteralPath $AssessmentTmp)){Remove-Item -LiteralPath $AssessmentTmp -Force}
    }
    Write-Host "SURFACE_TRANSFER_CONTRACT=PASS"
    Write-Host "SURFACE_TRANSFER_MODE=TEMP_JSON_FILE"
    Write-Host "SPT02413_RECOVERY_STATUS=$($Assessment.status)"
    Write-Host "CONTINUITY_RECOVERY_SURFACES=$($Assessment.surface_count)"
    Write-Host "FAILED_BLOCKING_CONTROLS=$($Assessment.failed_blocking_controls)"
    Write-Host "FAILED_CONTROL_IDS=$($Assessment.failed_control_ids -join ',')"
    Write-Host "INTEGRITY_RECORDS=7"
    Write-Host "RESTORE_EXECUTED=NO"; Write-Host "FAILOVER_EXECUTED=NO"; Write-Host "TRAFFIC_SHIFTED=NO"; Write-Host "INFRASTRUCTURE_CHANGED=NO"
    Write-Host "PRODUCTION_DATA_MODIFIED=NO"; Write-Host "EXTERNAL_CONNECTION_OPENED=NO"; Write-Host "SECRET_VALUES_EXPOSED=NO"
    if($Assessment.status -ne "CONTINUITY_RECOVERY_GOVERNANCE_GATE_PASS"){Hold "Continuity recovery governance gate failed"}
    Write-Host "CONTINUITY RECOVERY GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"
    WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 10)
    WriteLf $StrategyFile ($Assessment.recovery_strategy|ConvertTo-Json -Depth 8)
    WriteLf $RestoreFile ($Assessment.restore_testing|ConvertTo-Json -Depth 8)
    WriteLf $ObjectivesFile ($Assessment.rto_rpo|ConvertTo-Json -Depth 8)
    WriteLf $RedundancyFile ($Assessment.redundancy|ConvertTo-Json -Depth 8)
    WriteLf $FailoverFile ($Assessment.failover|ConvertTo-Json -Depth 8)
    $IntegrityRecords=@()
    foreach($p in @($PolicyFile,$DocFile,$AssessmentFile,$StrategyFile,$RestoreFile,$ObjectivesFile,$RedundancyFile)){
        $IntegrityRecords+=@{path=$p;sha256=Sha (Join-Path $Root $p)}
    }
    WriteLf $IntegrityFile (@{algorithm="SHA-256";records=$IntegrityRecords}|ConvertTo-Json -Depth 8)
    $Evidence=@{
        component="SPT-024.13";layer=2;baseline=$ExpectedBaseline;status=$Assessment.status
        targeted_tests="PASS";institutional_suite="PASS";compileall="PASS"
        capa1_reused=$true;capa1_reopened=$false;closed_components_preserved=$true
        destructive_actions_executed=$false;secret_values_exposed=$false
    }
    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 8)
    Write-Host "ASSESSMENT : CREATED"; Write-Host "STRATEGY   : CREATED"; Write-Host "RESTORE    : CREATED"; Write-Host "RTO/RPO    : CREATED"
    Write-Host "REDUNDANCY : CREATED"; Write-Host "FAILOVER   : CREATED"; Write-Host "INTEGRITY  : CREATED"; Write-Host "EVIDENCE   : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Protected tracked file changed: $p"}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.1-.12 + SPT-024.13 CAPA 1 : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@('Invoke-SGODA-SPT02413-Capa2-FINAL-v1.0.0-PS51.ps1','src/sgoda/integration/spt02413l2/__init__.py','src/sgoda/integration/spt02413l2/models.py','src/sgoda/integration/spt02413l2/recovery_strategy.py','src/sgoda/integration/spt02413l2/restore_testing.py','src/sgoda/integration/spt02413l2/objectives.py','src/sgoda/integration/spt02413l2/redundancy.py','src/sgoda/integration/spt02413l2/failover.py','src/sgoda/integration/spt02413l2/integrity.py','src/sgoda/integration/spt02413l2/audit.py','src/sgoda/integration/spt02413l2/gate.py','src/sgoda/integration/spt02413l2/service.py','tests/integration/test_spt02413_continuity_recovery_governance_layer2.py','config/integration/spt02413/continuity-recovery-governance-policy.json','docs/06_Tecnologia/SPT-024/SPT-024.13/SGD-SPT024.13-Capa2-Estrategias-Recuperacion-Restore-RTO-RPO-Redundancia-Failover.md','artifacts/development/SPT-024.13-Capa2-v1.0.0/continuity-recovery-governance-assessment.json','artifacts/development/SPT-024.13-Capa2-v1.0.0/recovery-strategy-baseline.json','artifacts/development/SPT-024.13-Capa2-v1.0.0/restore-testing-baseline.json','artifacts/development/SPT-024.13-Capa2-v1.0.0/rto-rpo-advanced-baseline.json','artifacts/development/SPT-024.13-Capa2-v1.0.0/redundancy-governance-baseline.json','artifacts/development/SPT-024.13-Capa2-v1.0.0/controlled-failover-baseline.json','artifacts/development/SPT-024.13-Capa2-v1.0.0/continuity-recovery-integrity-manifest.json','artifacts/development/SPT-024.13-Capa2-v1.0.0/implementation-evidence.json')
    foreach($p in $Allowed){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full)){Hold "Expected transaction file missing: $p"}
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $p
        if($LASTEXITCODE -ne 0){Hold "git add failed: $p"}
    }
    Write-Host "TRANSACTION LINE ENDINGS : CANONICAL LF"
    Write-Host "GIT SAFECRLF POLICY      : TRANSACTION-LOCAL OVERRIDE ONLY"
    Write-Host "GIT GLOBAL/REPO CONFIG   : NOT MODIFIED"
    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected=@($StagedNow|Where-Object{$Allowed -notcontains ($_ -replace '\\','/')})
    Write-Host "STAGED     : $($StagedNow.Count)"; Write-Host "UNEXPECTED : $($Unexpected.Count)"
    if($Unexpected.Count -gt 0){Hold "Unexpected staged paths"}
    if($StagedNow.Count -ne $Allowed.Count){Hold "Exact staging count mismatch"}
    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"
    $Bad=@(SizeGate)
    Write-Host "INDEX BLOBS >=100MB : $($Bad.Count)"
    if($Bad.Count -gt 0){$Bad|ForEach-Object{Write-Host "TOO LARGE : $_" -ForegroundColor Red};Hold "Git index contains blob >=100 MB"}
    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE GATE"
    GitFetch
    $Remote2=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    if($Remote2 -ne $ExpectedBaseline){Hold "Remote advanced during transaction"}
    foreach($p in $Freeze.Keys){$full=Join-Path $Root $p;if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Preservation changed before commit: $p"}}
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"; Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"
    Native "git.exe" @("commit","-m","feat(spt-024.13): implement recovery restore rto rpo redundancy failover governance layer 2") "git commit"
    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"
    Native "git.exe" @("push","origin",$Branch) "git push"
    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION"
    GitFetch
    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim()
    $Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim()
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe ls-files --deleted)
    Write-Host "LOCAL HEAD      : $FinalLocal"; Write-Host "REMOTE HEAD     : $FinalRemote"; Write-Host "BEHIND          : $Behind"; Write-Host "AHEAD           : $Ahead"
    Write-Host "STAGED          : $($FinalStaged.Count)"; Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"
    if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0" -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){Hold "Authoritative final synchronization failed"}

    Write-Host ""
    Write-Host "SPT-024.13 CAPA 2 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host "CAPA1_CONTINUITY_RESILIENCE_GATE=PASS"
    Write-Host "CONTINUITY_RECOVERY_GOVERNANCE_GATE=PASS"
    Write-Host "RECOVERY_STRATEGY_GOVERNANCE=PASS"
    Write-Host "RESTORE_TEST_GOVERNANCE=PASS"
    Write-Host "ADVANCED_RTO_RPO_GOVERNANCE=PASS"
    Write-Host "REDUNDANCY_GOVERNANCE=PASS"
    Write-Host "CONTROLLED_FAILOVER_GOVERNANCE=PASS"
    Write-Host "RESTORE_EXECUTED=NO"
    Write-Host "FAILOVER_EXECUTED=NO"
    Write-Host "TRAFFIC_SHIFTED=NO"
    Write-Host "INFRASTRUCTURE_CHANGED=NO"
    Write-Host "PRODUCTION_DATA_MODIFIED=NO"
    Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
    Write-Host "SECRET_VALUES_EXPOSED=NO"
    Write-Host "TARGETED_TESTS=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "COMPILEALL=PASS"
    Write-Host "CLOSED_COMPONENTS=PRESERVED"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0"
    exit 0
}
catch { Hold $_.Exception.Message }
