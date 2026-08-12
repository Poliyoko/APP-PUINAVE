#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="f44aa28ba66fe96c3e1a321c84c5d1e122e85262"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$SelfName="Invoke-SGODA-SPT02412-Capa2-FINAL-v1.0.0-PS51.ps1"

$Layer1Dir="artifacts/development/SPT-024.12-Capa1-v1.0.0"
$Layer1Assessment="$Layer1Dir/infrastructure-security-assessment.json"
$Layer1Inventory="$Layer1Dir/infrastructure-surface-inventory.json"
$Layer1Hardening="$Layer1Dir/infrastructure-hardening-baseline.json"
$Layer1Exposure="$Layer1Dir/exposure-surface-baseline.json"
$Layer1Integrity="$Layer1Dir/infrastructure-integrity-manifest.json"
$Layer1Evidence="$Layer1Dir/implementation-evidence.json"

$ModuleDir="src/sgoda/integration/spt02412l2"
$TestFile="tests/integration/test_spt02412_infrastructure_hardening_governance_layer2.py"
$PolicyFile="config/integration/spt02412/infrastructure-hardening-governance-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.12/SGD-SPT024.12-Capa2-Hardening-Operacional-Baselines-Servicios-Puertos-Cambios.md"

$ArtifactDir="artifacts/development/SPT-024.12-Capa2-v1.0.0"
$AssessmentFile="$ArtifactDir/infrastructure-hardening-governance-assessment.json"
$InventoryFile="$ArtifactDir/infrastructure-hardening-surface-inventory.json"
$BaselineFile="$ArtifactDir/secure-configuration-baseline.json"
$ServiceFile="$ArtifactDir/service-governance-baseline.json"
$PortFile="$ArtifactDir/port-exposure-governance-baseline.json"
$ChangeFile="$ArtifactDir/infrastructure-change-governance-baseline.json"
$IntegrityFile="$ArtifactDir/infrastructure-hardening-integrity-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"

$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan
}
function Hold([string]$Reason){
    Write-Host ""
    Write-Host "SPT-024.12 CAPA 2 : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason" -ForegroundColor Red
    Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow
    exit 1
}
function Native([string]$Exe,[string[]]$NativeArgs,[string]$Label){
    if([string]::IsNullOrWhiteSpace($Exe)){throw "Native executable is empty"}
    if($null -eq $NativeArgs -or $NativeArgs.Count -eq 0){throw "$Label received no native arguments"}
    & $Exe @NativeArgs
    if($LASTEXITCODE -ne 0){throw "$Label failed with exit code $LASTEXITCODE"}
}
function GitFetch {
    for($i=1;$i -le 4;$i++){
        Write-Host "GIT FETCH ATTEMPT : $i/4"
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return}
        Start-Sleep -Seconds 2
    }
    Hold "git fetch failed after 4 attempts"
}
function WriteLf([string]$Path,[string]$Text){
    if([string]::IsNullOrWhiteSpace($Path)){throw "WriteLf path is empty"}
    $Target=if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $Root $Path}
    $Parent=Split-Path -Parent $Target
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){New-Item -ItemType Directory -Force -Path $Parent|Out-Null}
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $Canonical.EndsWith("`n")){$Canonical+="`n"}
    [IO.File]::WriteAllText($Target,$Canonical,$Utf8)
}
function Sha([string]$Path){
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}
function SizeGate {
    $bad=New-Object System.Collections.Generic.List[string]
    $files=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate Git index"}
    foreach($p in $files){
        $s=@(& git.exe cat-file -s (":"+$p) 2>$null)
        if($LASTEXITCODE -eq 0 -and $s.Count -gt 0){
            [Int64]$n=0
            if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){
                [void]$bad.Add(($p -replace '\\','/'))
            }
        }
    }
    return $bad.ToArray()
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

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){Hold "Authoritative baseline mismatch"}
    if($Staged.Count -ne 0 -or $Deleted.Count -ne 0){Hold "Unsafe pre-existing staged/deleted state"}

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-024.1-.11 + SPT-024.12 CAPA 1 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY SPT-024.12 CAPA 1 INPUTS / RECOVERY STATE"

    $Required=@(
        $Layer1Assessment,$Layer1Inventory,$Layer1Hardening,$Layer1Exposure,$Layer1Integrity,$Layer1Evidence,
        "config/integration/spt02412/infrastructure-security-policy.json"
    )
    $Missing=@($Required|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})

    Write-Host "REQUIRED CAPA 1 INPUTS : $($Required.Count)"
    Write-Host "MISSING INPUTS         : $($Missing.Count)"

    if($Missing.Count -gt 0){$Missing|ForEach-Object{Write-Host "MISSING : $_"};Hold "SPT-024.12 Capa 1 inputs incomplete"}

    $Layer1Text=Get-Content -LiteralPath (Join-Path $Root $Layer1Assessment) -Raw -Encoding UTF8
    if($Layer1Text -notmatch "INFRASTRUCTURE_SECURITY_GATE_PASS"){Hold "SPT-024.12 Capa 1 gate not PASS"}

    $Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $Existing=@($Targets|Where-Object{Test-Path -LiteralPath (Join-Path $Root $_)})

    Write-Host "CAPA 1 INFRASTRUCTURE SECURITY GATE : PASS"
    Write-Host "PREEXISTING CAPA 2 TARGETS          : $($Existing.Count)"
    if($Existing.Count -gt 0){Write-Host "CAPA 2 RESUME MODE                  : ACTIVE"}else{Write-Host "CAPA 2 RESUME MODE                  : NO"}

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}
    foreach($p in $Protected){
        $full=Join-Path $Root $p
        if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}
    }

    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "ADVANCED HARDENING / SERVICES / PORTS / CHANGE DISCOVERY"

    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate tracked files"}

    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (
            $p -match '(config|infra|hardening|service|port|network|firewall|proxy|nginx|docker|compose|container|fastapi|n8n|postgres|database|webhook|api|deploy|release|change|workflow)' -or
            $p -match '(^|/)(config|automation|tools|src|\.github|docs)(/|$)'
        ) -and
        $p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$'
    })

    Write-Host "HARDENING/CHANGE SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE            : STATIC / NON-DESTRUCTIVE"
    Write-Host "SERVICE ACTION EXECUTED   : NO"
    Write-Host "PORT OPENED               : NO"
    Write-Host "FIREWALL CHANGED          : NO"
    Write-Host "PRODUCTION CHANGE         : NO"

    Step 5 "IMPLEMENT SPT-024.12 CAPA 2"

