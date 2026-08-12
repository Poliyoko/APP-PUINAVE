from typing import Mapping

def assess_failover(profile: Mapping) -> dict:
    checks = {
        "approval_required": bool(profile.get("approval_required")),
        "prechecks_required": bool(profile.get("prechecks_required")),
        "rollback_required": bool(profile.get("rollback_required")),
        "evidence_required": bool(profile.get("evidence_required")),
        "manual_activation": bool(profile.get("manual_activation")),
    }
    return {"valid": all(checks.values()), **checks, "failover_executed": False, "traffic_shifted": False}
