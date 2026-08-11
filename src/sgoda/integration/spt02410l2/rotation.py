from __future__ import annotations
from typing import Mapping


def build_rotation_plan(profile: Mapping) -> dict:
    key_id = str(profile.get("key_id", ""))
    current_version = int(profile.get("current_version", 0))
    interval_days = int(profile.get("rotation_interval_days", 0))
    approval_required = bool(profile.get("approval_required", True))

    valid = (
        bool(key_id)
        and current_version > 0
        and interval_days > 0
        and approval_required
    )

    return {
        "valid": valid,
        "key_id": key_id,
        "from_version": current_version,
        "to_version": current_version + 1,
        "rotation_interval_days": interval_days,
        "approval_required": approval_required,
        "rotation_executed": False,
        "key_material_read": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
