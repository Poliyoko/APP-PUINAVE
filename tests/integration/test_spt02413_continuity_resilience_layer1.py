from sgoda.integration.spt02413.backup import assess_backup_policy
from sgoda.integration.spt02413.recovery import assess_recovery_policy
from sgoda.integration.spt02413.availability import assess_availability_policy
from sgoda.integration.spt02413.contingency import assess_contingency_policy
from sgoda.integration.spt02413.service import ContinuityResilienceService


def test_backup_policy_passes_complete_profile():
    result = assess_backup_policy({
        "versioned": True,
        "scheduled": True,
        "integrity": True,
        "encrypted": True,
        "retention": True,
        "separated_copy": True,
    })
    assert result["valid"] is True


def test_backup_policy_requires_integrity():
    result = assess_backup_policy({
        "versioned": True,
        "scheduled": True,
        "integrity": False,
        "encrypted": True,
        "retention": True,
        "separated_copy": True,
    })
    assert result["valid"] is False


def test_recovery_policy_passes_complete_profile():
    result = assess_recovery_policy({
        "documented": True,
        "tested": True,
        "rto_defined": True,
        "rpo_defined": True,
        "rollback": True,
        "evidence": True,
    })
    assert result["valid"] is True


def test_recovery_policy_requires_rto_rpo():
    result = assess_recovery_policy({
        "documented": True,
        "tested": True,
        "rto_defined": False,
        "rpo_defined": True,
        "rollback": True,
        "evidence": True,
    })
    assert result["valid"] is False


def test_availability_policy_passes():
    result = assess_availability_policy({
        "health_monitoring": True,
        "dependency_inventory": True,
        "capacity_review": True,
        "degradation_plan": True,
        "recovery_priority": True,
    })
    assert result["valid"] is True


def test_contingency_policy_passes():
    result = assess_contingency_policy({
        "roles_defined": True,
        "escalation": True,
        "communication": True,
        "activation_criteria": True,
        "evidence": True,
        "periodic_review": True,
    })
    assert result["valid"] is True


def test_full_gate_passes(tmp_path):
    result = ContinuityResilienceService(
        tmp_path,
        ["config/backup.json", "docs/recovery.md", ".github/workflows/ci.yml"],
    ).assess()
    assert result["status"] == "CONTINUITY_RESILIENCE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_twelve_controls(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert len(result["controls"]) == 12


def test_full_gate_does_not_execute_backup_restore_or_failover(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert result["backup_executed"] is False
    assert result["restore_executed"] is False
    assert result["failover_executed"] is False


def test_full_gate_does_not_restart_or_shift_traffic(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert result["service_restarted"] is False
    assert result["traffic_shifted"] is False


def test_full_gate_does_not_activate_contingency_or_notify(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert result["contingency_activated"] is False
    assert result["notification_sent"] is False


def test_full_gate_has_no_external_connection_or_secret_exposure(tmp_path):
    result = ContinuityResilienceService(tmp_path, []).assess()
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
