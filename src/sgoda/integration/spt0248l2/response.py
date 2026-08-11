from __future__ import annotations
from typing import Mapping


ALLOWED_ACTIONS = {
    "REVIEW",
    "ESCALATE",
    "CONTAIN",
    "ERADICATE",
    "RECOVER",
}


def plan_response(incident: Mapping) -> dict:
    severity = str(incident.get("severity", "INFO")).upper()

    if severity == "CRITICAL":
        actions = ["REVIEW", "ESCALATE", "CONTAIN"]
    elif severity == "HIGH":
        actions = ["REVIEW", "ESCALATE"]
    else:
        actions = ["REVIEW"]

    return {
        "incident_id": incident.get("incident_id"),
        "planned_actions": actions,
        "execution_mode": "PLAN_ONLY",
        "executed": False,
        "secret_values_exposed": False,
    }


def validate_plan(plan: Mapping) -> bool:
    actions = plan.get("planned_actions", [])
    return all(action in ALLOWED_ACTIONS for action in actions)