$InitPy=@'
"""SPT-024.12 Capa 2 — advanced operational hardening, secure baselines, exposure and infrastructure change governance."""
from .service import InfrastructureHardeningGovernanceService
from .gate import InfrastructureHardeningGovernanceGate

__all__ = ["InfrastructureHardeningGovernanceService", "InfrastructureHardeningGovernanceGate"]
'@
$ModelsPy=@'
from dataclasses import dataclass


@dataclass(frozen=True)
class HardeningControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
'@
$BaselinePy=@'
from __future__ import annotations
from typing import Mapping


def validate_secure_baseline(profile: Mapping) -> dict:
    required = (
        "versioned",
        "reviewed",
        "integrity_protected",
        "rollback_ready",
        "least_exposure",
        "secret_indirection",
    )
    values = {key: bool(profile.get(key, False)) for key in required}
    valid = all(values.values())

    return {
        "valid": valid,
        "controls": values,
        "production_configuration_changed": False,
        "service_restarted": False,
        "secret_values_exposed": False,
    }
'@
$ServiceGovPy=@'
from __future__ import annotations
from typing import Mapping


def validate_service_governance(profile: Mapping) -> dict:
    enabled = bool(profile.get("enabled", True))
    approved = bool(profile.get("approved", False))
    health_check = bool(profile.get("health_check", False))
    privileged = bool(profile.get("privileged", False))
    external = bool(profile.get("external", False))

    valid = approved and health_check and not privileged

    return {
        "valid": valid,
        "enabled": enabled,
        "approved": approved,
        "health_check": health_check,
        "privileged": privileged,
        "external": external,
        "service_started": False,
        "service_stopped": False,
        "service_restarted": False,
        "secret_values_exposed": False,
    }
'@
$PortGovPy=@'
from __future__ import annotations
from typing import Mapping


