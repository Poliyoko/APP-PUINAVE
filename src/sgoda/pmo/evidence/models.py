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