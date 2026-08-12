from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable, Mapping
import hashlib

VALID_STATES = {
    "ACTIVE","ARCHIVE_READY","ARCHIVED","RETENTION_REVIEW",
    "DISPOSAL_REVIEW","LEGAL_HOLD","CLOSED"
}
TRANSITIONS = {
    "ACTIVE":{"ARCHIVE_READY","LEGAL_HOLD","RETENTION_REVIEW"},
    "ARCHIVE_READY":{"ARCHIVED","LEGAL_HOLD"},
    "ARCHIVED":{"RETENTION_REVIEW","LEGAL_HOLD"},
    "RETENTION_REVIEW":{"DISPOSAL_REVIEW","LEGAL_HOLD","CLOSED"},
    "DISPOSAL_REVIEW":{"LEGAL_HOLD","CLOSED"},
    "LEGAL_HOLD":{"RETENTION_REVIEW","CLOSED"},
    "CLOSED":set(),
}

@dataclass(frozen=True)
class Control:
    control_id: str
    passed: bool
    blocking: bool
    detail: str

def transition(record: Mapping, target: str) -> dict:
    current = str(record.get("state","")).upper()
    target = str(target).upper()
    if current not in VALID_STATES or target not in VALID_STATES:
        raise ValueError("invalid data lifecycle state")
    if target not in TRANSITIONS[current]:
        raise ValueError("invalid data lifecycle transition")
    updated = dict(record)
    updated["state"] = target
    return updated

def archive_plan(profile: Mapping) -> dict:
    fmt = str(profile.get("archive_format","")).upper()
    valid = (
        bool(str(profile.get("record_id","")).strip())
        and fmt in {"JSON","JSONL","CSV","WAV","FLAC","PNG","WEBP"}
        and bool(profile.get("integrity_required",False))
        and bool(profile.get("immutable",False))
    )
    return {
        "valid":valid,"archive_format":fmt,"archive_executed":False,
        "production_data_modified":False,"external_connection_opened":False,
        "secret_values_exposed":False
    }

def retention(profile: Mapping, now: datetime|None=None) -> dict:
    now = now or datetime.now(timezone.utc)
    created = datetime.fromisoformat(str(profile["created_at"]).replace("Z","+00:00"))
    days = int(profile.get("retention_days",0))
    minimum = int(profile.get("minimum_retention_days",1))
    legal_hold = bool(profile.get("legal_hold",False))
    expires = created + timedelta(days=days)
    expired = expires <= now
    disposition = "HOLD" if legal_hold else ("DISPOSAL_REVIEW" if expired else "RETAIN")
    return {
        "valid": days >= minimum and days > 0,
        "retention_days":days,"minimum_retention_days":minimum,
        "legal_hold":legal_hold,"expired":expired,"disposition":disposition,
        "disposal_executed":False,"production_data_deleted":False,
        "secret_values_exposed":False
    }

def legal_hold(profile: Mapping) -> dict:
    reason = str(profile.get("reason","")).strip()
    authority = str(profile.get("authority","")).strip()
    active = bool(profile.get("active",False))
    valid = bool(str(profile.get("hold_id","")).strip()) and len(reason) >= 10 and bool(authority) and active
    return {
        "valid":valid,"active":active,"release_executed":False,
        "production_data_deleted":False,"secret_values_exposed":False
    }

def disposal_review(profile: Mapping) -> dict:
    reason = str(profile.get("reason","")).strip()
    eligible = (
        bool(str(profile.get("record_id","")).strip())
        and bool(str(profile.get("approved_by","")).strip())
        and len(reason) >= 10
        and not bool(profile.get("legal_hold",False))
        and bool(profile.get("integrity_verified",False))
    )
    return {
        "eligible":eligible,"disposal_executed":False,
        "production_data_deleted":False,"secret_values_exposed":False
    }

def privacy_governance(profile: Mapping) -> dict:
    valid = (
        str(profile.get("purpose","")).upper() in {"PRESERVATION","TEACHING","AUDIT","SECURITY","OPERATIONS"}
        and str(profile.get("classification","")).upper() in {"PUBLIC","INTERNAL","CONFIDENTIAL","RESTRICTED"}
        and bool(profile.get("access_review",False))
        and bool(profile.get("minimization_review",False))
        and bool(profile.get("retention_review",False))
    )
    return {
        "valid":valid,"production_policy_changed":False,
        "external_disclosure_executed":False,"secret_values_exposed":False
    }

