from typing import Mapping

def assess_redundancy(profile: Mapping) -> dict:
    checks = {
        "failure_domain_separation": bool(profile.get("failure_domain_separation")),
        "dependency_redundancy": bool(profile.get("dependency_redundancy")),
        "capacity_defined": bool(profile.get("capacity_defined")),
        "health_criteria_defined": bool(profile.get("health_criteria_defined")),
    }
    return {"valid": all(checks.values()), **checks, "infrastructure_changed": False}
