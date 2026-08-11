from __future__ import annotations
from typing import Mapping


def build_revocation_record(profile: Mapping) -> dict:
    key_id = str(profile.get("key_id", "")).strip()
    version = int(profile.get("version", 0))
    reason = str(profile.get("reason", "")).strip()
    approved_by = str(profile.get("approved_by", "")).strip()

    valid = (
        bool(key_id)
        and version > 0
        and len(reason) >= 10
        and bool(approved_by)
    )

    return {
        "valid": valid,
        "key_id": key_id,
        "version": version,
        "reason": reason,
        "approved_by": approved_by,
        "revocation_executed": False,
        "key_material_read": False,
        "secret_values_exposed": False,
    }
