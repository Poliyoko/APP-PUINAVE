from __future__ import annotations
from typing import Mapping


def assess_vulnerability_governance(profile: Mapping) -> dict:
    checks = {
        "inventory_required": bool(profile.get("inventory_required", False)),
        "severity_model_defined": bool(profile.get("severity_model_defined", False)),
        "remediation_owner_required": bool(profile.get("remediation_owner_required", False)),
        "sla_defined": bool(profile.get("sla_defined", False)),
        "evidence_required": bool(profile.get("evidence_required", False)),
    }
    return {
        "valid": all(checks.values()),
        **checks,
        "scanner_executed": False,
        "package_changed": False,
        "production_changed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
