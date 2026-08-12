from __future__ import annotations
from typing import Mapping


def validate_secure_baseline(profile: Mapping) -> dict:
    required = (
        "versioned",
        "reviewed",
        "integrity_protected",
        "rollback_ready",
        "least_exposure",
        "secret_indirection",
    )
    values = {key: bool(profile.get(key, False)) for key in required}
    valid = all(values.values())

    return {
        "valid": valid,
        "controls": values,
        "production_configuration_changed": False,
        "service_restarted": False,
        "secret_values_exposed": False,
    }
