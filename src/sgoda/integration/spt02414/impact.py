from __future__ import annotations
from typing import Mapping


def assess_impact(profile: Mapping) -> dict:
    confidentiality = int(profile.get("confidentiality", 0))
    integrity = int(profile.get("integrity", 0))
    availability = int(profile.get("availability", 0))
    cultural = int(profile.get("cultural", 0))
    institutional = int(profile.get("institutional", 0))

    values = [confidentiality, integrity, availability, cultural, institutional]
    valid = all(1 <= value <= 5 for value in values)
    score = max(values) if valid else 0

    return {
        "valid": valid,
        "confidentiality": confidentiality,
        "integrity": integrity,
        "availability": availability,
        "cultural": cultural,
        "institutional": institutional,
        "impact_score": score,
        "production_data_modified": False,
        "secret_values_exposed": False,
    }
