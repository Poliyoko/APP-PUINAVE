from __future__ import annotations

from .roles import HIGH_RISK_PERMISSIONS, ROLE_PERMISSIONS


def validate_role_catalog() -> dict:
    wildcard_permissions = []
    empty_roles = []
    high_risk_roles = {}

    for role, permissions in ROLE_PERMISSIONS.items():
        if not permissions:
            empty_roles.append(role)

        for permission in permissions:
            if "*" in permission:
                wildcard_permissions.append(f"{role}:{permission}")

        high_risk = sorted(set(permissions).intersection(HIGH_RISK_PERMISSIONS))
        if high_risk:
            high_risk_roles[role] = high_risk

    separation_ok = (
        "publication:publish" not in ROLE_PERMISSIONS.get("SECURITY_OPERATOR", frozenset())
        and "incident:escalate" not in ROLE_PERMISSIONS.get("PUBLISHER", frozenset())
        and "workflow:execute" not in ROLE_PERMISSIONS.get("PUBLISHER", frozenset())
    )

    return {
        "wildcard_permissions": sorted(wildcard_permissions),
        "empty_roles": sorted(empty_roles),
        "high_risk_roles": high_risk_roles,
        "separation_of_duties": separation_ok,
        "least_privilege_pass": (
            not wildcard_permissions
            and not empty_roles
            and separation_ok
        ),
    }
