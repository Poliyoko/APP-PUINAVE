from __future__ import annotations

from .models import AccessDecision, Identity
from .roles import (
    HUMAN_ONLY_ROLES,
    SERVICE_ALLOWED_ROLES,
    known_role,
    permissions_for_roles,
)


class RbacPolicy:
    def validate_identity(self, identity: Identity) -> tuple[bool, str]:
        if not identity.enabled:
            return False, "IDENTITY_DISABLED"

        if identity.identity_type not in {"HUMAN", "SERVICE"}:
            return False, "UNKNOWN_IDENTITY_TYPE"

        unknown = sorted(role for role in identity.roles if not known_role(role))
        if unknown:
            return False, "UNKNOWN_ROLE"

        if identity.identity_type == "SERVICE":
            if not identity.roles.issubset(SERVICE_ALLOWED_ROLES):
                return False, "SERVICE_ROLE_SCOPE_VIOLATION"

        if identity.identity_type == "HUMAN":
            if not identity.roles.issubset(HUMAN_ONLY_ROLES):
                return False, "HUMAN_ROLE_SCOPE_VIOLATION"

        return True, "IDENTITY_VALID"

    def decide(self, identity: Identity, resource: str, action: str) -> AccessDecision:
        valid, reason = self.validate_identity(identity)
        permission = f"{resource}:{action}"

        if not valid:
            return AccessDecision(
                allowed=False,
                reason=reason,
                identity_id=identity.identity_id,
                resource=resource,
                action=action,
            )

        permissions = permissions_for_roles(identity.roles)

        if permission not in permissions:
            return AccessDecision(
                allowed=False,
                reason="DENY_BY_DEFAULT",
                identity_id=identity.identity_id,
                resource=resource,
                action=action,
            )

        return AccessDecision(
            allowed=True,
            reason="RBAC_ALLOW",
            identity_id=identity.identity_id,
            resource=resource,
            action=action,
        )
