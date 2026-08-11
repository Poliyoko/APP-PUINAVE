from __future__ import annotations

ROLE_PERMISSIONS = {
    "LEXICAL_READER": frozenset({
        "lexical:read",
        "catalog:read",
    }),
    "LEXICAL_EDITOR": frozenset({
        "lexical:read",
        "lexical:create",
        "lexical:update",
        "catalog:read",
    }),
    "AUDITOR": frozenset({
        "audit:read",
        "evidence:read",
        "security:assessment:read",
    }),
    "PUBLISHER": frozenset({
        "publication:prepare",
        "publication:publish",
        "release:read",
    }),
    "SECURITY_OPERATOR": frozenset({
        "security:assessment:read",
        "incident:read",
        "incident:triage",
        "incident:escalate",
    }),
    "SERVICE_WORKFLOW": frozenset({
        "workflow:execute",
        "workflow:read",
    }),
}

HIGH_RISK_PERMISSIONS = frozenset({
    "publication:publish",
    "incident:escalate",
    "workflow:execute",
})

SERVICE_ALLOWED_ROLES = frozenset({
    "SERVICE_WORKFLOW",
})

HUMAN_ONLY_ROLES = frozenset({
    "LEXICAL_READER",
    "LEXICAL_EDITOR",
    "AUDITOR",
    "PUBLISHER",
    "SECURITY_OPERATOR",
})


def permissions_for_roles(roles):
    permissions = set()
    for role in roles:
        permissions.update(ROLE_PERMISSIONS.get(role, frozenset()))
    return frozenset(permissions)


def known_role(role: str) -> bool:
    return role in ROLE_PERMISSIONS
