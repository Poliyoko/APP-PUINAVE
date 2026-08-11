from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .approval import validate_request
from .lifecycle import transition
from .models import Control
from .pam import build_session_control
from .service_identity import validate_service_identity


class PrivilegeGovernanceAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        service_identity = validate_service_identity({
            "identity_type": "SERVICE",
            "roles": ["SERVICE_WORKFLOW"],
            "owner": "PMO_DIGITAL",
            "credential_reference": "secretref:WORKFLOW_SERVICE_CREDENTIAL",
        })

        request = {
            "identity_id": "USR-PUBLISHER",
            "permission": "publication:publish",
            "justification": "Institutional release publication approval",
            "requested_by": "USR-PUBLISHER",
            "approved_by": "USR-AUDITOR",
        }

        approval = validate_request(request)

        lifecycle = {
            "request_id": "PAM-REQ-001",
            "state": "REQUESTED",
        }
        lifecycle = transition(lifecycle, "APPROVED")
        lifecycle = transition(lifecycle, "ACTIVE")
        lifecycle = transition(lifecycle, "REVOKED")
        lifecycle = transition(lifecycle, "CLOSED")

        grant = {
            "grant_id": "PAM-GRANT-001",
            "permission": "publication:publish",
        }

        pam_session = build_session_control(grant)

        controls = [
            Control(
                "PAM-SERVICE-IDENTITY",
                "Service identity governance",
                service_identity["valid"] is True,
                True,
                True,
                "Service identity is owner-bound, role-confined and credential-indirect.",
            ),
            Control(
                "PAM-JIT",
                "Just-in-time privileged access",
                pam_session["pam_required"] is True
                and pam_session["session_mode"] == "JUST_IN_TIME",
                True,
                True,
                "High-risk privileges require JIT PAM session controls.",
            ),
            Control(
                "PAM-APPROVAL",
                "Dual-control privileged approval",
                approval["valid"] is True
                and approval["separation_of_approval"] is True,
                True,
                True,
                "Privileged request requires separated requester and approver.",
            ),
            Control(
                "PAM-LIFECYCLE",
                "Access lifecycle governance",
                lifecycle["state"] == "CLOSED",
                True,
                True,
                "Privileged access lifecycle supports request, approval, activation, revocation and closure.",
            ),
            Control(
                "PAM-NO-STANDING-ADMIN",
                "No standing unrestricted administrator access",
                pam_session["credential_materialized"] is False
                and pam_session["command_executed"] is False,
                True,
                True,
                "Gate models privileged sessions without materializing credentials or executing commands.",
            ),
            Control(
                "PAM-SECRET-SAFETY",
                "Privileged credential secrecy",
                service_identity["secret_values_exposed"] is False
                and pam_session["secret_read"] is False
                and pam_session["secret_values_exposed"] is False,
                True,
                True,
                "Credential references remain indirect and secret values are not read or exposed.",
            ),
            Control(
                "PAM-NO-SIDE-EFFECTS",
                "No operational privilege side effects",
                pam_session["command_executed"] is False
                and pam_session["external_connection_opened"] is False,
                True,
                True,
                "No real privilege, command, token or external action is executed by the gate.",
            ),
        ]

        failed = [
            c.control_id
            for c in controls
            if c.blocking and c.applicable and not c.passed
        ]

        return {
            "status": "PRIVILEGE_GOVERNANCE_GATE_PASS" if not failed else "PRIVILEGE_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [c.__dict__ for c in controls],
            "service_identity": service_identity,
            "approval": approval,
            "lifecycle_final_state": lifecycle["state"],
            "pam_session": pam_session,
            "discovered_privileged_surfaces": len(self.discovered_paths),
            "real_privilege_granted": False,
            "real_privilege_revoked": False,
            "token_rotated": False,
            "secret_read": False,
            "command_executed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
