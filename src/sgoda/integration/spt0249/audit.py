from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .authn import validate_authentication_profile
from .least_privilege import validate_role_catalog
from .models import Identity, SecurityControl
from .policy import RbacPolicy


class IdentityAccessSecurityAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        policy = RbacPolicy()

        reader = Identity(
            identity_id="USR-READER",
            identity_type="HUMAN",
            roles=frozenset({"LEXICAL_READER"}),
        )

        editor = Identity(
            identity_id="USR-EDITOR",
            identity_type="HUMAN",
            roles=frozenset({"LEXICAL_EDITOR"}),
        )

        publisher = Identity(
            identity_id="USR-PUBLISHER",
            identity_type="HUMAN",
            roles=frozenset({"PUBLISHER"}),
        )

        security = Identity(
            identity_id="USR-SECURITY",
            identity_type="HUMAN",
            roles=frozenset({"SECURITY_OPERATOR"}),
        )

        service = Identity(
            identity_id="SVC-WORKFLOW",
            identity_type="SERVICE",
            roles=frozenset({"SERVICE_WORKFLOW"}),
        )

        unknown = Identity(
            identity_id="USR-UNKNOWN",
            identity_type="HUMAN",
            roles=frozenset({"UNKNOWN_ROLE"}),
        )

        decisions = {
            "reader_read": policy.decide(reader, "lexical", "read"),
            "reader_publish": policy.decide(reader, "publication", "publish"),
            "editor_update": policy.decide(editor, "lexical", "update"),
            "publisher_publish": policy.decide(publisher, "publication", "publish"),
            "publisher_incident": policy.decide(publisher, "incident", "escalate"),
            "security_incident": policy.decide(security, "incident", "escalate"),
            "security_publish": policy.decide(security, "publication", "publish"),
            "service_execute": policy.decide(service, "workflow", "execute"),
            "service_publish": policy.decide(service, "publication", "publish"),
            "unknown_read": policy.decide(unknown, "lexical", "read"),
        }

        human_auth = validate_authentication_profile({
            "identity_type": "HUMAN",
            "enabled": True,
            "credential_reference": "env:SGODA_USER_CREDENTIAL",
            "factors": ["MFA"],
        })

        service_auth = validate_authentication_profile({
            "identity_type": "SERVICE",
            "enabled": True,
            "credential_reference": "secretref:SGODA_WORKFLOW_TOKEN",
            "factors": ["WORKLOAD_IDENTITY"],
        })

        least = validate_role_catalog()

        controls = [
            SecurityControl(
                "IAM-DENY-DEFAULT",
                "Deny by default",
                decisions["reader_publish"].allowed is False
                and decisions["service_publish"].allowed is False
                and decisions["unknown_read"].allowed is False,
                True,
                True,
                "Unauthorized and unknown-role access is denied.",
            ),
            SecurityControl(
                "IAM-RBAC",
                "Role-based access control",
                decisions["reader_read"].allowed is True
                and decisions["editor_update"].allowed is True
                and decisions["publisher_publish"].allowed is True
                and decisions["security_incident"].allowed is True
                and decisions["service_execute"].allowed is True,
                True,
                True,
                "Authorized role/action combinations are explicitly allowed.",
            ),
            SecurityControl(
                "IAM-LEAST-PRIVILEGE",
                "Least privilege",
                least["least_privilege_pass"] is True,
                True,
                True,
                "Role catalog contains no wildcard permissions and passes least-privilege rules.",
            ),
            SecurityControl(
                "IAM-SEPARATION-DUTIES",
                "Separation of duties",
                decisions["publisher_incident"].allowed is False
                and decisions["security_publish"].allowed is False
                and least["separation_of_duties"] is True,
                True,
                True,
                "Publishing and security escalation duties are separated.",
            ),
            SecurityControl(
                "IAM-SERVICE-IDENTITY",
                "Service identity confinement",
                decisions["service_execute"].allowed is True
                and decisions["service_publish"].allowed is False,
                True,
                True,
                "Service identities are confined to service-specific roles.",
            ),
            SecurityControl(
                "IAM-AUTHN",
                "Authentication profile requirements",
                human_auth["valid"] is True
                and service_auth["valid"] is True,
                True,
                True,
                "Human and service authentication profiles satisfy factor and indirection requirements.",
            ),
            SecurityControl(
                "IAM-SECRET-INDIRECTION",
                "Credential secret indirection",
                human_auth["credential_reference_indirect"] is True
                and service_auth["credential_reference_indirect"] is True
                and human_auth["secret_values_exposed"] is False
                and service_auth["secret_values_exposed"] is False,
                True,
                True,
                "Credential references are indirect; raw secret values are not persisted.",
            ),
        ]

        failed = [
            c.control_id
            for c in controls
            if c.blocking and c.applicable and not c.passed
        ]

        return {
            "status": "IDENTITY_ACCESS_GATE_PASS" if not failed else "IDENTITY_ACCESS_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [c.__dict__ for c in controls],
            "least_privilege": least,
            "authentication": {
                "human": human_auth,
                "service": service_auth,
            },
            "decisions": {
                key: value.__dict__
                for key, value in decisions.items()
            },
            "discovered_identity_access_surfaces": len(self.discovered_paths),
            "password_changed": False,
            "token_rotated": False,
            "os_permission_changed": False,
            "database_role_changed": False,
            "github_permission_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
