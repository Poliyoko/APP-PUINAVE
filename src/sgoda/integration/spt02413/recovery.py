from __future__ import annotations
from typing import Mapping


def assess_recovery_policy(profile: Mapping) -> dict:
    documented = bool(profile.get("documented", False))
    tested = bool(profile.get("tested", False))
    rto_defined = bool(profile.get("rto_defined", False))
    rpo_defined = bool(profile.get("rpo_defined", False))
    rollback = bool(profile.get("rollback", False))
    evidence = bool(profile.get("evidence", False))

    valid = all((documented, tested, rto_defined, rpo_defined, rollback, evidence))

    return {
        "valid": valid,
        "documented": documented,
        "tested": tested,
        "rto_defined": rto_defined,
        "rpo_defined": rpo_defined,
        "rollback": rollback,
        "evidence": evidence,
        "restore_executed": False,
        "failover_executed": False,
        "production_data_modified": False,
        "secret_values_exposed": False,
    }
