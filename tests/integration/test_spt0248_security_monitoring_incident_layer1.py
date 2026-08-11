from pathlib import Path

from sgoda.integration.spt0248.detector import scan_sources
from sgoda.integration.spt0248.incident import new_incident, transition
from sgoda.integration.spt0248.integrity import build_hash_chain
from sgoda.integration.spt0248.service import SecurityMonitoringService


def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def controls(root, paths):
    result = SecurityMonitoringService(root, paths).assess()
    return {c["control_id"]: c for c in result["controls"]}, result


def test_empty_scope_passes(tmp_path):
    _, result = controls(tmp_path, [])
    assert result["status"] == "SECURITY_MONITORING_GATE_PASS"


def test_secret_logging_blocks(tmp_path):
    p = "src/a.py"
    write(tmp_path / p, 'logger.info("token=%s", token)\n')
    cmap, result = controls(tmp_path, [p])
    assert cmap["MON-SECRET-SAFETY"]["passed"] is False
    assert result["status"] == "SECURITY_MONITORING_GATE_HOLD"


def test_safe_logging_passes(tmp_path):
    p = "src/a.py"
    write(tmp_path / p, 'logger.info("security_event recorded")\n')
    cmap, result = controls(tmp_path, [p])
    assert cmap["MON-SECRET-SAFETY"]["passed"] is True
    assert result["status"] == "SECURITY_MONITORING_GATE_PASS"


def test_findings_do_not_expose_value(tmp_path):
    p = "src/a.py"
    write(tmp_path / p, 'print("password", password)\n')
    result = scan_sources(tmp_path, [p])
    assert result["secret_values_exposed"] is False
    assert result["findings"]
    assert all("value" not in f for f in result["findings"])


def test_hash_chain_is_linked():
    chain = build_hash_chain([
        {"event_type": "A"},
        {"event_type": "B"},
    ])
    assert len(chain) == 2
    assert chain[0]["previous_hash"] == ""
    assert chain[1]["previous_hash"] == chain[0]["sha256"]


def test_incident_lifecycle():
    incident = new_incident("INC-001", "HIGH", "api", "AUTH", "fingerprint-only")
    assert incident["status"] == "DETECTED"
    assert incident["fingerprint"]
    incident = transition(incident, "TRIAGED")
    assert incident["status"] == "TRIAGED"
    incident = transition(incident, "CLOSED")
    assert incident["status"] == "CLOSED"


def test_no_side_effects(tmp_path):
    _, result = controls(tmp_path, [])
    assert result["service_started"] is False
    assert result["external_connection_opened"] is False
    assert result["incident_action_executed"] is False
    assert result["secret_values_exposed"] is False
