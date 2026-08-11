from __future__ import annotations


SEVERITY_ORDER = {
    "INFO": 0,
    "LOW": 1,
    "MEDIUM": 2,
    "HIGH": 3,
    "CRITICAL": 4,
}


def escalation_rule(severity: str, event_count: int) -> dict:
    sev = str(severity).upper()
    score = SEVERITY_ORDER.get(sev, 0)

    if score >= 4 or event_count >= 10:
        level = "L3"
        authority = "INSTITUTIONAL_SECURITY_LEAD"
    elif score >= 3 or event_count >= 5:
        level = "L2"
        authority = "SECURITY_COORDINATION"
    else:
        level = "L1"
        authority = "OPERATIONAL_REVIEW"

    return {
        "severity": sev,
        "event_count": int(event_count),
        "escalation_level": level,
        "authority": authority,
        "notification_mode": "EVIDENCE_ONLY",
        "notification_sent": False,
        "action_executed": False,
        "secret_values_exposed": False,
    }
