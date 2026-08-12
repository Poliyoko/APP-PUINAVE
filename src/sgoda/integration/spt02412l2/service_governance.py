from __future__ import annotations
from typing import Mapping


def validate_service_governance(profile: Mapping) -> dict:
    enabled = bool(profile.get("enabled", True))
    approved = bool(profile.get("approved", False))
    health_check = bool(profile.get("health_check", False))
    privileged = bool(profile.get("privileged", False))
    external = bool(profile.get("external", False))

    valid = approved and health_check and not privileged

    return {
        "valid": valid,
        "enabled": enabled,
        "approved": approved,
        "health_check": health_check,
        "privileged": privileged,
        "external": external,
        "service_started": False,
        "service_stopped": False,
        "service_restarted": False,
        "secret_values_exposed": False,
    }
