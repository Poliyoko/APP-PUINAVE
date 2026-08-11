from __future__ import annotations
from typing import Mapping


ALLOWED_IDENTITY_TYPES = frozenset({
    "HUMAN",
    "SERVICE",
})

ALLOWED_CREDENTIAL_REFERENCE_PREFIXES = (
    "env:",
    "vaultref:",
    "secretref:",
    "credentialref:",
)


def validate_authentication_profile(profile: Mapping) -> dict:
    identity_type = str(profile.get("identity_type", "")).upper()
    enabled = bool(profile.get("enabled", False))
    credential_reference = str(profile.get("credential_reference", ""))
    factors = tuple(profile.get("factors", ()))

    ref_is_indirect = any(
        credential_reference.lower().startswith(prefix)
        for prefix in ALLOWED_CREDENTIAL_REFERENCE_PREFIXES
    )

    factor_set = {str(x).upper() for x in factors}

    if identity_type == "HUMAN":
        factor_policy = bool(factor_set.intersection({"PASSWORD", "PASSKEY", "MFA", "OIDC"}))
    elif identity_type == "SERVICE":
        factor_policy = bool(factor_set.intersection({"SERVICE_TOKEN", "OIDC", "WORKLOAD_IDENTITY"}))
    else:
        factor_policy = False

    valid = (
        identity_type in ALLOWED_IDENTITY_TYPES
        and enabled
        and ref_is_indirect
        and factor_policy
    )

    return {
        "valid": valid,
        "identity_type": identity_type,
        "enabled": enabled,
        "credential_reference_indirect": ref_is_indirect,
        "factor_policy": factor_policy,
        "secret_values_exposed": False,
    }
