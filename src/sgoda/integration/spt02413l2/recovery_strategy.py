from typing import Mapping

def assess_recovery_strategy(profile: Mapping) -> dict:
    checks = {
        "documented": bool(profile.get("documented")),
        "prioritized": bool(profile.get("prioritized")),
        "dependencies_mapped": bool(profile.get("dependencies_mapped")),
        "runbook_defined": bool(profile.get("runbook_defined")),
        "owners_defined": bool(profile.get("owners_defined")),
    }
    return {"valid": all(checks.values()), **checks, "recovery_executed": False}
