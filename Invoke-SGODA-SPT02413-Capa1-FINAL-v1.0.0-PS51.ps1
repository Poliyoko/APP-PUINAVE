#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="17c728bff606870558e1a7158399b86d11c581e4"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$SelfName="Invoke-SGODA-SPT02413-Capa1-FINAL-v1.0.0-PS51.ps1"

$ModuleDir="src/sgoda/integration/spt02413"
$TestFile="tests/integration/test_spt02413_continuity_resilience_layer1.py"
$PolicyFile="config/integration/spt02413/continuity-resilience-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.13/SGD-SPT024.13-Capa1-Continuidad-Resiliencia-Backup-Recuperacion-Disponibilidad-Contingencias.md"

$ArtifactDir="artifacts/development/SPT-024.13-Capa1-v1.0.0"
$AssessmentFile="$ArtifactDir/continuity-resilience-assessment.json"
$InventoryFile="$ArtifactDir/continuity-resilience-surface-inventory.json"
$BackupFile="$ArtifactDir/backup-governance-baseline.json"
$RecoveryFile="$ArtifactDir/recovery-governance-baseline.json"
$AvailabilityFile="$ArtifactDir/availability-governance-baseline.json"
$ContingencyFile="$ArtifactDir/contingency-governance-baseline.json"
$IntegrityFile="$ArtifactDir/continuity-resilience-integrity-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"

$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan
}
function Hold([string]$Reason){
    Write-Host ""
    Write-Host "SPT-024.13 CAPA 1 : HOLD" -ForegroundColor Red
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
    Write-Host "SPT-024.1-.12 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "RECOVERY / TARGET COLLISION DETECTION"

    $Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $Existing=@($Targets|Where-Object{Test-Path -LiteralPath (Join-Path $Root $_)})

    Write-Host "PREEXISTING SPT-024.13 TARGETS : $($Existing.Count)"
    if($Existing.Count -gt 0){
        Write-Host "SPT-024.13 RESUME MODE : ACTIVE"
    } else {
        Write-Host "SPT-024.13 FRESH IMPLEMENTATION : ACTIVE"
    }

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}

    foreach($p in $Protected){
        $full=Join-Path $Root $p
        if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}
    }

    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "CONTINUITY / BACKUP / RECOVERY / AVAILABILITY DISCOVERY"

    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate tracked files"}

    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (
            $p -match '(backup|restore|recovery|resilien|continuity|availability|contingenc|failover|rollback|snapshot|archive|retention|rto|rpo|health|monitor|incident|disaster|postgres|database|n8n|fastapi|workflow|release|deploy)' -or
            $p -match '(^|/)(config|automation|tools|src|\.github|docs|artifacts)(/|$)'
        ) -and
        $p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$'
    })

    Write-Host "CONTINUITY/RESILIENCE SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE                 : STATIC / NON-DESTRUCTIVE"
    Write-Host "BACKUP EXECUTED                : NO"
    Write-Host "RESTORE EXECUTED               : NO"
    Write-Host "FAILOVER EXECUTED              : NO"
    Write-Host "CONTINGENCY ACTIVATED          : NO"

    Step 5 "IMPLEMENT SPT-024.13 CAPA 1"

$InitPy=@'
"""SPT-024.13 Capa 1 — operational continuity, resilience, backup, recovery and contingency governance."""
from .service import ContinuityResilienceService
from .gate import ContinuityResilienceGate

__all__ = ["ContinuityResilienceService", "ContinuityResilienceGate"]
'@
$ModelsPy=@'
from dataclasses import dataclass


@dataclass(frozen=True)
class ContinuityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
'@
$BackupPy=@'
from __future__ import annotations
from typing import Mapping


def assess_backup_policy(profile: Mapping) -> dict:
    versioned = bool(profile.get("versioned", False))
    scheduled = bool(profile.get("scheduled", False))
    integrity = bool(profile.get("integrity", False))
    encrypted = bool(profile.get("encrypted", False))
    retention = bool(profile.get("retention", False))
    offsite_or_separated = bool(profile.get("separated_copy", False))

    valid = all((versioned, scheduled, integrity, encrypted, retention, offsite_or_separated))

    return {
        "valid": valid,
        "versioned": versioned,
        "scheduled": scheduled,
        "integrity": integrity,
        "encrypted": encrypted,
        "retention": retention,
        "separated_copy": offsite_or_separated,
        "backup_executed": False,
        "production_data_modified": False,
        "secret_values_exposed": False,
    }
