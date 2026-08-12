from __future__ import annotations
from typing import Mapping


ALLOWED = {"MITIGATE", "AVOID", "TRANSFER", "ACCEPT"}


def assess_treatment(profile: Mapping) -> dict:
    treatment = str(profile.get("treatment", "")).upper()
    owner = str(profile.get("owner", "")).strip()
    due_date = str(profile.get("due_date", "")).strip()
    approval = bool(profile.get("approval_required", False))
    residual_review = bool(profile.get("residual_risk_review", False))
    evidence = bool(profile.get("evidence_required", False))

    valid = (
        treatment in ALLOWED
        and bool(owner)
        and bool(due_date)
        and approval
        and residual_review
        and evidence
    )

    return {
        "valid": valid,
        "treatment": treatment,
        "owner_present": bool(owner),
        "due_date_present": bool(due_date),
        "approval_required": approval,
        "residual_risk_review": residual_review,
        "evidence_required": evidence,
        "treatment_executed": False,
        "production_changed": False,
        "secret_values_exposed": False,
    }
