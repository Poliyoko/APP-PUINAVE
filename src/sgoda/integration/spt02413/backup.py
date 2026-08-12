from __future__ import annotations
from typing import Mapping


def assess_backup_policy(profile: Mapping) -> dict:
    versioned = bool(profile.get("versioned", False))
    scheduled = bool(profile.get("scheduled", False))
    integrity = bool(profile.get("integrity", False))
    encrypted = bool(profile.get("encrypted", False))
    retention = bool(profile.get("retention", False))
    offsite_or_separated = bool(profile.get("separated_copy", False))

    valid = all((versioned, scheduled, integrity, encrypted, retention, offsite_or_separated))

    return {
        "valid": valid,
        "versioned": versioned,
        "scheduled": scheduled,
        "integrity": integrity,
        "encrypted": encrypted,
        "retention": retention,
        "separated_copy": offsite_or_separated,
        "backup_executed": False,
        "production_data_modified": False,
        "secret_values_exposed": False,
    }
