from sgoda.integration.spt02412l2.baseline import validate_secure_baseline
from sgoda.integration.spt02412l2.change_governance import validate_change_governance
from sgoda.integration.spt02412l2.port_governance import validate_port_governance
from sgoda.integration.spt02412l2.service_governance import validate_service_governance
from sgoda.integration.spt02412l2.service import InfrastructureHardeningGovernanceService


def test_secure_baseline_passes():
    result = validate_secure_baseline({
        "versioned": True,
        "reviewed": True,
        "integrity_protected": True,
        "rollback_ready": True,
        "least_exposure": True,
        "secret_indirection": True,
    })
    assert result["valid"] is True


def test_secure_baseline_requires_rollback():
    result = validate_secure_baseline({
        "versioned": True,
        "reviewed": True,
        "integrity_protected": True,
        "rollback_ready": False,
        "least_exposure": True,
        "secret_indirection": True,
    })
    assert result["valid"] is False


def test_service_governance_blocks_privileged_service():
    result = validate_service_governance({
        "enabled": True,
        "approved": True,
        "health_check": True,
        "privileged": True,
        "external": False,
    })
    assert result["valid"] is False


def test_service_governance_passes_non_privileged_service():
    result = validate_service_governance({
        "enabled": True,
        "approved": True,
        "health_check": True,
        "privileged": False,
        "external": False,
    })
    assert result["valid"] is True


def test_port_governance_passes_restricted_approved_port():
    result = validate_port_governance({
        "port": 443,
        "purpose": "secure endpoint",
        "approved": True,
        "restricted": True,
        "public": False,
    })
    assert result["valid"] is True


def test_port_governance_blocks_public_port():
    result = validate_port_governance({
        "port": 443,
        "purpose": "secure endpoint",
        "approved": True,
        "restricted": True,
        "public": True,
    })
    assert result["valid"] is False


def test_change_governance_requires_approval_and_rollback():
    result = validate_change_governance({
        "change_id": "CHG-1",
        "approved_by": "OWNER",
        "rollback": True,
        "evidence": True,
        "risk_review": True,
    })
    assert result["valid"] is True


def test_change_governance_blocks_without_risk_review():
    result = validate_change_governance({
        "change_id": "CHG-1",
        "approved_by": "OWNER",
        "rollback": True,
        "evidence": True,
        "risk_review": False,
    })
    assert result["valid"] is False


def test_full_gate_passes(tmp_path):
    result = InfrastructureHardeningGovernanceService(
        tmp_path,
        ["config/app.yaml", "src/api/main.py", "automation/n8n/workflows/a.json"],
    ).assess()
    assert result["status"] == "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_eleven_controls(tmp_path):
    result = InfrastructureHardeningGovernanceService(tmp_path, []).assess()
    assert len(result["controls"]) == 11


def test_full_gate_executes_no_real_changes(tmp_path):
    result = InfrastructureHardeningGovernanceService(tmp_path, []).assess()
    assert result["production_configuration_changed"] is False
    assert result["production_change_executed"] is False
    assert result["service_restarted"] is False
    assert result["port_opened"] is False
    assert result["firewall_changed"] is False


def test_full_gate_has_no_external_connection_or_secret_exposure(tmp_path):
    result = InfrastructureHardeningGovernanceService(tmp_path, []).assess()
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
