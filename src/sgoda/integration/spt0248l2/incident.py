from __future__ import annotations
from typing import Mapping


VALID_STATES = {
    "DETECTED",
    "TRIAGED",
    "ASSIGNED",
    "CONTAINED",
    "ERADICATED",
    "RECOVERED",
    "CLOSED",
}


def create_incident(correlation: Mapping) -> dict:
    correlation_id = str(correlation["correlation_id"])
    return {
        "incident_id": "INC-" + correlation_id.replace("COR-", ""),
        "correlation_id": correlation_id,
        "severity": str(correlation.get("severity", "INFO")).upper(),
        "status": "DETECTED",
        "event_count": int(correlation.get("event_count", 0)),
        "fingerprint": str(correlation.get("fingerprint", "")),
        "secret_values_exposed": False,
    }


def transition(incident: Mapping, status: str) -> dict:
    status = status.upper()
    if status not in VALID_STATES:
        raise ValueError("invalid incident status")

    updated = dict(incident)
    updated["status"] = status
    return updated
