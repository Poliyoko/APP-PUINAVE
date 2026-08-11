from __future__ import annotations
from typing import Mapping


ALLOWED_SERVICE_ROLES = frozenset({
    "SERVICE_WORKFLOW",
})

DISALLOWED_HUMAN_ROLES = frozenset({
    "PUBLISHER",
    "SECURITY_OPERATOR",
    "AUDITOR",
    "LEXICAL_EDITOR",
    "LEXICAL_READER",
})


def validate_service_identity(identity: Mapping) -> dict:
    identity_type = str(identity.get("identity_type", "")).upper()
    roles = frozenset(identity.get("roles", ()))
    owner = str(identity.get("owner", "")).strip()
    credential_reference = str(identity.get("credential_reference", ""))

    ref_ok = credential_reference.lower().startswith(
        ("env:", "secretref:", "credentialref:", "vaultref:")
    )

    role_ok = (
        bool(roles)
        and roles.issubset(ALLOWED_SERVICE_ROLES)
        and roles.isdisjoint(DISALLOWED_HUMAN_ROLES)
    )

    valid = (
        identity_type == "SERVICE"
        and bool(owner)
        and ref_ok
        and role_ok
    )

    return {
        "valid": valid,
        "owner_present": bool(owner),
        "credential_reference_indirect": ref_ok,
        "role_scope_valid": role_ok,
        "secret_values_exposed": False,
    }
