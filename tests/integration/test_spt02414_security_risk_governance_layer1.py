from sgoda.integration.spt02414.impact import assess_impact
from sgoda.integration.spt02414.risk import assess_risk
from sgoda.integration.spt02414.service import SecurityRiskGovernanceService
from sgoda.integration.spt02414.threats import assess_threat_governance
from sgoda.integration.spt02414.treatment import assess_treatment
from sgoda.integration.spt02414.vulnerabilities import assess_vulnerability_governance


def test_threat_governance_passes():
    result = assess_threat_governance({
        "taxonomy_defined": True,
        "assets_mapped": True,
        "attack_vectors_reviewed": True,
        "owners_defined": True,
        "evidence_required": True,
    })
    assert result["valid"] is True


def test_vulnerability_governance_passes():
    result = assess_vulnerability_governance({
        "inventory_required": True,
        "severity_model_defined": True,
        "remediation_owner_required": True,
        "sla_defined": True,
        "evidence_required": True,
    })
    assert result["valid"] is True


def test_impact_supports_cultural_dimension():
    result = assess_impact({
        "confidentiality": 4,
        "integrity": 4,
        "availability": 4,
        "cultural": 5,
        "institutional": 4,
    })
    assert result["valid"] is True
    assert result["impact_score"] == 5


def test_risk_high_or_critical_is_calculated():
    result = assess_risk({"likelihood": 4, "impact": 5})
    assert result["risk_level"] == "CRITICAL"


def test_treatment_requires_residual_review():
    result = assess_treatment({
        "treatment": "MITIGATE",
        "owner": "OWNER",
        "due_date": "GOVERNED",
        "approval_required": True,
        "residual_risk_review": False,
        "evidence_required": True,
    })
    assert result["valid"] is False


def test_full_gate_passes(tmp_path):
    result = SecurityRiskGovernanceService(tmp_path, ["src/api.py", "config/security.json"]).assess()
    assert result["status"] == "SECURITY_RISK_GOVERNANCE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_twelve_controls(tmp_path):
    result = SecurityRiskGovernanceService(tmp_path, []).assess()
    assert len(result["controls"]) == 12


def test_no_active_probe(tmp_path):
    result = SecurityRiskGovernanceService(tmp_path, []).assess()
    assert result["active_probe_executed"] is False


def test_no_active_vulnerability_scan(tmp_path):
    result = SecurityRiskGovernanceService(tmp_path, []).assess()
    assert result["vulnerability_scan_executed"] is False


def test_no_production_change(tmp_path):
    result = SecurityRiskGovernanceService(tmp_path, []).assess()
    assert result["production_changed"] is False


def test_no_external_connection(tmp_path):
    result = SecurityRiskGovernanceService(tmp_path, []).assess()
    assert result["external_connection_opened"] is False


def test_no_secret_values_exposed(tmp_path):
    result = SecurityRiskGovernanceService(tmp_path, []).assess()
    assert result["secret_values_exposed"] is False
