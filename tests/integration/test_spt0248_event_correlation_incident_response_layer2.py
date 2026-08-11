from pathlib import Path

from sgoda.integration.spt0248l2.alerting import build_alert
from sgoda.integration.spt0248l2.correlation import correlate
from sgoda.integration.spt0248l2.incident import create_incident, transition
from sgoda.integration.spt0248l2.integrity import build_chain
from sgoda.integration.spt0248l2.response import plan_response, validate_plan
from sgoda.integration.spt0248l2.service import EventCorrelationService


def test_correlation_groups_events():
    events = [
        {"category": "AUTH", "source": "api", "severity": "HIGH"},
        {"category": "AUTH", "source": "api", "severity": "HIGH"},
    ]
    result = correlate(events)
    assert len(result) == 1
    assert result[0]["event_count"] == 2
    assert result[0]["fingerprint"]


def test_incident_created_from_correlation():
    correlation = correlate([
        {"category": "AUTH", "source": "api", "severity": "HIGH"}
    ])[0]
    incident = create_incident(correlation)
    assert incident["status"] == "DETECTED"
    assert incident["incident_id"].startswith("INC-")


def test_incident_transition():
    correlation = correlate([
        {"category": "AUTH", "source": "api", "severity": "HIGH"}
    ])[0]
    incident = create_incident(correlation)
    incident = transition(incident, "TRIAGED")
    assert incident["status"] == "TRIAGED"


def test_high_incident_generates_unsent_alert():
    correlation = correlate([
        {"category": "AUTH", "source": "api", "severity": "HIGH"}
    ])[0]
    incident = create_incident(correlation)
    alert = build_alert(incident)
    assert alert["should_alert"] is True
    assert alert["sent"] is False
    assert alert["delivery_mode"] == "EVIDENCE_ONLY"


def test_response_plan_not_executed():
    correlation = correlate([
        {"category": "AUTH", "source": "api", "severity": "CRITICAL"}
    ])[0]
    incident = create_incident(correlation)
    plan = plan_response(incident)
    assert validate_plan(plan)
    assert plan["executed"] is False
    assert plan["execution_mode"] == "PLAN_ONLY"


def test_integrity_chain_links_records():
    chain = build_chain([
        {"type": "correlation"},
        {"type": "incident"},
        {"type": "alert"},
    ])
    assert len(chain) == 3
    assert chain[0]["previous_hash"] == ""
    assert chain[1]["previous_hash"] == chain[0]["sha256"]
    assert chain[2]["previous_hash"] == chain[1]["sha256"]


def test_service_gate_passes(tmp_path):
    result = EventCorrelationService(tmp_path, []).assess()
    assert result["status"] == "INCIDENT_RESPONSE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_no_operational_side_effects(tmp_path):
    result = EventCorrelationService(tmp_path, []).assess()
    assert result["alert_sent"] is False
    assert result["incident_action_executed"] is False
    assert result["webhook_called"] is False
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
