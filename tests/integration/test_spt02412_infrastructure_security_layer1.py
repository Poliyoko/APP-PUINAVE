from sgoda.integration.spt02412.classifier import classify_surface
from sgoda.integration.spt02412.configuration import configuration_governance
from sgoda.integration.spt02412.exposure import assess_exposure
from sgoda.integration.spt02412.hardening import analyze_hardening
from sgoda.integration.spt02412.service import InfrastructureSecurityService


def test_classifier_configuration():
    assert classify_surface("config/app.yaml") == "CONFIGURATION"


def test_classifier_script():
    assert classify_surface("tools/hardening.ps1") == "SCRIPT"


def test_classifier_workflow():
    assert classify_surface(".github/workflows/security.yml") == "CI_CD"


def test_configuration_governance_passes():
    result = configuration_governance({
        "versioned": True,
        "reviewed": True,
        "integrity": True,
        "rollback": True,
        "secrets_indirect": True,
    })
    assert result["valid"] is True


def test_configuration_governance_requires_secret_indirection():
    result = configuration_governance({
        "versioned": True,
        "reviewed": True,
        "integrity": True,
        "rollback": True,
        "secrets_indirect": False,
    })
    assert result["valid"] is False


def test_hardening_is_non_destructive():
    result = analyze_hardening(["config/app.yaml"])
    assert result["production_configuration_changed"] is False
    assert result["service_restarted"] is False
    assert result["os_permission_changed"] is False


def test_exposure_is_non_destructive():
    result = assess_exposure(["src/api/main.py", "docker-compose.yml"])
    assert result["port_opened"] is False
    assert result["firewall_changed"] is False
    assert result["service_published"] is False


def test_full_gate_passes(tmp_path):
    result = InfrastructureSecurityService(
        tmp_path,
        ["config/app.yaml", "src/api/main.py", ".github/workflows/ci.yml"],
    ).assess()
    assert result["status"] == "INFRASTRUCTURE_SECURITY_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_nine_controls(tmp_path):
    result = InfrastructureSecurityService(tmp_path, []).assess()
    assert len(result["controls"]) == 9


def test_full_gate_no_real_changes(tmp_path):
    result = InfrastructureSecurityService(tmp_path, []).assess()
    assert result["production_configuration_changed"] is False
    assert result["service_restarted"] is False
    assert result["port_opened"] is False
    assert result["firewall_changed"] is False


def test_full_gate_no_external_connection_or_secret_exposure(tmp_path):
    result = InfrastructureSecurityService(tmp_path, []).assess()
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