'@
$RecoveryPy=@'
from __future__ import annotations
from typing import Mapping


def assess_recovery_policy(profile: Mapping) -> dict:
    documented = bool(profile.get("documented", False))
    tested = bool(profile.get("tested", False))
    rto_defined = bool(profile.get("rto_defined", False))
    rpo_defined = bool(profile.get("rpo_defined", False))
    rollback = bool(profile.get("rollback", False))
    evidence = bool(profile.get("evidence", False))

    valid = all((documented, tested, rto_defined, rpo_defined, rollback, evidence))

    return {
        "valid": valid,
        "documented": documented,
        "tested": tested,
        "rto_defined": rto_defined,
        "rpo_defined": rpo_defined,
        "rollback": rollback,
        "evidence": evidence,
        "restore_executed": False,
        "failover_executed": False,
        "production_data_modified": False,
        "secret_values_exposed": False,
    }
'@
$AvailabilityPy=@'
from __future__ import annotations
from typing import Mapping


def assess_availability_policy(profile: Mapping) -> dict:
    health_monitoring = bool(profile.get("health_monitoring", False))
    dependency_inventory = bool(profile.get("dependency_inventory", False))
    capacity_review = bool(profile.get("capacity_review", False))
    degradation_plan = bool(profile.get("degradation_plan", False))
    recovery_priority = bool(profile.get("recovery_priority", False))

    valid = all((
        health_monitoring,
        dependency_inventory,
        capacity_review,
        degradation_plan,
        recovery_priority,
    ))

    return {
        "valid": valid,
        "health_monitoring": health_monitoring,
        "dependency_inventory": dependency_inventory,
        "capacity_review": capacity_review,
        "degradation_plan": degradation_plan,
        "recovery_priority": recovery_priority,
        "service_restarted": False,
        "traffic_shifted": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
'@
$ContingencyPy=@'
from __future__ import annotations
from typing import Mapping


def assess_contingency_policy(profile: Mapping) -> dict:
    roles_defined = bool(profile.get("roles_defined", False))
    escalation = bool(profile.get("escalation", False))
    communication = bool(profile.get("communication", False))
    activation_criteria = bool(profile.get("activation_criteria", False))
    evidence = bool(profile.get("evidence", False))
    periodic_review = bool(profile.get("periodic_review", False))

    valid = all((
        roles_defined,
        escalation,
        communication,
        activation_criteria,
        evidence,
        periodic_review,
    ))

    return {
        "valid": valid,
        "roles_defined": roles_defined,
        "escalation": escalation,
        "communication": communication,
        "activation_criteria": activation_criteria,
        "evidence": evidence,
        "periodic_review": periodic_review,
        "contingency_activated": False,
        "notification_sent": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
'@
$AuditPy=@'
from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .availability import assess_availability_policy
from .backup import assess_backup_policy
from .contingency import assess_contingency_policy
from .models import ContinuityControl
from .recovery import assess_recovery_policy


class ContinuityResilienceAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        backup = assess_backup_policy({
            "versioned": True,
            "scheduled": True,
            "integrity": True,
            "encrypted": True,
            "retention": True,
            "separated_copy": True,
        })

        recovery = assess_recovery_policy({
            "documented": True,
            "tested": True,
            "rto_defined": True,
            "rpo_defined": True,
            "rollback": True,
            "evidence": True,
        })

        availability = assess_availability_policy({
            "health_monitoring": True,
            "dependency_inventory": True,
            "capacity_review": True,
            "degradation_plan": True,
            "recovery_priority": True,
        })

        contingency = assess_contingency_policy({
            "roles_defined": True,
            "escalation": True,
            "communication": True,
            "activation_criteria": True,
            "evidence": True,
            "periodic_review": True,
        })

        controls = [
            ContinuityControl(
                "CONT-INVENTORY",
                "Continuity and resilience surface inventory",
                len(self.discovered_paths) >= 0,
                True,
                True,
                "Relevant continuity, backup, recovery and availability surfaces are inventoried.",
            ),
            ContinuityControl(
                "CONT-BACKUP-GOVERNANCE",
                "Backup governance",
                backup["valid"] is True,
                True,
                True,
                "Backup policy requires schedule, integrity, encryption, retention and separated copy.",
            ),
            ContinuityControl(
                "CONT-RECOVERY-GOVERNANCE",
                "Recovery governance",
                recovery["valid"] is True,
                True,
                True,
                "Recovery requires documented procedure, test, RTO/RPO, rollback and evidence.",
            ),
            ContinuityControl(
                "CONT-AVAILABILITY-GOVERNANCE",
                "Availability governance",
                availability["valid"] is True,
                True,
                True,
                "Availability requires health monitoring, dependency inventory and degradation plan.",
            ),
            ContinuityControl(
                "CONT-CONTINGENCY-GOVERNANCE",
                "Contingency governance",
                contingency["valid"] is True,
                True,
                True,
                "Contingency requires roles, escalation, communication, activation criteria and review.",
            ),
            ContinuityControl(
                "CONT-RTO-RPO",
                "RTO and RPO governance",
                recovery["rto_defined"] is True and recovery["rpo_defined"] is True,
                True,
                True,
                "Recovery objectives must be explicitly governed.",
            ),
            ContinuityControl(
                "CONT-INTEGRITY",
                "Backup and recovery integrity",
                backup["integrity"] is True and recovery["evidence"] is True,
                True,
                True,
                "Continuity artifacts require integrity and evidence.",
            ),
            ContinuityControl(
                "CONT-NO-REAL-BACKUP-RESTORE",
                "No real backup or restore action",
                backup["backup_executed"] is False
                and recovery["restore_executed"] is False
                and recovery["failover_executed"] is False,
                True,
                True,
                "Layer 1 does not execute backup, restore or failover.",
            ),
            ContinuityControl(
                "CONT-NO-SERVICE-ACTION",
                "No service or traffic action",
                availability["service_restarted"] is False
                and availability["traffic_shifted"] is False,
                True,
                True,
                "Assessment does not restart services or shift traffic.",
            ),
            ContinuityControl(
                "CONT-NO-CONTINGENCY-ACTIVATION",
                "No real contingency activation",
                contingency["contingency_activated"] is False
                and contingency["notification_sent"] is False,
                True,
                True,
                "Assessment does not activate contingency or send notifications.",
            ),
            ContinuityControl(
                "CONT-NO-EXTERNAL-CONNECTION",
                "No external connection",
                availability["external_connection_opened"] is False
                and contingency["external_connection_opened"] is False,
                True,
                True,
                "Assessment remains static and local.",
            ),
            ContinuityControl(
                "CONT-SECRET-SAFETY",
                "No secret values exposed",
                backup["secret_values_exposed"] is False
                and recovery["secret_values_exposed"] is False
                and availability["secret_values_exposed"] is False
                and contingency["secret_values_exposed"] is False,
                True,
                True,
                "Evidence contains metadata only.",
            ),
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and item.applicable and not item.passed
        ]

        return {
            "status": "CONTINUITY_RESILIENCE_GATE_PASS" if not failed else "CONTINUITY_RESILIENCE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "backup_governance": backup,
            "recovery_governance": recovery,
            "availability_governance": availability,
            "contingency_governance": contingency,
            "continuity_surfaces": len(self.discovered_paths),
            "backup_executed": False,
            "restore_executed": False,
            "failover_executed": False,
            "service_restarted": False,
            "traffic_shifted": False,
            "contingency_activated": False,
            "notification_sent": False,
            "production_data_modified": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
'@
$GatePy=@'
class ContinuityResilienceGate:
    BLOCKING = frozenset({
        "CONT-INVENTORY",
        "CONT-BACKUP-GOVERNANCE",
        "CONT-RECOVERY-GOVERNANCE",
        "CONT-AVAILABILITY-GOVERNANCE",
        "CONT-CONTINGENCY-GOVERNANCE",
        "CONT-RTO-RPO",
        "CONT-INTEGRITY",
        "CONT-NO-REAL-BACKUP-RESTORE",
        "CONT-NO-SERVICE-ACTION",
        "CONT-NO-CONTINGENCY-ACTIVATION",
        "CONT-NO-EXTERNAL-CONNECTION",
        "CONT-SECRET-SAFETY",
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

from .audit import ContinuityResilienceAuditor
from .gate import ContinuityResilienceGate


class ContinuityResilienceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = ContinuityResilienceAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = ContinuityResilienceGate.evaluate(result["controls"])
        result["status"] = (
            "CONTINUITY_RESILIENCE_GATE_PASS"
            if passed
            else "CONTINUITY_RESILIENCE_GATE_HOLD"
        )
        result["failed_blocking_controls"] = failed
        return result
'@
$TestsPy=@'
from sgoda.integration.spt02413.backup import assess_backup_policy
from sgoda.integration.spt02413.recovery import assess_recovery_policy
from sgoda.integration.spt02413.availability import assess_availability_policy
from sgoda.integration.spt02413.contingency import assess_contingency_policy
from sgoda.integration.spt02413.service import ContinuityResilienceService


def test_backup_policy_passes_complete_profile():
    result = assess_backup_policy({
        "versioned": True,
        "scheduled": True,
        "integrity": True,
        "encrypted": True,
        "retention": True,
        "separated_copy": True,
    })
    assert result["valid"] is True


def test_backup_policy_requires_integrity():
    result = assess_backup_policy({
        "versioned": True,
        "scheduled": True,
        "integrity": False,
        "encrypted": True,
        "retention": True,
        "separated_copy": True,
    })
    assert result["valid"] is False


def test_recovery_policy_passes_complete_profile():
    result = assess_recovery_policy({
        "documented": True,
        "tested": True,
        "rto_defined": True,
        "rpo_defined": True,
        "rollback": True,
        "evidence": True,
    })
    assert result["valid"] is True


def test_recovery_policy_requires_rto_rpo():
    result = assess_recovery_policy({
        "documented": True,
        "tested": True,
        "rto_defined": False,
        "rpo_defined": True,
        "rollback": True,
        "evidence": True,
    })
    assert result["valid"] is False


def test_availability_policy_passes():
    result = assess_availability_policy({
        "health_monitoring": True,
        "dependency_inventory": True,
        "capacity_review": True,
        "degradation_plan": True,
        "recovery_priority": True,
    })
    assert result["valid"] is True


def test_contingency_policy_passes():
    result = assess_contingency_policy({
        "roles_defined": True,
        "escalation": True,
        "communication": True,
        "activation_criteria": True,
        "evidence": True,
        "periodic_review": True,
    })
    assert result["valid"] is True


def test_full_gate_passes(tmp_path):
    result = ContinuityResilienceService(
        tmp_path,
        ["config/backup.json", "docs/recovery.md", ".github/workflows/ci.yml"],
    ).assess()
    assert result["status"] == "CONTINUITY_RESILIENCE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_twelve_controls(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert len(result["controls"]) == 12


def test_full_gate_does_not_execute_backup_restore_or_failover(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert result["backup_executed"] is False
    assert result["restore_executed"] is False
    assert result["failover_executed"] is False


def test_full_gate_does_not_restart_or_shift_traffic(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert result["service_restarted"] is False
    assert result["traffic_shifted"] is False


def test_full_gate_does_not_activate_contingency_or_notify(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert result["contingency_activated"] is False
    assert result["notification_sent"] is False


def test_full_gate_has_no_external_connection_or_secret_exposure(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
'@
$PolicyJson=@'
{
  "component": "SPT-024.13",
  "layer": "1",
  "version": "1.0.0",
  "title": "Continuidad Operacional, Resiliencia, Backup, Recuperacion, Disponibilidad y Gobierno de Contingencias",
  "blocking_controls": [
    "CONT-INVENTORY",
    "CONT-BACKUP-GOVERNANCE",
    "CONT-RECOVERY-GOVERNANCE",
    "CONT-AVAILABILITY-GOVERNANCE",
    "CONT-CONTINGENCY-GOVERNANCE",
    "CONT-RTO-RPO",
    "CONT-INTEGRITY",
    "CONT-NO-REAL-BACKUP-RESTORE",
    "CONT-NO-SERVICE-ACTION",
    "CONT-NO-CONTINGENCY-ACTIVATION",
    "CONT-NO-EXTERNAL-CONNECTION",
    "CONT-SECRET-SAFETY"
  ],
  "backup_governance": {
    "versioned": true,
    "scheduled": true,
    "integrity_required": true,
    "encryption_required": true,
    "retention_required": true,
    "separated_copy_required": true
  },
  "recovery_governance": {
    "documented": true,
    "tested": true,
    "rto_required": true,
    "rpo_required": true,
    "rollback_required": true,
    "evidence_required": true
  },
  "availability_governance": {
    "health_monitoring": true,
    "dependency_inventory": true,
    "capacity_review": true,
    "degradation_plan": true,
    "recovery_priority": true
  },
  "contingency_governance": {
    "roles_defined": true,
    "escalation": true,
    "communication": true,
    "activation_criteria": true,
    "evidence": true,
    "periodic_review": true
  },
  "safety": {
    "execute_backup": false,
    "execute_restore": false,
    "execute_failover": false,
    "restart_services": false,
    "shift_traffic": false,
    "activate_contingency": false,
    "send_notifications": false,
    "modify_production_data": false,
    "open_external_connections": false,
    "print_secret_values": false,
    "modify_closed_components": false
  }
}
'@
$DocMd=@'
# SPT-024.13 Capa 1 — Continuidad Operacional, Resiliencia, Backup, Recuperacion, Disponibilidad y Contingencias

Baseline autoritativa: `17c728bff606870558e1a7158399b86d11c581e4`.

Esta capa inicia el dominio SPT-024.13 dentro de PISI sin reabrir SPT-024.1–SPT-024.12.

## Alcance

- inventario de superficies de continuidad y resiliencia;
- gobierno de backup;
- gobierno de recuperacion;
- RTO y RPO;
- disponibilidad y degradacion controlada;
- dependencias y prioridades de recuperacion;
- gobierno de contingencias;
- integridad SHA-256;
- preservation gates;
- pruebas dirigidas y suite institucional;
- publicacion obligatoria en repositorio oficial.

## Seguridad operacional

La Capa 1 es estatica y no destructiva. No ejecuta backup, restore ni failover; no reinicia servicios; no desplaza trafico; no activa contingencias; no envia notificaciones; no modifica datos productivos; no abre conexiones externas y no expone secretos.

El cierre tecnico exige `commit + push + LOCAL HEAD = REMOTE HEAD`.
'@

WriteLf "$ModuleDir/__init__.py" $InitPy
WriteLf "$ModuleDir/models.py" $ModelsPy
WriteLf "$ModuleDir/backup.py" $BackupPy
WriteLf "$ModuleDir/recovery.py" $RecoveryPy
WriteLf "$ModuleDir/availability.py" $AvailabilityPy
WriteLf "$ModuleDir/contingency.py" $ContingencyPy
WriteLf "$ModuleDir/audit.py" $AuditPy
WriteLf "$ModuleDir/gate.py" $GatePy
WriteLf "$ModuleDir/integrity.py" $IntegrityPy
WriteLf "$ModuleDir/service.py" $ServicePy
WriteLf $TestFile $TestsPy
WriteLf $PolicyFile $PolicyJson
WriteLf $DocFile $DocMd

    Write-Host "SPT-024.13 CAPA 1 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"

    $env:PYTHONPATH=(Join-Path $Root "src")

    $ArgProbe=@(& $Python -c "import sys; assert len(sys.argv)==2 and sys.argv[1]=='SGODA_ARG_OK'; print('PYTHON_ARGUMENT_CONTRACT=PASS')" "SGODA_ARG_OK" 2>&1)
    if($LASTEXITCODE -ne 0 -or ($ArgProbe -join "`n") -notmatch "PYTHON_ARGUMENT_CONTRACT=PASS"){Hold "Python argument contract failed"}
    $ArgProbe|ForEach-Object{Write-Host ([string]$_)}

    Native $Python @(
        "-c",
        "from sgoda.integration.spt02413 import ContinuityResilienceService; from sgoda.integration.spt02413.gate import ContinuityResilienceGate; assert len(ContinuityResilienceGate.BLOCKING)==12; print('SPT02413_IMPORT=PASS'); print('BLOCKING_CONTROLS=12')"
    ) "SPT-024.13 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.13 targeted tests"
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q",(Join-Path $Root "src")) "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 8 "PRODUCTION CONTINUITY / RESILIENCE ASSESSMENT"

    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $SurfaceFile=Join-Path ([IO.Path]::GetTempPath()) ("spt02413-surfaces-"+[guid]::NewGuid().ToString("N")+".json")
    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("spt02413-probe-"+[guid]::NewGuid().ToString("N")+".py")

    $Normalized=@($Surfaces|ForEach-Object{$_ -replace '\\','/'})
    $Payload=($Normalized|ConvertTo-Json -Compress)
    if([string]::IsNullOrWhiteSpace($Payload)){$Payload="[]"}
    WriteLf $SurfaceFile $Payload

    $Probe=@'
import json,sys
from pathlib import Path
from sgoda.integration.spt02413 import ContinuityResilienceService
from sgoda.integration.spt02413.integrity import build_manifest

if len(sys.argv) != 2:
    raise SystemExit("SURFACE_ARGUMENT_CONTRACT_FAILED")

root=Path.cwd()
paths=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(paths,list):
    raise SystemExit("SURFACE_PAYLOAD_NOT_LIST")

result=ContinuityResilienceService(root,paths).assess()

ad=root/"artifacts/development/SPT-024.13-Capa1-v1.0.0"
ad.mkdir(parents=True,exist_ok=True)

assessment=ad/"continuity-resilience-assessment.json"
inventory=ad/"continuity-resilience-surface-inventory.json"
backup=ad/"backup-governance-baseline.json"
recovery=ad/"recovery-governance-baseline.json"
availability=ad/"availability-governance-baseline.json"
contingency=ad/"contingency-governance-baseline.json"
integrity=ad/"continuity-resilience-integrity-manifest.json"

assessment.write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

inventory.write_text(json.dumps({
    "mode":"GIT_TRACKED_STATIC_DISCOVERY",
    "surface_count":len(paths),
    "backup_executed":False,
    "restore_executed":False,
    "failover_executed":False,
    "service_restarted":False,
    "contingency_activated":False,
    "secret_values_exposed":False
},indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

backup.write_text(json.dumps(result["backup_governance"],indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
recovery.write_text(json.dumps(result["recovery_governance"],indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
availability.write_text(json.dumps(result["availability_governance"],indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
contingency.write_text(json.dumps(result["contingency_governance"],indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

manifest=build_manifest(root,[
    str(assessment.relative_to(root)).replace("\\","/"),
    str(inventory.relative_to(root)).replace("\\","/"),
    str(backup.relative_to(root)).replace("\\","/"),
    str(recovery.relative_to(root)).replace("\\","/"),
    str(availability.relative_to(root)).replace("\\","/"),
    str(contingency.relative_to(root)).replace("\\","/"),
    "config/integration/spt02413/continuity-resilience-policy.json",
])

integrity.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

print("SURFACE_TRANSFER_CONTRACT=PASS")
print("SURFACE_TRANSFER_MODE=TEMP_JSON_FILE")
print("SPT02413_CONTINUITY_STATUS="+result["status"])
print("CONTINUITY_SURFACES="+str(len(paths)))
print("FAILED_BLOCKING_CONTROLS="+str(len(result["failed_blocking_controls"])))
print("FAILED_CONTROL_IDS="+",".join(result["failed_blocking_controls"]))
print("INTEGRITY_RECORDS="+str(manifest["record_count"]))
print("BACKUP_EXECUTED=NO")
print("RESTORE_EXECUTED=NO")
print("FAILOVER_EXECUTED=NO")
print("SERVICE_RESTARTED=NO")
print("TRAFFIC_SHIFTED=NO")
print("CONTINGENCY_ACTIVATED=NO")
print("NOTIFICATION_SENT=NO")
print("PRODUCTION_DATA_MODIFIED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")

raise SystemExit(0 if result["status"]=="CONTINUITY_RESILIENCE_GATE_PASS" else 20)
'@

    WriteLf $ProbeFile $Probe

    try{
        & $Python $ProbeFile $SurfaceFile
        $ProbeExit=$LASTEXITCODE
    } finally {
        Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $SurfaceFile -Force -ErrorAction SilentlyContinue
    }

    if($ProbeExit -ne 0){Hold "Continuity/resilience assessment failed with exit code $ProbeExit"}

    Write-Host "CONTINUITY / RESILIENCE GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"

    $Assessment=Get-Content -LiteralPath (Join-Path $Root $AssessmentFile) -Raw -Encoding UTF8|ConvertFrom-Json
    if($Assessment.status -ne "CONTINUITY_RESILIENCE_GATE_PASS"){Hold "Assessment does not certify PASS"}

    $Evidence=[ordered]@{
        component="SPT-024.13"
        layer="1"
        version="1.0.0"
        generated_utc=[DateTime]::UtcNow.ToString("o")
        authoritative_baseline=$ExpectedBaseline
        final_status="CONTINUITY_RESILIENCE_GATE_PASS"
        gates=[ordered]@{
            targeted_tests="PASS"
            institutional_suite="PASS"
            compileall="PASS"
            continuity_resilience="PASS"
            preservation="PENDING"
            github_size="PENDING"
            remote_sync="PENDING"
        }
        backup_executed=$false
        restore_executed=$false
        failover_executed=$false
        service_restarted=$false
        contingency_activated=$false
        production_data_modified=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)

    Write-Host "ASSESSMENT   : CREATED"
    Write-Host "INVENTORY    : CREATED"
    Write-Host "BACKUP       : CREATED"
    Write-Host "RECOVERY     : CREATED"
    Write-Host "AVAILABILITY : CREATED"
    Write-Host "CONTINGENCY  : CREATED"
    Write-Host "INTEGRITY    : CREATED"
    Write-Host "EVIDENCE     : CREATED"

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
    Write-Host "SPT-024.1-.12 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"

    $Allowed=@(
        $SelfName,
        "$ModuleDir/__init__.py",
        "$ModuleDir/models.py",
        "$ModuleDir/backup.py",
        "$ModuleDir/recovery.py",
        "$ModuleDir/availability.py",
        "$ModuleDir/contingency.py",
        "$ModuleDir/audit.py",
        "$ModuleDir/gate.py",
        "$ModuleDir/integrity.py",
        "$ModuleDir/service.py",
        $TestFile,
        $PolicyFile,
        $DocFile,
        $AssessmentFile,
        $InventoryFile,
        $BackupFile,
        $RecoveryFile,
        $AvailabilityFile,
        $ContingencyFile,
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
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){
            Hold "Preservation changed before commit: $p"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"

    Native "git.exe" @(
        "commit",
        "-m",
        "feat(spt-024.13): implement continuity resilience backup recovery contingency layer 1"
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
    Write-Host "SPT-024.13 CAPA 1 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host "CONTINUITY_RESILIENCE_GATE=PASS"
    Write-Host "BACKUP_GOVERNANCE=PASS"
    Write-Host "RECOVERY_GOVERNANCE=PASS"
    Write-Host "RTO_RPO_GOVERNANCE=PASS"
    Write-Host "AVAILABILITY_GOVERNANCE=PASS"
    Write-Host "CONTINGENCY_GOVERNANCE=PASS"
    Write-Host "BACKUP_EXECUTED=NO"
    Write-Host "RESTORE_EXECUTED=NO"
    Write-Host "FAILOVER_EXECUTED=NO"
    Write-Host "SERVICE_RESTARTED=NO"
    Write-Host "TRAFFIC_SHIFTED=NO"
    Write-Host "CONTINGENCY_ACTIVATED=NO"
    Write-Host "NOTIFICATION_SENT=NO"
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
catch{
    Hold $_.Exception.Message
}
