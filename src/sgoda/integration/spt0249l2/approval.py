from __future__ import annotations
from typing import Mapping


HIGH_RISK_PERMISSIONS = frozenset({
    "publication:publish",
    "incident:escalate",
    "workflow:execute",
    "database:admin",
    "repository:admin",
})


def validate_request(request: Mapping) -> dict:
    identity_id = str(request.get("identity_id", ""))
    permission = str(request.get("permission", ""))
    justification = str(request.get("justification", "")).strip()
    requested_by = str(request.get("requested_by", ""))
    approved_by = str(request.get("approved_by", ""))

    high_risk = permission in HIGH_RISK_PERMISSIONS
    separation_ok = bool(requested_by) and bool(approved_by) and requested_by != approved_by

    valid = (
        bool(identity_id)
        and bool(permission)
        and len(justification) >= 10
        and separation_ok
    )

    return {
        "valid": valid,
        "high_risk": high_risk,
        "separation_of_approval": separation_ok,
        "secret_values_exposed": False,
    }
