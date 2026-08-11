from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .alerting import build_alert
from .correlation import correlate
from .incident import create_incident
from .integrity import build_chain
from .models import Control
from .response import plan_response, validate_plan


class EventCorrelationAuditor:
    def __init__(self, root: Path, source_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.source_paths = list(source_paths)

    def assess(self) -> dict:
        synthetic_events = [
            {
                "category": "AUTH",
                "source": "api",
                "severity": "HIGH",
                "fingerprint": "FP-A",
            },
            {
                "category": "AUTH",
                "source": "api",
                "severity": "HIGH",
                "fingerprint": "FP-B",
            },
            {
                "category": "AUDIT",
                "source": "repository",
                "severity": "LOW",
                "fingerprint": "FP-C",
            },
        ]

        correlations = correlate(synthetic_events)
        incidents = [create_incident(item) for item in correlations]
        alerts = [build_alert(item) for item in incidents]
        plans = [plan_response(item) for item in incidents]
        chain = build_chain(correlations + incidents + alerts + plans)

        controls = [
            Control(
                "IR-CORRELATION",
                "Deterministic event correlation",
                len(correlations) == 2 and all(c.get("correlation_id") for c in correlations),
                True,
                True,
                "Event correlation engine produced deterministic grouped records.",
            ),
            Control(
                "IR-INCIDENT",
                "Incident generation and lifecycle",
                len(incidents) == len(correlations)
                and all(i.get("status") == "DETECTED" for i in incidents),
                True,
                True,
                "Incident records created from correlations.",
            ),
            Control(
                "IR-ALERTING",
                "Safe alerting policy",
                all(a.get("sent") is False for a in alerts)
                and all(a.get("delivery_mode") == "EVIDENCE_ONLY" for a in alerts),
                True,
                True,
                "Alerts are generated as evidence only; no delivery performed by gate.",
            ),
            Control(
                "IR-RESPONSE",
                "Controlled response planning",
                all(validate_plan(p) for p in plans)
                and all(p.get("executed") is False for p in plans),
                True,
                True,
                "Response plans validated without execution.",
            ),
            Control(
                "IR-INTEGRITY",
                "Correlation and incident evidence integrity",
                len(chain) == len(correlations + incidents + alerts + plans)
                and all(item.get("sha256") for item in chain),
                True,
                True,
                "SHA-256 chain covers correlation, incident, alert and response records.",
            ),
            Control(
                "IR-SECRET-SAFETY",
                "No secret values in incident evidence",
                all(item.get("secret_values_exposed") is False for item in correlations + incidents + alerts + plans),
                True,
                True,
                "Incident evidence uses metadata and fingerprints only.",
            ),
        ]

        failed = [
            c.control_id for c in controls
            if c.blocking and c.applicable and not c.passed
        ]

        return {
            "status": "INCIDENT_RESPONSE_GATE_PASS" if not failed else "INCIDENT_RESPONSE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [c.__dict__ for c in controls],
            "correlations": correlations,
            "incidents": incidents,
            "alerts": alerts,
            "response_plans": plans,
            "integrity_chain": chain,
            "alert_sent": False,
            "incident_action_executed": False,
            "webhook_called": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
