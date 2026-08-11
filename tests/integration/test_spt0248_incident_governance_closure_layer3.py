import json
from pathlib import Path

from sgoda.integration.spt0248l3.escalation import escalation_rule
from sgoda.integration.spt0248l3.service import IncidentGovernanceClosureService


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def fixture(tmp_path):
    l1 = "l1/assessment.json"
    l2 = "l2/assessment.json"
    incident = "l2/incident.json"
    e1 = "l1/evidence.json"
    e2 = "l2/evidence.json"

    write_json(tmp_path / l1, {
        "status": "SECURITY_MONITORING_GATE_PASS",
        "secret_values_exposed": False,
    })

    write_json(tmp_path / l2, {
        "status": "INCIDENT_RESPONSE_GATE_PASS",
        "alert_sent": False,
        "incident_action_executed": False,
        "webhook_called": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    })

    write_json(tmp_path / incident, {
        "incidents": [
            {
                "incident_id": "INC-1",
                "severity": "HIGH",
                "event_count": 2,
            }
        ]
    })

    write_json(tmp_path / e1, {"ok": True})
    write_json(tmp_path / e2, {"ok": True})

    inputs = {
        "layer1_assessment": l1,
        "layer2_assessment": l2,
        "layer2_incident_baseline": incident,
        "required_evidence": [l1, l2, incident, e1, e2],
    }

    return inputs


def test_closure_passes(tmp_path):
    result = IncidentGovernanceClosureService(tmp_path).close(fixture(tmp_path))
    assert result["status"] == "INSTITUTIONALLY_CLOSED"
    assert result["failed_blocking_controls"] == []


def test_missing_evidence_blocks(tmp_path):
    inputs = fixture(tmp_path)
    inputs["required_evidence"].append("missing.json")
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-EVIDENCE-INTEGRITY" in result["failed_blocking_controls"]


def test_layer1_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    write_json(tmp_path / inputs["layer1_assessment"], {
        "status": "SECURITY_MONITORING_GATE_HOLD",
        "secret_values_exposed": False,
    })
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-CAPA1-PASS" in result["failed_blocking_controls"]


def test_layer2_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["status"] = "INCIDENT_RESPONSE_GATE_HOLD"
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-CAPA2-PASS" in result["failed_blocking_controls"]


def test_secret_exposure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["secret_values_exposed"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-SECRET-SAFETY" in result["failed_blocking_controls"]


def test_side_effect_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["alert_sent"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-NO-SIDE-EFFECTS" in result["failed_blocking_controls"]


def test_escalation_levels():
    assert escalation_rule("LOW", 1)["escalation_level"] == "L1"
    assert escalation_rule("HIGH", 1)["escalation_level"] == "L2"
    assert escalation_rule("CRITICAL", 1)["escalation_level"] == "L3"
    assert escalation_rule("LOW", 10)["escalation_level"] == "L3"
