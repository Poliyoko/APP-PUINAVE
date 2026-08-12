import pytest
from datetime import datetime, timezone
from pathlib import Path
from sgoda.integration.spt02411l2.core import (
    transition, archive_plan, retention, legal_hold, disposal_review,
    privacy_governance, DataLifecycleGovernanceService
)

def test_valid_lifecycle():
    r={"state":"ACTIVE"}
    for s in ["ARCHIVE_READY","ARCHIVED","RETENTION_REVIEW","DISPOSAL_REVIEW","CLOSED"]:
        r=transition(r,s)
    assert r["state"]=="CLOSED"

def test_invalid_transition():
    with pytest.raises(ValueError):
        transition({"state":"ACTIVE"},"CLOSED")

def test_archive_requires_integrity():
    assert archive_plan({"record_id":"R1","archive_format":"JSON","integrity_required":True,"immutable":True})["valid"] is True
    assert archive_plan({"record_id":"R1","archive_format":"JSON","integrity_required":False,"immutable":True})["valid"] is False

def test_expired_retention_review():
    r=retention({"created_at":"2025-01-01T00:00:00+00:00","retention_days":30,"minimum_retention_days":30,"legal_hold":False}, datetime(2026,8,11,tzinfo=timezone.utc))
    assert r["disposition"]=="DISPOSAL_REVIEW"
    assert r["disposal_executed"] is False

def test_legal_hold_overrides():
    r=retention({"created_at":"2025-01-01T00:00:00+00:00","retention_days":30,"minimum_retention_days":30,"legal_hold":True}, datetime(2026,8,11,tzinfo=timezone.utc))
    assert r["disposition"]=="HOLD"

def test_legal_hold_requires_authority():
    assert legal_hold({"hold_id":"LH1","reason":"Institutional investigation","authority":"OWNER","active":True})["valid"] is True
    assert legal_hold({"hold_id":"LH1","reason":"short","authority":"","active":True})["valid"] is False

def test_disposal_review():
    r=disposal_review({"record_id":"R1","approved_by":"OWNER","reason":"Retention period completed","legal_hold":False,"integrity_verified":True})
    assert r["eligible"] is True and r["disposal_executed"] is False

def test_disposal_blocked_by_hold():
    r=disposal_review({"record_id":"R1","approved_by":"OWNER","reason":"Retention period completed","legal_hold":True,"integrity_verified":True})
    assert r["eligible"] is False

def test_privacy_governance():
    r=privacy_governance({"purpose":"PRESERVATION","classification":"RESTRICTED","access_review":True,"minimization_review":True,"retention_review":True})
    assert r["valid"] is True

def test_full_gate(tmp_path):
    r=DataLifecycleGovernanceService(tmp_path,[]).assess()
    assert r["status"]=="DATA_LIFECYCLE_GOVERNANCE_GATE_PASS"
    assert r["failed_blocking_controls"]==[]

def test_no_real_changes(tmp_path):
    r=DataLifecycleGovernanceService(tmp_path,[]).assess()
    assert r["production_data_modified"] is False
    assert r["production_data_deleted"] is False
    assert r["archive_executed"] is False
    assert r["disposal_executed"] is False
    assert r["external_disclosure_executed"] is False
    assert r["external_connection_opened"] is False
    assert r["secret_values_exposed"] is False
