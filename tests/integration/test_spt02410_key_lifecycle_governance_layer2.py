import pytest

from sgoda.integration.spt02410l2.custody import validate_custody
from sgoda.integration.spt02410l2.lifecycle import transition
from sgoda.integration.spt02410l2.revocation import build_revocation_record
from sgoda.integration.spt02410l2.rotation import build_rotation_plan
from sgoda.integration.spt02410l2.service import KeyLifecycleGovernanceService
from sgoda.integration.spt02410l2.versioning import validate_versions


def test_valid_lifecycle_sequence():
    record = {"state": "PLANNED"}
    record = transition(record, "ACTIVE")
    record = transition(record, "ROTATION_DUE")
    record = transition(record, "RETIRED")
    record = transition(record, "DESTROYED")
    assert record["state"] == "DESTROYED"


def test_invalid_lifecycle_transition_fails():
    with pytest.raises(ValueError):
        transition({"state": "PLANNED"}, "DESTROYED")


def test_versioning_passes_for_ordered_versions():
    result = validate_versions([
        {"key_id": "K1", "version": 1},
        {"key_id": "K1", "version": 2},
        {"key_id": "K1", "version": 3},
    ])
    assert result["valid"] is True


def test_duplicate_key_version_fails():
    result = validate_versions([
        {"key_id": "K1", "version": 1},
        {"key_id": "K1", "version": 1},
    ])
    assert result["valid"] is False


def test_rotation_plan_is_next_version_and_nonexecuting():
    plan = build_rotation_plan({
        "key_id": "K1",
        "current_version": 3,
        "rotation_interval_days": 90,
        "approval_required": True,
    })
    assert plan["valid"] is True
    assert plan["to_version"] == 4
    assert plan["rotation_executed"] is False


def test_rotation_requires_approval():
    plan = build_rotation_plan({
        "key_id": "K1",
        "current_version": 3,
        "rotation_interval_days": 90,
        "approval_required": False,
    })
    assert plan["valid"] is False


def test_revocation_requires_reason_and_approval():
    good = build_revocation_record({
        "key_id": "K1",
        "version": 2,
        "reason": "Scheduled retirement after rotation",
        "approved_by": "SECURITY_OWNER",
    })
    bad = build_revocation_record({
        "key_id": "K1",
        "version": 2,
        "reason": "short",
        "approved_by": "",
    })
    assert good["valid"] is True
    assert bad["valid"] is False


def test_custody_requires_separation():
    result = validate_custody({
        "owner": "OWNER",
        "primary_custodian": "A",
        "secondary_custodian": "B",
        "recovery_authority": "C",
    })
    assert result["valid"] is True


def test_custody_rejects_same_person():
    result = validate_custody({
        "owner": "OWNER",
        "primary_custodian": "A",
        "secondary_custodian": "A",
        "recovery_authority": "C",
    })
    assert result["valid"] is False


def test_full_key_governance_gate_passes(tmp_path):
    result = KeyLifecycleGovernanceService(tmp_path, []).assess()
    assert result["status"] == "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_no_real_key_changes(tmp_path):
    result = KeyLifecycleGovernanceService(tmp_path, []).assess()
    assert result["real_key_material_read"] is False
    assert result["real_key_rotated"] is False
    assert result["real_key_revoked"] is False
    assert result["production_crypto_changed"] is False
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
