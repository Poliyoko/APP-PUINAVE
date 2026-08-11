from __future__ import annotations
from typing import Mapping


def validate_custody(profile: Mapping) -> dict:
    primary = str(profile.get("primary_custodian", "")).strip()
    secondary = str(profile.get("secondary_custodian", "")).strip()
    owner = str(profile.get("owner", "")).strip()
    recovery_authority = str(profile.get("recovery_authority", "")).strip()

    separation_ok = (
        bool(primary)
        and bool(secondary)
        and primary != secondary
        and primary != owner
        and secondary != owner
    )

    recovery_separated = bool(recovery_authority) and recovery_authority not in {
        primary,
        secondary,
        owner,
    }

    return {
        "valid": separation_ok and recovery_separated,
        "separation_of_custody": separation_ok,
        "recovery_authority_separated": recovery_separated,
        "key_material_read": False,
        "secret_values_exposed": False,
    }
