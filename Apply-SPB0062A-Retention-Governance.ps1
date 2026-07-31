param(
    [string]$RepositoryRoot = (Get-Location).Path,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$RepositoryRoot = (Resolve-Path $RepositoryRoot).Path
Set-Location $RepositoryRoot

if (-not (Test-Path ".git")) {
    throw "La carpeta actual no es la raíz de un repositorio Git."
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupRoot = Join-Path $RepositoryRoot "artifacts/pmo/SPB-006-SEMS/patch-backups/SPB-006.2-A-$Timestamp"
$Files = [ordered]@{}

$Files["src/sgoda/pmo/evidence/models.py"] = @'
from __future__ import annotations
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any
from uuid import uuid4

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

class EvidenceType(str, Enum):
    FILE="file"; DIRECTORY="directory"; REPORT="report"; MANIFEST="manifest"
    ARCHIVE="archive"; TEST_RESULT="test-result"; AUDIT="audit"; OTHER="other"

class EvidenceStatus(str, Enum):
    REGISTERED="registered"; ARCHIVED="archived"; VERIFIED="verified"
    FAILED="failed"; EXTERNALIZED="externalized"; ACTIVE="active"
    RESTORABLE="restorable"; RETIRED="retired"
    PENDING_DELETION="pending-deletion"; DELETED="deleted"

class RetentionAction(str, Enum):
    KEEP="keep"; ARCHIVE="archive"; REVIEW="review"
    RETIRE="retire"; DELETE_CANDIDATE="delete-candidate"

@dataclass(frozen=True)
class IntegrityResult:
    valid: bool
    expected_sha256: str
    actual_sha256: str
    checked_at_utc: str = field(default_factory=utc_now_iso)
    details: str = ""
    def to_dict(self) -> dict[str, Any]: return asdict(self)

@dataclass
class EvidenceRecord:
    evidence_id: str
    name: str
    source_path: str
    evidence_type: EvidenceType
    status: EvidenceStatus
    sha256: str
    size_bytes: int
    created_at_utc: str
    registered_at_utc: str
    deliverable_id: str = ""
    commit: str = ""
    tag: str = ""
    archive_path: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)
    retention_policy: str = ""
    retention_policy_version: str = ""
    retention_until_utc: str = ""
    retention_action: str = ""
    retention_evaluated_at_utc: str = ""
    legal_hold: bool = False

    @classmethod
    def create(cls, source_path: Path, evidence_type: EvidenceType, sha256: str,
               size_bytes: int, *, evidence_id: str|None=None,
               deliverable_id: str="", commit: str="", tag: str="",
               metadata: dict[str,Any]|None=None) -> "EvidenceRecord":
        stat=source_path.stat()
        created=datetime.fromtimestamp(stat.st_mtime,tz=timezone.utc).isoformat()
        return cls(evidence_id or f"EVD-{uuid4().hex[:12].upper()}",
                   source_path.name, source_path.as_posix(), evidence_type,
                   EvidenceStatus.REGISTERED, sha256, size_bytes, created,
                   utc_now_iso(), deliverable_id, commit, tag, "", metadata or {})

    def to_dict(self) -> dict[str, Any]:
        data=asdict(self)
        data["evidence_type"]=self.evidence_type.value
        data["status"]=self.status.value
        return data

    @classmethod
    def from_dict(cls, data: dict[str,Any]) -> "EvidenceRecord":
        d=dict(data)
        d["evidence_type"]=EvidenceType(d["evidence_type"])
        d["status"]=EvidenceStatus(d["status"])
        defaults={
            "retention_policy":"",
            "retention_policy_version":"",
            "retention_until_utc":"",
            "retention_action":"",
            "retention_evaluated_at_utc":"",
            "legal_hold":False,
        }
        for key,value in defaults.items():
            d.setdefault(key,value)
        return cls(**d)
'@

$Files["src/sgoda/pmo/evidence/retention_policy.py"] = @'
from __future__ import annotations
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

@dataclass(frozen=True)
class RetentionPolicy:
    policy_id: str
    version: str
    description: str
    duration_days: int | None
    action_on_expiry: str
    permanent: bool = False
    priority: int = 100
    match: dict[str, Any] | None = None

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "RetentionPolicy":
        return cls(
            policy_id=data["policy_id"],
            version=data.get("version","1.0"),
            description=data.get("description",""),
            duration_days=data.get("duration_days"),
            action_on_expiry=data.get("action_on_expiry","review"),
            permanent=bool(data.get("permanent",False)),
            priority=int(data.get("priority",100)),
            match=dict(data.get("match",{})),
        )

class RetentionPolicyRepository:
    def __init__(self, path: Path) -> None:
        self.path=path

    def load(self) -> list[RetentionPolicy]:
        data=json.loads(self.path.read_text(encoding="utf-8"))
        policies=[RetentionPolicy.from_dict(item) for item in data.get("policies",[])]
        return sorted(policies,key=lambda item:item.priority)

    def get(self, policy_id: str) -> RetentionPolicy:
        for policy in self.load():
            if policy.policy_id==policy_id:
                return policy
        raise KeyError(f"No existe la política: {policy_id}")
'@

$Files["src/sgoda/pmo/evidence/retention.py"] = @'
from __future__ import annotations
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from typing import Any
from .models import EvidenceRecord
from .retention_policy import RetentionPolicy, RetentionPolicyRepository

def parse_utc(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z","+00:00")).astimezone(timezone.utc)

@dataclass(frozen=True)
class RetentionDecision:
    evidence_id: str
    policy_id: str
    policy_version: str
    action: str
    permanent: bool
    retention_until_utc: str
    evaluated_at_utc: str
    reason: str
    legal_hold: bool

    def to_dict(self) -> dict[str,Any]:
        return asdict(self)

class RetentionDecisionEngine:
    def __init__(self, repository: RetentionPolicyRepository) -> None:
        self.repository=repository

    @staticmethod
    def _matches(record: EvidenceRecord, policy: RetentionPolicy) -> bool:
        match=policy.match or {}
        if "evidence_type" in match and record.evidence_type.value not in match["evidence_type"]:
            return False
        if "deliverable_prefix" in match and not any(
            record.deliverable_id.upper().startswith(prefix.upper())
            for prefix in match["deliverable_prefix"]
        ):
            return False
        if match.get("requires_tag") is True and not record.tag:
            return False
        if match.get("requires_commit") is True and not record.commit:
            return False
        name_suffixes=match.get("name_suffix")
        if name_suffixes and not any(record.name.lower().endswith(x.lower()) for x in name_suffixes):
            return False
        return True

    def select_policy(self, record: EvidenceRecord) -> RetentionPolicy:
        explicit=str(record.metadata.get("retention_policy","")).strip()
        if explicit:
            return self.repository.get(explicit)
        for policy in self.repository.load():
            if self._matches(record,policy):
                return policy
        return self.repository.get("RET-DEFAULT-REVIEW")

    def evaluate(self, record: EvidenceRecord, now: datetime|None=None) -> RetentionDecision:
        now=now or datetime.now(timezone.utc)
        policy=self.select_policy(record)
        if record.legal_hold or bool(record.metadata.get("legal_hold",False)):
            return RetentionDecision(
                record.evidence_id,policy.policy_id,policy.version,"keep",True,"",
                now.isoformat(),"legal-hold",True
            )
        if policy.permanent or policy.duration_days is None:
            until=""
            action="keep"
            reason="permanent-policy"
        else:
            base=parse_utc(record.registered_at_utc)
            expiry=base+timedelta(days=policy.duration_days)
            until=expiry.isoformat()
            expired=now>=expiry
            action=policy.action_on_expiry if expired else "keep"
            reason="expired" if expired else "within-retention-period"
        return RetentionDecision(
            record.evidence_id,policy.policy_id,policy.version,action,
            policy.permanent,until,now.isoformat(),reason,False
        )

class RetentionManager:
    def __init__(self, registry, engine: RetentionDecisionEngine) -> None:
        self.registry=registry
        self.engine=engine

    def evaluate_one(self, evidence_id: str, *, apply: bool=False) -> RetentionDecision:
        record=self.registry.get(evidence_id)
        decision=self.engine.evaluate(record)
        if apply:
            record.retention_policy=decision.policy_id
            record.retention_policy_version=decision.policy_version
            record.retention_until_utc=decision.retention_until_utc
            record.retention_action=decision.action
            record.retention_evaluated_at_utc=decision.evaluated_at_utc
            record.legal_hold=decision.legal_hold
            self.registry.update(record)
        return decision

    def evaluate_all(self, *, apply: bool=False) -> list[RetentionDecision]:
        return [self.evaluate_one(item.evidence_id,apply=apply) for item in self.registry.list()]

    @staticmethod
    def summary(decisions: list[RetentionDecision], *, applied: bool) -> dict[str,Any]:
        by_action: dict[str,int]={}
        by_policy: dict[str,int]={}
        for item in decisions:
            by_action[item.action]=by_action.get(item.action,0)+1
            by_policy[item.policy_id]=by_policy.get(item.policy_id,0)+1
        return {
            "schema":"sgoda.sems.retention-report/v1",
            "mode":"apply" if applied else "dry-run",
            "records":len(decisions),
            "by_action":by_action,
            "by_policy":by_policy,
            "decisions":[item.to_dict() for item in decisions],
        }
'@

$Files["src/sgoda/pmo/evidence/retention_audit.py"] = @'
from __future__ import annotations
from typing import Any

def audit_retention(records) -> dict[str,Any]:
    findings=[]
    for record in records:
        if not record.retention_policy:
            findings.append({"evidence_id":record.evidence_id,"severity":"warning","code":"RET-POLICY-MISSING"})
        if record.retention_action=="delete-candidate" and not record.retention_evaluated_at_utc:
            findings.append({"evidence_id":record.evidence_id,"severity":"error","code":"RET-EVALUATION-MISSING"})
        if record.legal_hold and record.retention_action not in ("","keep"):
            findings.append({"evidence_id":record.evidence_id,"severity":"error","code":"RET-LEGAL-HOLD-CONFLICT"})
    return {
        "schema":"sgoda.sems.retention-audit/v1",
        "records":len(records),
        "findings":findings,
        "compliant":not any(item["severity"]=="error" for item in findings),
    }
'@

$Files["src/sgoda/pmo/evidence/manager.py"] = @'
from __future__ import annotations
from pathlib import Path
from typing import Any
from .archive import create_archive
from .exceptions import EvidenceValidationError
from .hasher import calculate_sha256, calculate_size
from .models import EvidenceRecord,EvidenceStatus,EvidenceType,IntegrityResult
from .registry import EvidenceRegistry
from .retention import RetentionDecisionEngine,RetentionManager
from .retention_policy import RetentionPolicyRepository
from .verifier import verify_archive_contents,verify_path

class EvidenceManager:
    def __init__(self,repository_root:Path,registry_path:Path|None=None)->None:
        self.repository_root=repository_root.resolve()
        self.sems_root=self.repository_root/"artifacts"/"pmo"/"SPB-006-SEMS"
        self.registry=EvidenceRegistry(registry_path or self.sems_root/"registry"/"evidence-registry.json")
        policy_path=self.repository_root/"config"/"evidence-retention-policies.json"
        self.retention=RetentionManager(
            self.registry,
            RetentionDecisionEngine(RetentionPolicyRepository(policy_path))
        )

    def register(self,source:Path,*,evidence_id:str|None=None,evidence_type:EvidenceType|None=None,
                 deliverable_id:str="",commit:str="",tag:str="",metadata:dict[str,Any]|None=None)->EvidenceRecord:
        source=source.resolve()
        if not source.exists(): raise EvidenceValidationError(f"No existe la ruta: {source}")
        selected=evidence_type or (EvidenceType.DIRECTORY if source.is_dir() else EvidenceType.FILE)
        record=EvidenceRecord.create(source,selected,calculate_sha256(source),calculate_size(source),
                                     evidence_id=evidence_id,deliverable_id=deliverable_id,
                                     commit=commit,tag=tag,metadata=metadata)
        return self.registry.add(record)

    def verify(self,evidence_id:str)->IntegrityResult:
        record=self.registry.get(evidence_id)
        source=Path(record.archive_path or record.source_path)
        result=verify_path(source,record.sha256)
        record.status=EvidenceStatus.VERIFIED if result.valid else EvidenceStatus.FAILED
        self.registry.update(record)
        return result

    def archive(self,evidence_id:str,destination:Path|None=None)->EvidenceRecord:
        record=self.registry.get(evidence_id)
        source=Path(record.source_path)
        destination=destination or self.sems_root/"archives"/f"{record.evidence_id}-{record.name}.zip"
        archive_path,archive_sha=create_archive(source,destination,metadata={
            "evidence_id":record.evidence_id,"deliverable_id":record.deliverable_id,
            "source_sha256":record.sha256,"commit":record.commit,"tag":record.tag})
        valid,errors=verify_archive_contents(archive_path)
        if not valid: raise EvidenceValidationError("ZIP inválido: "+", ".join(errors))
        record.archive_path=archive_path.as_posix()
        record.sha256=archive_sha
        record.size_bytes=archive_path.stat().st_size
        record.status=EvidenceStatus.ARCHIVED
        return self.registry.update(record)

    def status(self)->dict[str,Any]:
        records=self.registry.list()
        by_status={}
        by_retention_action={}
        for record in records:
            by_status[record.status.value]=by_status.get(record.status.value,0)+1
            if record.retention_action:
                by_retention_action[record.retention_action]=by_retention_action.get(record.retention_action,0)+1
        return {
            "schema":"sgoda.sems.status/v2",
            "registry":self.registry.path.as_posix(),
            "records":len(records),
            "by_status":by_status,
            "by_retention_action":by_retention_action,
        }
'@

$Files["src/sgoda/pmo/evidence/cli.py"] = @'
from __future__ import annotations
import argparse,json,subprocess
from pathlib import Path
from .manager import EvidenceManager
from .models import EvidenceType
from .retention_audit import audit_retention

def git_value(root:Path,*args:str)->str:
    try:
        return subprocess.run(["git",*args],cwd=root,check=True,capture_output=True,text=True).stdout.strip()
    except (OSError,subprocess.CalledProcessError):
        return ""

def build_parser()->argparse.ArgumentParser:
    parser=argparse.ArgumentParser(prog="sgoda-sems",description="SGODA Evidence Management System")
    parser.add_argument("--root",default=".")
    sub=parser.add_subparsers(dest="command",required=True)

    register=sub.add_parser("register")
    register.add_argument("source")
    register.add_argument("--id",dest="evidence_id")
    register.add_argument("--type",choices=[i.value for i in EvidenceType])
    register.add_argument("--deliverable",default="")
    register.add_argument("--commit",default="")
    register.add_argument("--tag",default="")

    verify=sub.add_parser("verify")
    verify.add_argument("evidence_id")

    archive=sub.add_parser("archive")
    archive.add_argument("evidence_id")
    archive.add_argument("--destination")

    retention=sub.add_parser("retention")
    retention.add_argument("evidence_id",nargs="?")
    retention.add_argument("--apply",action="store_true")
    retention.add_argument("--dry-run",action="store_true")

    sub.add_parser("retention-audit")
    sub.add_parser("retention-policies")
    sub.add_parser("status")
    sub.add_parser("list")
    return parser

def main(argv:list[str]|None=None)->int:
    args=build_parser().parse_args(argv)
    root=Path(args.root).resolve()
    manager=EvidenceManager(root)

    if args.command=="register":
        record=manager.register(
            Path(args.source),
            evidence_id=args.evidence_id,
            evidence_type=EvidenceType(args.type) if args.type else None,
            deliverable_id=args.deliverable,
            commit=args.commit or git_value(root,"rev-parse","HEAD"),
            tag=args.tag,
        )
        print(json.dumps(record.to_dict(),ensure_ascii=False,indent=2))
        return 0

    if args.command=="verify":
        result=manager.verify(args.evidence_id)
        print(json.dumps(result.to_dict(),ensure_ascii=False,indent=2))
        return 0 if result.valid else 2

    if args.command=="archive":
        record=manager.archive(args.evidence_id,Path(args.destination).resolve() if args.destination else None)
        print(json.dumps(record.to_dict(),ensure_ascii=False,indent=2))
        return 0

    if args.command=="retention":
        apply=bool(args.apply)
        if args.evidence_id:
            decision=manager.retention.evaluate_one(args.evidence_id,apply=apply)
            output=decision.to_dict()
            output["mode"]="apply" if apply else "dry-run"
        else:
            decisions=manager.retention.evaluate_all(apply=apply)
            output=manager.retention.summary(decisions,applied=apply)
        print(json.dumps(output,ensure_ascii=False,indent=2))
        return 0

    if args.command=="retention-audit":
        report=audit_retention(manager.registry.list())
        print(json.dumps(report,ensure_ascii=False,indent=2))
        return 0 if report["compliant"] else 2

    if args.command=="retention-policies":
        policies=[item.__dict__ for item in manager.retention.engine.repository.load()]
        print(json.dumps(policies,ensure_ascii=False,indent=2))
        return 0

    if args.command=="status":
        print(json.dumps(manager.status(),ensure_ascii=False,indent=2))
        return 0

    if args.command=="list":
        print(json.dumps([r.to_dict() for r in manager.registry.list()],ensure_ascii=False,indent=2))
        return 0

    return 2
'@

$Files["src/sgoda/pmo/evidence/__init__.py"] = @'
"""SGODA Evidence Management System (SEMS)."""
from .manager import EvidenceManager
from .models import (
    EvidenceRecord, EvidenceStatus, EvidenceType, IntegrityResult, RetentionAction
)
from .retention import RetentionDecision, RetentionDecisionEngine, RetentionManager
from .retention_policy import RetentionPolicy, RetentionPolicyRepository

__all__ = [
    "EvidenceManager","EvidenceRecord","EvidenceStatus","EvidenceType","IntegrityResult",
    "RetentionAction","RetentionDecision","RetentionDecisionEngine","RetentionManager",
    "RetentionPolicy","RetentionPolicyRepository",
]
__version__ = "0.2.0"
'@

$Files["config/evidence-retention-policies.json"] = @'
{
  "schema": "sgoda.sems.retention-policy-set/v1",
  "version": "1.0.0",
  "policies": [
    {
      "policy_id": "RET-PERMANENT-GOVERNANCE",
      "version": "1.0",
      "description": "ADR, actas, normas, auditorías y manifiestos de cierre.",
      "duration_days": null,
      "action_on_expiry": "keep",
      "permanent": true,
      "priority": 10,
      "match": {
        "evidence_type": ["audit", "manifest"],
        "deliverable_prefix": ["ADR", "ACT", "SGD", "SPB"]
      }
    },
    {
      "policy_id": "RET-RELEASE-PERMANENT",
      "version": "1.0",
      "description": "Evidencia vinculada con tags de release.",
      "duration_days": null,
      "action_on_expiry": "keep",
      "permanent": true,
      "priority": 20,
      "match": {
        "requires_tag": true
      }
    },
    {
      "policy_id": "RET-TEST-5Y",
      "version": "1.0",
      "description": "Resultados de prueba conservados durante cinco años.",
      "duration_days": 1825,
      "action_on_expiry": "review",
      "permanent": false,
      "priority": 30,
      "match": {
        "evidence_type": ["test-result"]
      }
    },
    {
      "policy_id": "RET-ARCHIVE-2Y",
      "version": "1.0",
      "description": "Archivos técnicos y respaldos consolidados por dos años.",
      "duration_days": 730,
      "action_on_expiry": "review",
      "permanent": false,
      "priority": 40,
      "match": {
        "evidence_type": ["archive"]
      }
    },
    {
      "policy_id": "RET-TEMP-90D",
      "version": "1.0",
      "description": "Evidencia temporal candidata a revisión después de 90 días.",
      "duration_days": 90,
      "action_on_expiry": "delete-candidate",
      "permanent": false,
      "priority": 50,
      "match": {
        "name_suffix": [".tmp", ".bak", ".log"]
      }
    },
    {
      "policy_id": "RET-DEFAULT-REVIEW",
      "version": "1.0",
      "description": "Política predeterminada: revisión anual.",
      "duration_days": 365,
      "action_on_expiry": "review",
      "permanent": false,
      "priority": 999,
      "match": {}
    }
  ]
}
'@

$Files["tests/pmo/evidence/test_retention_manager.py"] = @'
from datetime import datetime, timedelta, timezone
from pathlib import Path
import json
from sgoda.pmo.evidence.manager import EvidenceManager
from sgoda.pmo.evidence.models import EvidenceType
from sgoda.pmo.evidence.retention import RetentionDecisionEngine
from sgoda.pmo.evidence.retention_policy import RetentionPolicyRepository

def write_policies(path:Path)->None:
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps({
        "policies":[
            {"policy_id":"RET-MANIFEST","version":"1.0","duration_days":None,
             "action_on_expiry":"keep","permanent":True,"priority":1,
             "match":{"evidence_type":["manifest"]}},
            {"policy_id":"RET-DEFAULT-REVIEW","version":"1.0","duration_days":30,
             "action_on_expiry":"review","permanent":False,"priority":999,"match":{}}
        ]
    }),encoding="utf-8")

def make_manager(tmp_path:Path)->EvidenceManager:
    repo=tmp_path/"repo"
    repo.mkdir()
    write_policies(repo/"config"/"evidence-retention-policies.json")
    return EvidenceManager(repo)

def test_manifest_gets_permanent_policy(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"manifest.json"
    sample.write_text("{}",encoding="utf-8")
    manager.register(sample,evidence_id="EVD-RET-1",evidence_type=EvidenceType.MANIFEST)
    decision=manager.retention.evaluate_one("EVD-RET-1")
    assert decision.policy_id=="RET-MANIFEST"
    assert decision.permanent is True
    assert decision.action=="keep"

def test_dry_run_does_not_change_registry(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"file.txt"
    sample.write_text("x",encoding="utf-8")
    manager.register(sample,evidence_id="EVD-RET-2")
    manager.retention.evaluate_one("EVD-RET-2",apply=False)
    assert manager.registry.get("EVD-RET-2").retention_policy==""

def test_apply_persists_decision(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"file.txt"
    sample.write_text("x",encoding="utf-8")
    manager.register(sample,evidence_id="EVD-RET-3")
    manager.retention.evaluate_one("EVD-RET-3",apply=True)
    record=manager.registry.get("EVD-RET-3")
    assert record.retention_policy=="RET-DEFAULT-REVIEW"
    assert record.retention_action=="keep"

def test_expired_record_becomes_review(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"file.txt"
    sample.write_text("x",encoding="utf-8")
    record=manager.register(sample,evidence_id="EVD-RET-4")
    record.registered_at_utc=(datetime.now(timezone.utc)-timedelta(days=40)).isoformat()
    manager.registry.update(record)
    decision=manager.retention.engine.evaluate(
        manager.registry.get("EVD-RET-4"),datetime.now(timezone.utc)
    )
    assert decision.action=="review"
    assert decision.reason=="expired"

def test_legal_hold_overrides_expiry(tmp_path:Path)->None:
    manager=make_manager(tmp_path)
    sample=manager.repository_root/"file.txt"
    sample.write_text("x",encoding="utf-8")
    record=manager.register(sample,evidence_id="EVD-RET-5")
    record.legal_hold=True
    manager.registry.update(record)
    decision=manager.retention.evaluate_one("EVD-RET-5")
    assert decision.action=="keep"
    assert decision.legal_hold is True
'@

$Files["docs/03_ADR/ADR-011-Retention-Policy-Engine.md"] = @'
# ADR-011 — Retention Policy Engine

## Estado
Aceptada para SPB-006.2-A.

## Decisión
Implementar un motor institucional de políticas de retención separado del
registro SEMS. Las reglas se almacenan en JSON UTF-8 y se evalúan por prioridad.

## Garantías
- La simulación es el modo predeterminado.
- Ninguna evidencia se elimina automáticamente.
- `delete-candidate` significa candidata a revisión, no eliminación.
- La suspensión legal (`legal_hold`) prevalece sobre cualquier vencimiento.
- Cada decisión conserva identificador y versión de la política aplicada.
'@

$Files["docs/01_Gobierno/SGD-113-Politica-Retencion-Evidencias.md"] = @'
# SGD-113 — Política Institucional de Retención de Evidencias

SPB-006.2-A incorpora gobierno del ciclo de vida mediante políticas versionadas.

Principios:
1. Conservación permanente para evidencia de gobierno y releases.
2. Retención temporal para pruebas y archivos técnicos.
3. Evaluación reproducible y auditable.
4. Simulación obligatoria antes de aplicar.
5. Prohibición de eliminación automática en esta fase.
6. Prevalencia de `legal_hold`.
7. Registro de política, versión, acción y fecha de evaluación.
'@

$Files["artifacts/pmo/SPB-006-SEMS/SPB-006.2-A-implementation-manifest.json"] = @'
{
  "schema": "sgoda.spb.implementation/v1",
  "deliverable": "SPB-006.2-A",
  "name": "Motor Institucional de Gobierno del Ciclo de Vida de Evidencias",
  "version": "0.2.0",
  "status": "implemented",
  "capabilities": [
    "versioned-retention-policies",
    "retention-decision-engine",
    "dry-run",
    "apply-decision",
    "legal-hold",
    "retention-audit",
    "retention-report"
  ],
  "safety": {
    "automatic_delete": false,
    "delete_candidate_requires_review": true
  }
}
'@

function Write-Utf8NoBom {
    param([string]$Path,[string]$Content)
    $FullPath=Join-Path $RepositoryRoot $Path
    New-Item -ItemType Directory -Force -Path (Split-Path $FullPath -Parent) | Out-Null

    if (Test-Path $FullPath) {
        $BackupPath=Join-Path $BackupRoot $Path
        New-Item -ItemType Directory -Force -Path (Split-Path $BackupPath -Parent) | Out-Null
        Copy-Item $FullPath $BackupPath -Force
        Write-Host "RESPALDADO: $Path"
    }

    [System.IO.File]::WriteAllText(
        $FullPath,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host "ACTUALIZADO: $Path"
}

Write-Host ""
Write-Host "============================================================"
Write-Host " SPB-006.2-A - Gobierno del Ciclo de Vida de Evidencias"
Write-Host "============================================================"
Write-Host ""

foreach ($Entry in $Files.GetEnumerator()) {
    Write-Utf8NoBom $Entry.Key $Entry.Value
}

$env:PYTHONPATH="src"

python -c "from sgoda.pmo.evidence import RetentionManager, RetentionDecisionEngine; print('Retention Engine import: OK')"
if ($LASTEXITCODE -ne 0) { throw "Falló la importación del Retention Engine." }

python -m pytest tests/pmo/evidence -q
if ($LASTEXITCODE -ne 0) { throw "Fallaron las pruebas de SPB-006.2-A." }

python -m sgoda.pmo.evidence --root . retention-policies | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Falló la carga de políticas." }

Write-Host ""
Write-Host "Simulación de retención sobre el registro actual:"
python -m sgoda.pmo.evidence --root . retention --dry-run
if ($LASTEXITCODE -ne 0) { throw "Falló la simulación de retención." }

Write-Host ""
Write-Host "SPB-006.2-A IMPLEMENTADO."
Write-Host "Respaldo de archivos reemplazados: $BackupRoot"
Write-Host "La simulación NO modificó el registro."
Write-Host "No se elimina ninguna evidencia."
Write-Host "No ejecute git add ."
