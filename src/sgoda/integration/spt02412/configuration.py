from __future__ import annotations
from typing import Mapping


def configuration_governance(profile: Mapping) -> dict:
    versioned = bool(profile.get("versioned", False))
    reviewed = bool(profile.get("reviewed", False))
    integrity = bool(profile.get("integrity", False))
    rollback = bool(profile.get("rollback", False))
    secrets_indirect = bool(profile.get("secrets_indirect", False))

    valid = all((versioned, reviewed, integrity, rollback, secrets_indirect))

    return {
        "valid": valid,
        "versioned": versioned,
        "reviewed": reviewed,
        "integrity": integrity,
        "rollback": rollback,
        "secrets_indirect": secrets_indirect,
        "production_configuration_changed": False,
        "secret_values_exposed": False,
    }