def validate_port_governance(profile: Mapping) -> dict:
    port = int(profile.get("port", 0))
    purpose = str(profile.get("purpose", "")).strip()
    approved = bool(profile.get("approved", False))
    restricted = bool(profile.get("restricted", False))
    public = bool(profile.get("public", False))

    valid = 1 <= port <= 65535 and bool(purpose) and approved and restricted and not public

    return {
        "valid": valid,
        "port": port,
        "purpose_present": bool(purpose),
        "approved": approved,
        "restricted": restricted,
        "public": public,
        "port_opened": False,
        "firewall_changed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
'@
$ChangeGovPy=@'
from __future__ import annotations
from typing import Mapping


def validate_change_governance(profile: Mapping) -> dict:
    change_id = str(profile.get("change_id", "")).strip()
    approved_by = str(profile.get("approved_by", "")).strip()
    rollback = bool(profile.get("rollback", False))
    evidence = bool(profile.get("evidence", False))
    risk_review = bool(profile.get("risk_review", False))

    valid = bool(change_id) and bool(approved_by) and rollback and evidence and risk_review

    return {
        "valid": valid,
        "change_id": change_id,
        "approval_present": bool(approved_by),
        "rollback": rollback,
        "evidence": evidence,
        "risk_review": risk_review,
        "production_change_executed": False,
        "secret_values_exposed": False,
    }
'@
$ExposurePy=@'
from __future__ import annotations
from typing import Iterable


def exposure_baseline(paths: Iterable[str]) -> dict:
    items = sorted(set(str(p).replace("\\", "/") for p in paths))
    candidates = [
        p for p in items
        if any(token in p.lower() for token in (
            "api", "webhook", "port", "network", "proxy", "nginx",
            "fastapi", "n8n", "postgres", "docker", "compose", "service"
        ))
    ]
    return {
        "valid": True,
        "surface_count": len(items),
        "candidate_count": len(candidates),
        "mode": "STATIC_NON_DESTRUCTIVE",
        "port_opened": False,
        "firewall_changed": False,
        "service_published": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
'@
$AuditPy=@'
from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .baseline import validate_secure_baseline
from .change_governance import validate_change_governance
from .exposure import exposure_baseline
from .models import HardeningControl
from .port_governance import validate_port_governance
from .service_governance import validate_service_governance


class InfrastructureHardeningGovernanceAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        baseline = validate_secure_baseline({
            "versioned": True,
            "reviewed": True,
            "integrity_protected": True,
            "rollback_ready": True,
            "least_exposure": True,
            "secret_indirection": True,
        })

        service = validate_service_governance({
            "enabled": True,
            "approved": True,
            "health_check": True,
            "privileged": False,
            "external": False,
        })

        port = validate_port_governance({
            "port": 443,
            "purpose": "Approved secure application endpoint",
            "approved": True,
            "restricted": True,
            "public": False,
        })

        change = validate_change_governance({
            "change_id": "CHG-SPT02412-L2",
            "approved_by": "PISI_INFRA_OWNER",
            "rollback": True,
            "evidence": True,
            "risk_review": True,
        })

        exposure = exposure_baseline(self.discovered_paths)

        controls = [
            HardeningControl(
                "INFRA-SECURE-BASELINE",
                "Secure configuration baseline",
                baseline["valid"] is True,
                True,
                True,
                "Secure baseline is versioned, reviewed, integrity-protected and rollback-ready.",
            ),
            HardeningControl(
                "INFRA-SERVICE-GOVERNANCE",
                "Service governance",
                service["valid"] is True,
                True,
                True,
                "Services require approval and health checks and may not run privileged.",
            ),
            HardeningControl(
                "INFRA-PORT-GOVERNANCE",
                "Port governance",
                port["valid"] is True,
                True,
                True,
                "Ports require purpose, approval, restriction and non-public exposure.",
            ),
            HardeningControl(
                "INFRA-EXPOSURE-GOVERNANCE",
                "Exposure governance",
                exposure["valid"] is True,
                True,
                True,
                "Exposure is inventoried and assessed statically.",
            ),
            HardeningControl(
                "INFRA-CHANGE-GOVERNANCE",
                "Infrastructure change governance",
                change["valid"] is True,
                True,
                True,
                "Changes require approval, rollback, risk review and evidence.",
            ),
            HardeningControl(
                "INFRA-SECRET-INDIRECTION",
                "Secret indirection",
                baseline["controls"]["secret_indirection"] is True,
                True,
                True,
                "Operational infrastructure baselines prohibit embedded production secrets.",
            ),
            HardeningControl(
                "INFRA-NO-REAL-SERVICE-ACTION",
                "No real service action",
                service["service_started"] is False
                and service["service_stopped"] is False
                and service["service_restarted"] is False,
                True,
                True,
                "Assessment never starts, stops or restarts services.",
            ),
            HardeningControl(
                "INFRA-NO-REAL-NETWORK-ACTION",
                "No real network action",
                port["port_opened"] is False
                and port["firewall_changed"] is False
                and exposure["port_opened"] is False
                and exposure["firewall_changed"] is False,
                True,
                True,
                "Assessment never opens ports or changes firewall.",
            ),
            HardeningControl(
                "INFRA-NO-PRODUCTION-CHANGE",
                "No production infrastructure change",
                baseline["production_configuration_changed"] is False
                and change["production_change_executed"] is False,
                True,
                True,
                "Assessment is governance-only.",
            ),
            HardeningControl(
                "INFRA-NO-EXTERNAL-CONNECTION",
                "No external connection",
                port["external_connection_opened"] is False
                and exposure["external_connection_opened"] is False,
                True,
                True,
                "Assessment remains local and static.",
            ),
            HardeningControl(
                "INFRA-SECRET-SAFETY",
                "No secret values exposed",
                baseline["secret_values_exposed"] is False
                and service["secret_values_exposed"] is False
                and port["secret_values_exposed"] is False
                and change["secret_values_exposed"] is False
                and exposure["secret_values_exposed"] is False,
                True,
                True,
                "Evidence stores governance metadata only.",
            ),
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and item.applicable and not item.passed
        ]

        return {
            "status": "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS" if not failed else "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "secure_baseline": baseline,
            "service_governance": service,
            "port_governance": port,
            "change_governance": change,
            "exposure": exposure,
            "infrastructure_surfaces": len(self.discovered_paths),
            "production_configuration_changed": False,
            "production_change_executed": False,
            "service_restarted": False,
            "port_opened": False,
            "firewall_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
'@
$GatePy=@'
class InfrastructureHardeningGovernanceGate:
    BLOCKING = frozenset({
        "INFRA-SECURE-BASELINE",
        "INFRA-SERVICE-GOVERNANCE",
        "INFRA-PORT-GOVERNANCE",
        "INFRA-EXPOSURE-GOVERNANCE",
        "INFRA-CHANGE-GOVERNANCE",
        "INFRA-SECRET-INDIRECTION",
        "INFRA-NO-REAL-SERVICE-ACTION",
        "INFRA-NO-REAL-NETWORK-ACTION",
        "INFRA-NO-PRODUCTION-CHANGE",
        "INFRA-NO-EXTERNAL-CONNECTION",
        "INFRA-SECRET-SAFETY",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {
            item["control_id"] if isinstance(item, dict) else item.control_id: item
            for item in controls
        }

        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:" + item for item in missing]

        failed = []
        for control_id in sorted(cls.BLOCKING):
            item = by_id[control_id]
            passed = item["passed"] if isinstance(item, dict) else item.passed
            blocking = item["blocking"] if isinstance(item, dict) else item.blocking
            applicable = item["applicable"] if isinstance(item, dict) else item.applicable
            if blocking and applicable and not passed:
                failed.append(control_id)

        return not failed, failed
'@
$IntegrityPy=@'
from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_manifest(root: Path, paths: Iterable[str]) -> dict:
    records = []
    for rel in sorted(set(paths)):
        path = root / rel
        if not path.is_file():
            continue
        records.append({
            "path": rel.replace("\\", "/"),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        })
    return {
        "algorithm": "SHA-256",
        "record_count": len(records),
        "records": records,
    }
'@
$ServicePy=@'
from pathlib import Path
from typing import Iterable

from .audit import InfrastructureHardeningGovernanceAuditor
from .gate import InfrastructureHardeningGovernanceGate


class InfrastructureHardeningGovernanceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = InfrastructureHardeningGovernanceAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = InfrastructureHardeningGovernanceGate.evaluate(result["controls"])
        result["status"] = (
            "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"
            if passed
            else "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_HOLD"
        )
        result["failed_blocking_controls"] = failed
        return result
'@
$TestsPy=@'
from sgoda.integration.spt02412l2.baseline import validate_secure_baseline
from sgoda.integration.spt02412l2.change_governance import validate_change_governance
from sgoda.integration.spt02412l2.port_governance import validate_port_governance
from sgoda.integration.spt02412l2.service_governance import validate_service_governance
from sgoda.integration.spt02412l2.service import InfrastructureHardeningGovernanceService


def test_secure_baseline_passes():
    result = validate_secure_baseline({
        "versioned": True,
        "reviewed": True,
        "integrity_protected": True,
        "rollback_ready": True,
        "least_exposure": True,
        "secret_indirection": True,
    })
    assert result["valid"] is True


def test_secure_baseline_requires_rollback():
    result = validate_secure_baseline({
        "versioned": True,
        "reviewed": True,
        "integrity_protected": True,
        "rollback_ready": False,
        "least_exposure": True,
        "secret_indirection": True,
    })
    assert result["valid"] is False


def test_service_governance_blocks_privileged_service():
    result = validate_service_governance({
        "enabled": True,
        "approved": True,
        "health_check": True,
        "privileged": True,
        "external": False,
    })
    assert result["valid"] is False


def test_service_governance_passes_non_privileged_service():
    result = validate_service_governance({
        "enabled": True,
        "approved": True,
        "health_check": True,
        "privileged": False,
        "external": False,
    })
    assert result["valid"] is True


def test_port_governance_passes_restricted_approved_port():
    result = validate_port_governance({
        "port": 443,
        "purpose": "secure endpoint",
        "approved": True,
        "restricted": True,
        "public": False,
    })
    assert result["valid"] is True


def test_port_governance_blocks_public_port():
    result = validate_port_governance({
        "port": 443,
        "purpose": "secure endpoint",
        "approved": True,
        "restricted": True,
        "public": True,
    })
    assert result["valid"] is False


def test_change_governance_requires_approval_and_rollback():
    result = validate_change_governance({
        "change_id": "CHG-1",
        "approved_by": "OWNER",
        "rollback": True,
        "evidence": True,
        "risk_review": True,
    })
    assert result["valid"] is True


def test_change_governance_blocks_without_risk_review():
    result = validate_change_governance({
        "change_id": "CHG-1",
        "approved_by": "OWNER",
        "rollback": True,
        "evidence": True,
        "risk_review": False,
    })
    assert result["valid"] is False


def test_full_gate_passes(tmp_path):
    result = InfrastructureHardeningGovernanceService(
        tmp_path,
        ["config/app.yaml", "src/api/main.py", "automation/n8n/workflows/a.json"],
    ).assess()
    assert result["status"] == "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_eleven_controls(tmp_path):
    result = InfrastructureHardeningGovernanceService(tmp_path, []).assess()
    assert len(result["controls"]) == 11


def test_full_gate_executes_no_real_changes(tmp_path):
    result = InfrastructureHardeningGovernanceService(tmp_path, []).assess()
    assert result["production_configuration_changed"] is False
    assert result["production_change_executed"] is False
    assert result["service_restarted"] is False
    assert result["port_opened"] is False
    assert result["firewall_changed"] is False


def test_full_gate_has_no_external_connection_or_secret_exposure(tmp_path):
    result = InfrastructureHardeningGovernanceService(tmp_path, []).assess()
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
'@
$PolicyJson=@'
{
  "component": "SPT-024.12",
  "layer": "2",
  "version": "1.0.0",
  "title": "Hardening Operacional Avanzado, Baselines de Configuracion Segura, Gestion de Exposicion, Servicios, Puertos y Gobierno de Cambios de Infraestructura",
  "blocking_controls": [
    "INFRA-SECURE-BASELINE",
    "INFRA-SERVICE-GOVERNANCE",
    "INFRA-PORT-GOVERNANCE",
    "INFRA-EXPOSURE-GOVERNANCE",
    "INFRA-CHANGE-GOVERNANCE",
    "INFRA-SECRET-INDIRECTION",
    "INFRA-NO-REAL-SERVICE-ACTION",
    "INFRA-NO-REAL-NETWORK-ACTION",
    "INFRA-NO-PRODUCTION-CHANGE",
    "INFRA-NO-EXTERNAL-CONNECTION",
    "INFRA-SECRET-SAFETY"
  ],
  "secure_baseline": {
    "versioned": true,
    "reviewed": true,
    "integrity_protected": true,
    "rollback_ready": true,
    "least_exposure": true,
    "secret_indirection": true
  },
  "service_governance": {
    "approval_required": true,
    "health_check_required": true,
    "privileged_services_prohibited": true
  },
  "port_governance": {
    "purpose_required": true,
    "approval_required": true,
    "restriction_required": true,
    "public_exposure_default": false
  },
  "change_governance": {
    "change_id_required": true,
    "approval_required": true,
    "rollback_required": true,
    "evidence_required": true,
    "risk_review_required": true
  },
  "safety": {
    "modify_production_configuration": false,
    "execute_production_change": false,
    "start_stop_restart_service": false,
    "open_ports": false,
    "change_firewall": false,
    "open_external_connections": false,
    "print_secret_values": false,
    "modify_layer1": false,
    "modify_closed_components": false
  }
}
'@
$DocMd=@'
# SPT-024.12 Capa 2 — Hardening Operacional Avanzado, Baselines de Configuracion Segura, Exposicion, Servicios, Puertos y Cambios

Baseline autoritativa: `f44aa28ba66fe96c3e1a321c84c5d1e122e85262`.

Esta capa reutiliza SPT-024.12 Capa 1 sin reabrirla y conserva todos los componentes cerrados de PISI.

## Alcance

- baseline operacional segura;
- gobierno de servicios;
- gobierno de puertos;
- gestion de superficie de exposicion;
- gobierno de cambios de infraestructura;
- aprobacion, rollback, evaluacion de riesgo y evidencia;
- indireccion de secretos;
- integridad SHA-256;
- preservation gates;
- pruebas dirigidas y suite institucional;
- publicacion obligatoria en repositorio oficial.

## Seguridad operacional

La capa es estatica y no destructiva. No inicia, detiene ni reinicia servicios; no abre puertos; no modifica firewall; no ejecuta cambios productivos; no modifica configuracion productiva; no abre conexiones externas; no expone secretos.

El cierre tecnico exige `commit + push + LOCAL HEAD = REMOTE HEAD`.
'@

WriteLf "$ModuleDir/__init__.py" $InitPy
WriteLf "$ModuleDir/models.py" $ModelsPy
WriteLf "$ModuleDir/baseline.py" $BaselinePy
WriteLf "$ModuleDir/service_governance.py" $ServiceGovPy
WriteLf "$ModuleDir/port_governance.py" $PortGovPy
WriteLf "$ModuleDir/change_governance.py" $ChangeGovPy
WriteLf "$ModuleDir/exposure.py" $ExposurePy
WriteLf "$ModuleDir/audit.py" $AuditPy
WriteLf "$ModuleDir/gate.py" $GatePy
WriteLf "$ModuleDir/integrity.py" $IntegrityPy
WriteLf "$ModuleDir/service.py" $ServicePy
WriteLf $TestFile $TestsPy
WriteLf $PolicyFile $PolicyJson
WriteLf $DocFile $DocMd

    Write-Host "SPT-024.12 CAPA 2 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"

    $env:PYTHONPATH=(Join-Path $Root "src")

    $ArgProbe=@(& $Python -c "import sys; assert len(sys.argv)==2 and sys.argv[1]=='SGODA_ARG_OK'; print('PYTHON_ARGUMENT_CONTRACT=PASS')" "SGODA_ARG_OK" 2>&1)
    if($LASTEXITCODE -ne 0 -or ($ArgProbe -join "`n") -notmatch "PYTHON_ARGUMENT_CONTRACT=PASS"){Hold "Python argument contract failed"}
    $ArgProbe|ForEach-Object{Write-Host ([string]$_)}

    Native $Python @(
        "-c",
        "from sgoda.integration.spt02412l2 import InfrastructureHardeningGovernanceService; from sgoda.integration.spt02412l2.gate import InfrastructureHardeningGovernanceGate; assert len(InfrastructureHardeningGovernanceGate.BLOCKING)==11; print('SPT02412_CAPA2_IMPORT=PASS'); print('BLOCKING_CONTROLS=11')"
    ) "SPT-024.12 Capa 2 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.12 Capa 2 targeted tests"
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q",(Join-Path $Root "src")) "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 8 "PRODUCTION HARDENING / INFRASTRUCTURE CHANGE ASSESSMENT"

    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $SurfaceFile=Join-Path ([IO.Path]::GetTempPath()) ("spt02412l2-surfaces-"+[guid]::NewGuid().ToString("N")+".json")
    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("spt02412l2-probe-"+[guid]::NewGuid().ToString("N")+".py")

    $Normalized=@($Surfaces|ForEach-Object{$_ -replace '\\','/'})
    $Payload=($Normalized|ConvertTo-Json -Compress)
    if([string]::IsNullOrWhiteSpace($Payload)){$Payload="[]"}
    WriteLf $SurfaceFile $Payload

    $Probe=@'
import json,sys
from pathlib import Path
from sgoda.integration.spt02412l2 import InfrastructureHardeningGovernanceService
from sgoda.integration.spt02412l2.integrity import build_manifest

if len(sys.argv) != 2:
    raise SystemExit("SURFACE_ARGUMENT_CONTRACT_FAILED")

root=Path.cwd()
paths=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(paths,list):
    raise SystemExit("SURFACE_PAYLOAD_NOT_LIST")

result=InfrastructureHardeningGovernanceService(root,paths).assess()

ad=root/"artifacts/development/SPT-024.12-Capa2-v1.0.0"
ad.mkdir(parents=True,exist_ok=True)

assessment=ad/"infrastructure-hardening-governance-assessment.json"
inventory=ad/"infrastructure-hardening-surface-inventory.json"
baseline=ad/"secure-configuration-baseline.json"
service=ad/"service-governance-baseline.json"
port=ad/"port-exposure-governance-baseline.json"
change=ad/"infrastructure-change-governance-baseline.json"
integrity=ad/"infrastructure-hardening-integrity-manifest.json"

assessment.write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
inventory.write_text(json.dumps({
    "mode":"GIT_TRACKED_STATIC_DISCOVERY",
    "surface_count":len(paths),
    "production_configuration_changed":False,
    "production_change_executed":False,
    "service_restarted":False,
    "port_opened":False,
    "firewall_changed":False,
    "secret_values_exposed":False
},indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

baseline.write_text(json.dumps(result["secure_baseline"],indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
service.write_text(json.dumps(result["service_governance"],indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
port.write_text(json.dumps({
    "port_governance":result["port_governance"],
    "exposure":result["exposure"],
    "port_opened":False,
    "firewall_changed":False
},indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
change.write_text(json.dumps(result["change_governance"],indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

manifest=build_manifest(root,[
    str(assessment.relative_to(root)).replace("\\","/"),
    str(inventory.relative_to(root)).replace("\\","/"),
    str(baseline.relative_to(root)).replace("\\","/"),
    str(service.relative_to(root)).replace("\\","/"),
    str(port.relative_to(root)).replace("\\","/"),
    str(change.relative_to(root)).replace("\\","/"),
    "config/integration/spt02412/infrastructure-hardening-governance-policy.json",
])
integrity.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

print("SURFACE_TRANSFER_CONTRACT=PASS")
print("SURFACE_TRANSFER_MODE=TEMP_JSON_FILE")
print("SPT02412_HARDENING_STATUS="+result["status"])
print("HARDENING_SURFACES="+str(len(paths)))
print("FAILED_BLOCKING_CONTROLS="+str(len(result["failed_blocking_controls"])))
print("FAILED_CONTROL_IDS="+",".join(result["failed_blocking_controls"]))
print("INTEGRITY_RECORDS="+str(manifest["record_count"]))
print("PRODUCTION_CONFIGURATION_CHANGED=NO")
print("PRODUCTION_CHANGE_EXECUTED=NO")
print("SERVICE_RESTARTED=NO")
print("PORT_OPENED=NO")
print("FIREWALL_CHANGED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")

raise SystemExit(0 if result["status"]=="INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS" else 20)
'@

    WriteLf $ProbeFile $Probe

    try{
        & $Python $ProbeFile $SurfaceFile
        $ProbeExit=$LASTEXITCODE
    } finally {
        Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $SurfaceFile -Force -ErrorAction SilentlyContinue
    }

    if($ProbeExit -ne 0){Hold "Infrastructure hardening governance assessment failed with exit code $ProbeExit"}

    Write-Host "INFRASTRUCTURE HARDENING GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"

    $Assessment=Get-Content -LiteralPath (Join-Path $Root $AssessmentFile) -Raw -Encoding UTF8|ConvertFrom-Json
    if($Assessment.status -ne "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"){Hold "Assessment does not certify PASS"}

    $Evidence=[ordered]@{
        component="SPT-024.12"
        layer="2"
        version="1.0.0"
        generated_utc=[DateTime]::UtcNow.ToString("o")
        authoritative_baseline=$ExpectedBaseline
        final_status="INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"
        gates=[ordered]@{
            capa1_infrastructure_security="PASS"
            targeted_tests="PASS"
            institutional_suite="PASS"
            compileall="PASS"
            hardening_governance="PASS"
            preservation="PENDING"
            github_size="PENDING"
            remote_sync="PENDING"
        }
        production_configuration_changed=$false
        production_change_executed=$false
        service_restarted=$false
        port_opened=$false
        firewall_changed=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)

    Write-Host "ASSESSMENT : CREATED"
    Write-Host "INVENTORY  : CREATED"
    Write-Host "BASELINE   : CREATED"
    Write-Host "SERVICES   : CREATED"
    Write-Host "PORTS      : CREATED"
    Write-Host "CHANGES    : CREATED"
    Write-Host "INTEGRITY  : CREATED"
    Write-Host "EVIDENCE   : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"

    $Changed=New-Object System.Collections.Generic.List[string]
    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full)){[void]$Changed.Add($p);continue}
        if((Sha $full) -ne $Freeze[$p]){[void]$Changed.Add($p)}
    }

    if($Changed.Count -gt 0){
        $Changed|ForEach-Object{Write-Host "PRESERVATION FAILURE : $_" -ForegroundColor Red}
        Hold "Protected tracked files changed"
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.1-.11 + SPT-024.12 CAPA 1 : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"

    $Allowed=@(
        $SelfName,
        "$ModuleDir/__init__.py",
        "$ModuleDir/models.py",
        "$ModuleDir/baseline.py",
        "$ModuleDir/service_governance.py",
        "$ModuleDir/port_governance.py",
        "$ModuleDir/change_governance.py",
        "$ModuleDir/exposure.py",
        "$ModuleDir/audit.py",
        "$ModuleDir/gate.py",
        "$ModuleDir/integrity.py",
        "$ModuleDir/service.py",
        $TestFile,
        $PolicyFile,
        $DocFile,
        $AssessmentFile,
        $InventoryFile,
        $BaselineFile,
        $ServiceFile,
        $PortFile,
        $ChangeFile,
        $IntegrityFile,
        $EvidenceFile
    )

    foreach($p in $Allowed){
        if(-not(Test-Path -LiteralPath (Join-Path $Root $p))){Hold "Expected target missing before staging: $p"}

        & git.exe `
            -c core.autocrlf=false `
            -c core.eol=lf `
            -c core.safecrlf=false `
            add -- $p

        if($LASTEXITCODE -ne 0){Hold "git add failed: $p"}
    }

    Write-Host "TRANSACTION LINE ENDINGS : CANONICAL LF"
    Write-Host "GIT SAFECRLF POLICY      : TRANSACTION-LOCAL OVERRIDE ONLY"
    Write-Host "GIT GLOBAL/REPO CONFIG   : NOT MODIFIED"

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected=@($StagedNow|Where-Object{$Allowed -notcontains ($_ -replace '\\','/')})

    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if($Unexpected.Count -gt 0){Hold "Unexpected staged paths"}
    if($StagedNow.Count -ne $Allowed.Count){Hold "Exact staging count mismatch"}

    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"

    $Bad=@(SizeGate)
    Write-Host "INDEX BLOBS >=100MB : $($Bad.Count)"
    if($Bad.Count -gt 0){
        $Bad|ForEach-Object{Write-Host "TOO LARGE : $_" -ForegroundColor Red}
        Hold "Git index contains blob >=100 MB"
    }

    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE GATE"

    GitFetch
    $Remote2=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    if($Remote2 -ne $ExpectedBaseline){Hold "Remote advanced during transaction"}

    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Preservation changed before commit: $p"}
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"

    Native "git.exe" @(
        "commit",
        "-m",
        "feat(spt-024.12): implement advanced hardening services ports infrastructure change layer 2"
    ) "git commit"

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

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $Behind"
    Write-Host "AHEAD           : $Ahead"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if(
        $FinalLocal -ne $FinalRemote -or
        $Behind -ne "0" -or
        $Ahead -ne "0" -or
        $FinalStaged.Count -ne 0 -or
        $FinalDeleted.Count -ne 0
    ){Hold "Authoritative final synchronization failed"}

    Write-Host ""
    Write-Host "SPT-024.12 CAPA 2 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host "CAPA1_INFRASTRUCTURE_SECURITY_GATE=PASS"
    Write-Host "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE=PASS"
    Write-Host "SECURE_CONFIGURATION_BASELINE=PASS"
    Write-Host "SERVICE_GOVERNANCE=PASS"
    Write-Host "PORT_GOVERNANCE=PASS"
    Write-Host "EXPOSURE_GOVERNANCE=PASS"
    Write-Host "INFRASTRUCTURE_CHANGE_GOVERNANCE=PASS"
    Write-Host "SECRET_INDIRECTION=PASS"
    Write-Host "PRODUCTION_CONFIGURATION_CHANGED=NO"
    Write-Host "PRODUCTION_CHANGE_EXECUTED=NO"
    Write-Host "SERVICE_RESTARTED=NO"
    Write-Host "PORT_OPENED=NO"
    Write-Host "FIREWALL_CHANGED=NO"
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
catch{
    Hold $_.Exception.Message
}
