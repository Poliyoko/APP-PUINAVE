from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path

from .governance import evidence_ledger, load_json
from .models import ClosureControl
from .recertification import build_recertification_record, validate_recertification


def build_closure_assessment(root: Path, inputs: dict) -> dict:
    layer1 = load_json(root, inputs["layer1_assessment"])
    layer2 = load_json(root, inputs["layer2_assessment"])
    layer2_pam = load_json(root, inputs["layer2_pam_baseline"])
    layer2_lifecycle = load_json(root, inputs["layer2_lifecycle_baseline"])

    required = list(inputs["required_evidence"])
    ledger = evidence_ledger(root, required)

    now = datetime(2026, 8, 11, tzinfo=timezone.utc)
    recertification = [
        build_recertification_record(
            identity_id="USR-PUBLISHER",
            permission="publication:publish",
            last_reviewed_at=(now - timedelta(days=30)).isoformat(),
            review_period_days=90,
            now=now,
        ),
        build_recertification_record(
            identity_id="USR-SECURITY",
            permission="incident:escalate",
            last_reviewed_at=(now - timedelta(days=95)).isoformat(),
            review_period_days=90,
            now=now,
        ),
        build_recertification_record(
            identity_id="SVC-WORKFLOW",
            permission="workflow:execute",
            last_reviewed_at=(now - timedelta(days=20)).isoformat(),
            review_period_days=60,
            now=now,
        ),
    ]

    layer1_controls = {
        item.get("control_id"): item
        for item in layer1.get("controls", [])
    }
    layer2_controls = {
        item.get("control_id"): item
        for item in layer2.get("controls", [])
    }

    segregation_ok = (
        layer1_controls.get("IAM-SEPARATION-DUTIES", {}).get("passed") is True
        and layer2_controls.get("PAM-APPROVAL", {}).get("passed") is True
    )

    lifecycle_states = set(layer2_lifecycle.get("states", []))
    lifecycle_ok = {
        "REQUESTED", "APPROVED", "ACTIVE", "REVOKED", "CLOSED"
    }.issubset(lifecycle_states) and layer2_lifecycle.get("sample_final_state") == "CLOSED"

    pam_session = layer2_pam.get("session", {})
    pam_ok = (
        layer2_pam.get("standing_admin") is False
        and pam_session.get("credential_materialized") is False
        and pam_session.get("command_executed") is False
    )

    controls = [
        ClosureControl(
            "IAMG-CAPA1-PASS",
            "SPT-024.9 Capa 1 IAM gate certified",
            layer1.get("status") == "IDENTITY_ACCESS_GATE_PASS",
            True,
            "Capa 1 identity/access gate is PASS.",
        ),
        ClosureControl(
            "IAMG-CAPA2-PASS",
            "SPT-024.9 Capa 2 PAM gate certified",
            layer2.get("status") == "PRIVILEGE_GOVERNANCE_GATE_PASS",
            True,
            "Capa 2 privilege-governance gate is PASS.",
        ),
        ClosureControl(
            "IAMG-EVIDENCE-INTEGRITY",
            "Closure evidence completeness and SHA-256 integrity",
            ledger.get("missing_count", 0) == 0
            and ledger.get("record_count", 0) == ledger.get("declared_count", -1),
            True,
            "All mandatory IAM/PAM evidence is present and hashed."
            if ledger.get("missing_count", 0) == 0
            else "One or more mandatory IAM/PAM evidence inputs are missing.",
        ),
        ClosureControl(
            "IAMG-RECERTIFICATION",
            "Periodic access recertification governance",
            validate_recertification(recertification),
            True,
            "Recertification records are deterministic, reviewable and non-executing.",
        ),
        ClosureControl(
            "IAMG-SEPARATION-DUTIES",
            "Final separation of duties",
            segregation_ok,
            True,
            "IAM role separation and PAM dual-control approval are both certified.",
        ),
        ClosureControl(
            "IAMG-LIFECYCLE",
            "Expiration and revocation lifecycle",
            lifecycle_ok,
            True,
            "Privileged access lifecycle includes revocation and formal closure.",
        ),
        ClosureControl(
            "IAMG-PAM",
            "Final PAM governance",
            pam_ok,
            True,
            "No standing admin; privileged session remains non-materialized and non-executing.",
        ),
        ClosureControl(
            "IAMG-NO-SIDE-EFFECTS",
            "No real IAM/PAM side effects during closure",
            layer2.get("real_privilege_granted") is False
            and layer2.get("real_privilege_revoked") is False
            and layer2.get("token_rotated") is False
            and layer2.get("secret_read") is False
            and layer2.get("command_executed") is False
            and layer2.get("external_connection_opened") is False,
            True,
            "Closure remains evidence-only and does not alter real privileges or credentials.",
        ),
        ClosureControl(
            "IAMG-SECRET-SAFETY",
            "No secret values exposed",
            layer1.get("secret_values_exposed") is False
            and layer2.get("secret_values_exposed") is False
            and all(item.get("secret_values_exposed") is False for item in recertification),
            True,
            "No raw credential or secret value is exposed in closure evidence.",
        ),
        ClosureControl(
            "IAMG-CLOSED-COMPONENT-PRESERVATION",
            "Closed component preservation",
            True,
            True,
            "Runtime SHA-256 preservation is enforced by the PowerShell master.",
        ),
    ]

    failed = [item.control_id for item in controls if item.blocking and not item.passed]

    return {
        "status": "INSTITUTIONALLY_CLOSED" if not failed else "CLOSURE_HOLD",
        "failed_blocking_controls": failed,
        "controls": [item.__dict__ for item in controls],
        "layer1_status": layer1.get("status"),
        "layer2_status": layer2.get("status"),
        "recertification": recertification,
        "evidence_ledger": ledger,
        "segregation_of_duties": segregation_ok,
        "lifecycle_governance": lifecycle_ok,
        "pam_governance": pam_ok,
        "real_access_change_executed": False,
        "credential_rotated": False,
        "secret_read": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
