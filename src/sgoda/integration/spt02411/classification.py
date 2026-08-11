from __future__ import annotations
from typing import Mapping


ALLOWED_CLASSES = frozenset({
    "PUBLIC",
    "INTERNAL",
    "CONFIDENTIAL",
    "RESTRICTED",
})


def classify_record(record: Mapping) -> dict:
    declared = str(record.get("classification", "")).upper()
    data_type = str(record.get("data_type", "")).upper()

    valid_class = declared in ALLOWED_CLASSES

    sensitive = declared in {"CONFIDENTIAL", "RESTRICTED"} or data_type in {
        "PERSONAL_DATA",
        "CREDENTIAL",
        "AUTH_TOKEN",
        "LEXICAL_RESTRICTED",
        "AUDIT_SENSITIVE",
    }

    return {
        "valid": valid_class,
        "classification": declared,
        "data_type": data_type,
        "sensitive": sensitive,
        "requires_access_control": sensitive,
        "requires_retention_policy": True,
        "secret_values_exposed": False,
    }
