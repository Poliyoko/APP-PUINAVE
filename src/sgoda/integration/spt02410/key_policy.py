from __future__ import annotations
from typing import Mapping


ALLOWED_KEY_REFERENCE_PREFIXES = (
    "env:",
    "secretref:",
    "credentialref:",
    "vaultref:",
    "keystore:",
)

FORBIDDEN_KEY_MATERIAL_MARKERS = (
    "-----BEGIN PRIVATE KEY-----",
    "-----BEGIN RSA PRIVATE KEY-----",
    "-----BEGIN EC PRIVATE KEY-----",
)


def validate_key_reference(profile: Mapping) -> dict:
    reference = str(profile.get("key_reference", "")).strip()
    algorithm = str(profile.get("algorithm", "")).upper()
    purpose = str(profile.get("purpose", "")).upper()
    enabled = bool(profile.get("enabled", False))

    indirect = any(
        reference.lower().startswith(prefix)
        for prefix in ALLOWED_KEY_REFERENCE_PREFIXES
    )

    algorithm_ok = algorithm in {
        "AES-256-GCM",
        "CHACHA20-POLY1305",
        "ED25519",
        "RSA-3072",
        "SHA-256",
        "HMAC-SHA-256",
    }

    purpose_ok = purpose in {
        "ENCRYPTION",
        "SIGNING",
        "INTEGRITY",
        "AUTHENTICATION",
    }

    no_inline_key_material = not any(
        marker in reference
        for marker in FORBIDDEN_KEY_MATERIAL_MARKERS
    )

    valid = (
        enabled
        and indirect
        and algorithm_ok
        and purpose_ok
        and no_inline_key_material
    )

    return {
        "valid": valid,
        "credential_reference_indirect": indirect,
        "algorithm_allowed": algorithm_ok,
        "purpose_allowed": purpose_ok,
        "inline_key_material": not no_inline_key_material,
        "key_material_read": False,
        "secret_values_exposed": False,
    }
