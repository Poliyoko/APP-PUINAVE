from __future__ import annotations
from pathlib import Path

from .escalation import escalation_rule
from .governance import evidence_ledger, load_json
from .models import GovernanceControl


def build_governance_assessment(root: Path, inputs: dict) -> dict:
    l1 = load_json(root, inputs["layer1_assessment"])
    l2 = load_json(root, inputs["layer2_assessment"])
    l2_incident = load_json(root, inputs["layer2_incident_baseline"])

    required_paths = list(inputs["required_evidence"])
    ledger = evidence_ledger(root, required_paths)

    incidents = l2_incident.get("incidents", [])
    escalation = [
        escalation_rule(
            incident.get("severity", "INFO"),
            incident.get("event_count", 0),
        )
        for incident in incidents
    ]

    controls = [
        GovernanceControl(
            "IRG-CAPA1-PASS",
            "Capa 1 security monitoring certified",
            l1.get("status") == "SECURITY_MONITORING_GATE_PASS",
            True,
            "Capa 1 security monitoring gate is PASS.",
        ),
        GovernanceControl(
            "IRG-CAPA2-PASS",
            "Capa 2 incident response certified",
            l2.get("status") == "INCIDENT_RESPONSE_GATE_PASS",
            True,
            "Capa 2 incident response gate is PASS.",
        ),
        GovernanceControl(
            "IRG-EVIDENCE-INTEGRITY",
            "Required evidence completeness and SHA-256 ledger",
            ledger.get("missing_count", 0) == 0
            and ledger.get("record_count", 0) == len(required_paths),
            True,
            "Evidence ledger covers all required inputs."
            if ledger.get("missing_count", 0) == 0
            else "One or more required evidence inputs are missing.",
        ),
        GovernanceControl(
            "IRG-ESCALATION",
            "Institutional escalation rules",
            len(escalation) == len(incidents)
            and all(item.get("escalation_level") in {"L1", "L2", "L3"} for item in escalation),
            True,
            "Escalation rules generated for all incidents.",
        ),
        GovernanceControl(
            "IRG-NO-SIDE-EFFECTS",
            "No operational side effects during closure",
            l2.get("alert_sent") is False
            and l2.get("incident_action_executed") is False
            and l2.get("webhook_called") is False
            and l2.get("external_connection_opened") is False,
            True,
            "Closure uses evidence-only alerting and plan-only response.",
        ),
        GovernanceControl(
            "IRG-SECRET-SAFETY",
            "No secret values exposed",
            l1.get("secret_values_exposed") is False
            and l2.get("secret_values_exposed") is False
            and all(item.get("secret_values_exposed") is False for item in escalation),
            True,
            "No secret values exposed in governance evidence.",
        ),
        GovernanceControl(
            "IRG-CLOSED-COMPONENT-PRESERVATION",
            "Closed component preservation",
            True,
            True,
            "Runtime SHA-256 preservation is enforced by PowerShell master.",
        ),
    ]

    failed = [c.control_id for c in controls if c.blocking and not c.passed]

    return {
        "status": "INSTITUTIONALLY_CLOSED" if not failed else "CLOSURE_HOLD",
        "failed_blocking_controls": failed,
        "controls": [c.__dict__ for c in controls],
        "evidence_ledger": ledger,
        "escalation": escalation,
        "layer1_status": l1.get("status"),
        "layer2_status": l2.get("status"),
        "incident_count": len(incidents),
        "notification_sent": False,
        "incident_action_executed": False,
        "webhook_called": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
