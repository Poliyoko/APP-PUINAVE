from __future__ import annotations
from typing import Mapping


def validate_change_governance(profile: Mapping) -> dict:
    change_id = str(profile.get("change_id", "")).strip()
    approved_by = str(profile.get("approved_by", "")).strip()
    rollback = bool(profile.get("rollback", False))
    evidence = bool(profile.get("evidence", False))
    risk_review = bool(profile.get("risk_review", False))

    valid = bool(change_id) and bool(approved_by) and rollback and evidence and risk_review

    return {
        "valid": valid,
        "change_id": change_id,
        "approval_present": bool(approved_by),
        "rollback": rollback,
        "evidence": evidence,
        "risk_review": risk_review,
        "production_change_executed": False,
        "secret_values_exposed": False,
    }
