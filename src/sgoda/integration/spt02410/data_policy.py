from __future__ import annotations
from typing import Mapping


SENSITIVE_CLASSES = frozenset({
    "CREDENTIAL",
    "AUTH_TOKEN",
    "API_SECRET",
    "PRIVATE_KEY",
    "PERSONAL_DATA",
    "LEXICAL_RESTRICTED",
    "AUDIT_SENSITIVE",
})


def classify_record(record: Mapping) -> dict:
    declared = str(record.get("classification", "PUBLIC")).upper()
    sensitive = declared in SENSITIVE_CLASSES

    required_protection = "ENCRYPT_AT_REST_AND_IN_TRANSIT" if sensitive else "INTEGRITY_ONLY"

    return {
        "classification": declared,
        "sensitive": sensitive,
        "required_protection": required_protection,
        "plaintext_persistence_allowed": not sensitive,
        "secret_values_exposed": False,
    }


def validate_storage_policy(record: Mapping) -> dict:
    classification = classify_record(record)
    encrypted_at_rest = bool(record.get("encrypted_at_rest", False))
    encrypted_in_transit = bool(record.get("encrypted_in_transit", False))

    if classification["sensitive"]:
        valid = encrypted_at_rest and encrypted_in_transit
    else:
        valid = True

    return {
        "valid": valid,
        **classification,
        "encrypted_at_rest": encrypted_at_rest,
        "encrypted_in_transit": encrypted_in_transit,
    }