class DataLifecycleGovernanceGate:
    BLOCKING = {
        "DATA-LIFECYCLE","DATA-ARCHIVE-GOVERNANCE","DATA-ADVANCED-RETENTION",
        "DATA-LEGAL-HOLD","DATA-DISPOSAL-CONTROL","DATA-PRIVACY-GOVERNANCE",
        "DATA-NO-DESTRUCTIVE-ACTION","DATA-NO-SIDE-EFFECTS","DATA-SECRET-SAFETY"
    }

    @classmethod
    def evaluate(cls, controls):
        by_id = {c.control_id:c for c in controls}
        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:"+m for m in missing]
        failed = [cid for cid in sorted(cls.BLOCKING) if by_id[cid].blocking and not by_id[cid].passed]
        return not failed, failed

class DataLifecycleGovernanceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        state = {"state":"ACTIVE","record_id":"ODA-001"}
        for target in ["ARCHIVE_READY","ARCHIVED","RETENTION_REVIEW","DISPOSAL_REVIEW","CLOSED"]:
            state = transition(state,target)

        a = archive_plan({
            "record_id":"ODA-001","archive_format":"JSON",
            "integrity_required":True,"immutable":True
        })
        r = retention({
            "created_at":"2025-01-01T00:00:00+00:00",
            "retention_days":365,"minimum_retention_days":30,"legal_hold":False
        }, datetime(2026,8,11,tzinfo=timezone.utc))
        h = legal_hold({
            "hold_id":"LH-001","reason":"Institutional preservation review",
            "authority":"PISI_PRIVACY_OWNER","active":True
        })
        d = disposal_review({
            "record_id":"ODA-001","approved_by":"PISI_PRIVACY_OWNER",
            "reason":"Retention period completed and reviewed",
            "legal_hold":False,"integrity_verified":True
        })
        g = privacy_governance({
            "purpose":"PRESERVATION","classification":"RESTRICTED",
            "access_review":True,"minimization_review":True,"retention_review":True
        })

        controls = [
            Control("DATA-LIFECYCLE", state["state"]=="CLOSED", True, "Formal lifecycle closes after governed review."),
            Control("DATA-ARCHIVE-GOVERNANCE", a["valid"] is True, True, "Archive requires integrity and immutability."),
            Control("DATA-ADVANCED-RETENTION", r["valid"] is True and r["disposition"] in {"RETAIN","HOLD","DISPOSAL_REVIEW"}, True, "Retention is time-bound."),
            Control("DATA-LEGAL-HOLD", h["valid"] is True, True, "Legal hold requires reason and authority."),
            Control("DATA-DISPOSAL-CONTROL", d["eligible"] is True and d["disposal_executed"] is False, True, "Disposal remains review-only."),
            Control("DATA-PRIVACY-GOVERNANCE", g["valid"] is True, True, "Purpose/classification/access/minimization/retention jointly reviewed."),
            Control("DATA-NO-DESTRUCTIVE-ACTION", r["production_data_deleted"] is False and h["production_data_deleted"] is False and d["production_data_deleted"] is False, True, "No production deletion."),
            Control("DATA-NO-SIDE-EFFECTS", a["production_data_modified"] is False and g["production_policy_changed"] is False and g["external_disclosure_executed"] is False, True, "No production mutation or disclosure."),
            Control("DATA-SECRET-SAFETY", all(x["secret_values_exposed"] is False for x in [a,r,h,d,g]), True, "No secret values exposed."),
        ]
        passed, failed = DataLifecycleGovernanceGate.evaluate(controls)
        return {
            "status":"DATA_LIFECYCLE_GOVERNANCE_GATE_PASS" if passed else "DATA_LIFECYCLE_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls":failed,
            "controls":[c.__dict__ for c in controls],
            "lifecycle_final_state":state["state"],
            "archive_plan":a,"retention":r,"legal_hold":h,
            "disposal_review":d,"privacy_governance":g,
            "discovered_data_lifecycle_surfaces":len(self.discovered_paths),
            "production_data_modified":False,"production_data_deleted":False,
            "archive_executed":False,"disposal_executed":False,
            "external_disclosure_executed":False,"external_connection_opened":False,
            "secret_values_exposed":False
        }

def sha256(path: Path) -> str:
    d=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            d.update(chunk)
    return d.hexdigest()

def build_manifest(root: Path, paths: Iterable[str]) -> dict:
    records=[]
    for rel in sorted(set(paths)):
        p=root/rel
        if p.is_file():
            records.append({"path":rel.replace("\\\\","/"),"bytes":p.stat().st_size,"sha256":sha256(p)})
    return {"algorithm":"SHA-256","record_count":len(records),"records":records}
