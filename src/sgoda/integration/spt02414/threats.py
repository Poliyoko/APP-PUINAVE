from __future__ import annotations
from typing import Mapping


def assess_threat_governance(profile: Mapping) -> dict:
    checks = {
        "taxonomy_defined": bool(profile.get("taxonomy_defined", False)),
        "assets_mapped": bool(profile.get("assets_mapped", False)),
        "attack_vectors_reviewed": bool(profile.get("attack_vectors_reviewed", False)),
        "owners_defined": bool(profile.get("owners_defined", False)),
        "evidence_required": bool(profile.get("evidence_required", False)),
    }
    return {
        "valid": all(checks.values()),
        **checks,
        "active_probe_executed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
