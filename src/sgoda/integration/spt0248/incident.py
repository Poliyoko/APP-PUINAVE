from __future__ import annotations
import hashlib
from dataclasses import asdict
from .models import IncidentRecord


ALLOWED_STATUS = {
    "DETECTED",
    "TRIAGED",
    "CONTAINED",
    "ERADICATED",
    "RECOVERED",
    "CLOSED",
}


def incident_fingerprint(source: str, category: str, evidence: str) -> str:
    data = f"{source}|{category}|{evidence}".encode("utf-8")
    return hashlib.sha256(data).hexdigest()[:24].upper()


def new_incident(incident_id: str, severity: str, source: str, category: str, evidence: str) -> dict:
    fp = incident_fingerprint(source, category, evidence)
    record = IncidentRecord(
        incident_id=incident_id,
        severity=severity,
        status="DETECTED",
        source=source,
        fingerprint=fp,
        metadata={"category": category},
    )
    return asdict(record)


def transition(record: dict, new_status: str) -> dict:
    if new_status not in ALLOWED_STATUS:
        raise ValueError("invalid incident status")
    out = dict(record)
    out["status"] = new_status
    return out
