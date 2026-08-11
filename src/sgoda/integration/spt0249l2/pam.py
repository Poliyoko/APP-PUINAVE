from __future__ import annotations
from typing import Mapping


PAM_REQUIRED_PREFIXES = (
    "publication:",
    "incident:",
    "workflow:",
    "database:",
    "repository:",
)


def requires_pam(permission: str) -> bool:
    return any(permission.startswith(prefix) for prefix in PAM_REQUIRED_PREFIXES)


def build_session_control(grant: Mapping) -> dict:
    permission = str(grant.get("permission", ""))
    pam_required = requires_pam(permission)

    return {
        "grant_id": grant.get("grant_id"),
        "permission": permission,
        "pam_required": pam_required,
        "session_mode": "JUST_IN_TIME" if pam_required else "STANDARD",
        "credential_materialized": False,
        "secret_read": False,
        "command_executed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
