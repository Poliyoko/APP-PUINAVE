from __future__ import annotations
from typing import Mapping


SEVERITY_ORDER = {
    "INFO": 0,
    "LOW": 1,
    "MEDIUM": 2,
    "HIGH": 3,
    "CRITICAL": 4,
}


def build_alert(incident: Mapping, minimum_severity: str = "HIGH") -> dict:
    severity = str(incident.get("severity", "INFO")).upper()
    minimum = minimum_severity.upper()

    should_alert = SEVERITY_ORDER.get(severity, 0) >= SEVERITY_ORDER.get(minimum, 3)

    return {
        "alert_id": "ALT-" + str(incident.get("incident_id", "UNKNOWN")).replace("INC-", ""),
        "incident_id": incident.get("incident_id"),
        "severity": severity,
        "should_alert": should_alert,
        "delivery_mode": "EVIDENCE_ONLY",
        "sent": False,
        "secret_values_exposed": False,
    }
