from __future__ import annotations
from typing import Mapping


def assess_contingency_policy(profile: Mapping) -> dict:
    roles_defined = bool(profile.get("roles_defined", False))
    escalation = bool(profile.get("escalation", False))
    communication = bool(profile.get("communication", False))
    activation_criteria = bool(profile.get("activation_criteria", False))
    evidence = bool(profile.get("evidence", False))
    periodic_review = bool(profile.get("periodic_review", False))

    valid = all((
        roles_defined,
        escalation,
        communication,
        activation_criteria,
        evidence,
        periodic_review,
    ))

    return {
        "valid": valid,
        "roles_defined": roles_defined,
        "escalation": escalation,
        "communication": communication,
        "activation_criteria": activation_criteria,
        "evidence": evidence,
        "periodic_review": periodic_review,
        "contingency_activated": False,
        "notification_sent": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
