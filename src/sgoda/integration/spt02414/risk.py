from __future__ import annotations
from typing import Mapping


def assess_risk(profile: Mapping) -> dict:
    likelihood = int(profile.get("likelihood", 0))
    impact = int(profile.get("impact", 0))

    valid = 1 <= likelihood <= 5 and 1 <= impact <= 5
    score = likelihood * impact if valid else 0

    if not valid:
        level = "INVALID"
    elif score >= 20:
        level = "CRITICAL"
    elif score >= 12:
        level = "HIGH"
    elif score >= 6:
        level = "MEDIUM"
    else:
        level = "LOW"

    return {
        "valid": valid,
        "likelihood": likelihood,
        "impact": impact,
        "risk_score": score,
        "risk_level": level,
    }
