from __future__ import annotations
from typing import Mapping


ALLOWED_PURPOSES = frozenset({
    "PRESERVATION",
    "TEACHING",
    "AUDIT",
    "SECURITY",
    "OPERATIONS",
})


def validate_purpose(profile: Mapping) -> dict:
    purpose = str(profile.get("purpose", "")).upper()
    declared = bool(profile.get("purpose_declared", False))
    access_limited = bool(profile.get("access_limited", False))
    disclosure_limited = bool(profile.get("disclosure_limited", False))

    valid = (
        declared
        and purpose in ALLOWED_PURPOSES
        and access_limited
        and disclosure_limited
    )

    return {
        "valid": valid,
        "purpose": purpose,
        "purpose_declared": declared,
        "access_limited": access_limited,
        "disclosure_limited": disclosure_limited,
        "external_disclosure_executed": False,
        "secret_values_exposed": False,
    }
