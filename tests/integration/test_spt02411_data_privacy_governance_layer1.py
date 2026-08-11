from datetime import datetime, timezone

from sgoda.integration.spt02411.classification import classify_record
from sgoda.integration.spt02411.minimization import minimize_fields
from sgoda.integration.spt02411.privacy import validate_purpose
from sgoda.integration.spt02411.retention import build_retention_decision
from sgoda.integration.spt02411.service import DataPrivacyGovernanceService


def test_restricted_data_is_sensitive():
    result = classify_record({
        "classification": "RESTRICTED",
        "data_type": "LEXICAL_RESTRICTED",
    })
    assert result["valid"] is True
    assert result["sensitive"] is True
    assert result["requires_access_control"] is True


def test_invalid_classification_fails():
    result = classify_record({
        "classification": "UNKNOWN",
        "data_type": "PERSONAL_DATA",
    })
    assert result["valid"] is False


def test_minimization_removes_unrequired_fields():
    result = minimize_fields(
        ["word", "audio_ref", "debug_note"],
        ["word", "audio_ref"],
    )
    assert result["valid"] is True
    assert result["minimized"] is True
    assert result["removed_fields"] == ["debug_note"]


def test_minimization_is_non_destructive():
    result = minimize_fields(["a", "b"], ["a"])
    assert result["data_modified_in_production"] is False


def test_retention_keeps_unexpired_record():
    result = build_retention_decision(
        {
            "created_at": "2026-01-01T00:00:00+00:00",
            "retention_days": 365,
            "legal_hold": False,
        },
        now=datetime(2026, 8, 11, tzinfo=timezone.utc),
    )
    assert result["decision"] == "RETAIN"
    assert result["disposal_executed"] is False


def test_expired_record_requires_disposal_review_not_deletion():
    result = build_retention_decision(
        {
            "created_at": "2025-01-01T00:00:00+00:00",
            "retention_days": 30,
            "legal_hold": False,
        },
        now=datetime(2026, 8, 11, tzinfo=timezone.utc),
    )
    assert result["decision"] == "DISPOSE_REVIEW"
    assert result["disposal_executed"] is False


def test_legal_hold_overrides_expiration():
    result = build_retention_decision(
        {
            "created_at": "2025-01-01T00:00:00+00:00",
            "retention_days": 30,
            "legal_hold": True,
        },
        now=datetime(2026, 8, 11, tzinfo=timezone.utc),
    )
    assert result["decision"] == "RETAIN_LEGAL_HOLD"


def test_purpose_limitation_passes():
    result = validate_purpose({
        "purpose": "PRESERVATION",
        "purpose_declared": True,
        "access_limited": True,
        "disclosure_limited": True,
    })
    assert result["valid"] is True


def test_undeclared_purpose_fails():
    result = validate_purpose({
        "purpose": "PRESERVATION",
        "purpose_declared": False,
        "access_limited": True,
        "disclosure_limited": True,
    })
    assert result["valid"] is False


def test_full_privacy_gate_passes(tmp_path):
    result = DataPrivacyGovernanceService(tmp_path, []).assess()
    assert result["status"] == "DATA_PRIVACY_GOVERNANCE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_no_real_data_changes(tmp_path):
    result = DataPrivacyGovernanceService(tmp_path, []).assess()
    assert result["production_data_modified"] is False
    assert result["production_data_deleted"] is False
    assert result["external_disclosure_executed"] is False
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
