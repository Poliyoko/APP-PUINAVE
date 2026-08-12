from typing import Mapping

def assess_restore_test(profile: Mapping) -> dict:
    checks = {
        "isolated_test": bool(profile.get("isolated_test")),
        "integrity_verified": bool(profile.get("integrity_verified")),
        "evidence_required": bool(profile.get("evidence_required")),
        "rollback_defined": bool(profile.get("rollback_defined")),
    }
    return {"valid": all(checks.values()), **checks, "restore_executed": False, "production_data_modified": False}
