from __future__ import annotations
from typing import Mapping


def validate_port_governance(profile: Mapping) -> dict:
    port = int(profile.get("port", 0))
    purpose = str(profile.get("purpose", "")).strip()
    approved = bool(profile.get("approved", False))
    restricted = bool(profile.get("restricted", False))
    public = bool(profile.get("public", False))

    valid = 1 <= port <= 65535 and bool(purpose) and approved and restricted and not public

    return {
        "valid": valid,
        "port": port,
        "purpose_present": bool(purpose),
        "approved": approved,
        "restricted": restricted,
        "public": public,
        "port_opened": False,
        "firewall_changed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
