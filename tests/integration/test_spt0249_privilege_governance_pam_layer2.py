from pathlib import Path

import pytest

from sgoda.integration.spt0249l2.approval import validate_request
from sgoda.integration.spt0249l2.lifecycle import transition
from sgoda.integration.spt0249l2.pam import build_session_control
from sgoda.integration.spt0249l2.service import PrivilegeGovernanceService
from sgoda.integration.spt0249l2.service_identity import validate_service_identity


def test_service_identity_valid():
    result = validate_service_identity({
        "identity_type": "SERVICE",
        "roles": ["SERVICE_WORKFLOW"],
        "owner": "PMO_DIGITAL",
        "credential_reference": "secretref:SVC_TOKEN",
    })

    assert result["valid"] is True
    assert result["secret_values_exposed"] is False


def test_service_identity_requires_owner():
    result = validate_service_identity({
        "identity_type": "SERVICE",
        "roles": ["SERVICE_WORKFLOW"],
        "owner": "",
        "credential_reference": "secretref:SVC_TOKEN",
    })

    assert result["valid"] is False


def test_service_identity_rejects_human_role():
    result = validate_service_identity({
        "identity_type": "SERVICE",
        "roles": ["PUBLISHER"],
        "owner": "PMO_DIGITAL",
        "credential_reference": "secretref:SVC_TOKEN",
    })

    assert result["valid"] is False


def test_service_identity_requires_indirect_secret_reference():
    result = validate_service_identity({
        "identity_type": "SERVICE",
        "roles": ["SERVICE_WORKFLOW"],
        "owner": "PMO_DIGITAL",
        "credential_reference": "plaintext-token",
    })

    assert result["valid"] is False


def test_privileged_request_requires_separate_approver():
    good = validate_request({
        "identity_id": "USR-PUB",
        "permission": "publication:publish",
        "justification": "Institutional publication approval",
        "requested_by": "USR-PUB",
        "approved_by": "USR-AUD",
    })

    bad = validate_request({
        "identity_id": "USR-PUB",
        "permission": "publication:publish",
        "justification": "Institutional publication approval",
        "requested_by": "USR-PUB",
        "approved_by": "USR-PUB",
    })

    assert good["valid"] is True
    assert bad["valid"] is False


def test_privileged_request_requires_justification():
    result = validate_request({
        "identity_id": "USR-PUB",
        "permission": "publication:publish",
        "justification": "short",
        "requested_by": "USR-PUB",
        "approved_by": "USR-AUD",
    })

    assert result["valid"] is False


def test_lifecycle_valid_sequence():
    record = {"state": "REQUESTED"}
    record = transition(record, "APPROVED")
    record = transition(record, "ACTIVE")
    record = transition(record, "REVOKED")
    record = transition(record, "CLOSED")

    assert record["state"] == "CLOSED"


def test_lifecycle_rejects_invalid_transition():
    with pytest.raises(ValueError):
        transition({"state": "REQUESTED"}, "ACTIVE")


def test_high_risk_permission_requires_jit_pam():
    session = build_session_control({
        "grant_id": "G1",
        "permission": "publication:publish",
    })

    assert session["pam_required"] is True
    assert session["session_mode"] == "JUST_IN_TIME"


def test_pam_session_has_no_operational_side_effects():
    session = build_session_control({
        "grant_id": "G1",
        "permission": "repository:admin",
    })

    assert session["credential_materialized"] is False
    assert session["secret_read"] is False
    assert session["command_executed"] is False
    assert session["external_connection_opened"] is False
    assert session["secret_values_exposed"] is False


def test_full_privilege_governance_gate_passes(tmp_path):
    result = PrivilegeGovernanceService(tmp_path, []).assess()

    assert result["status"] == "PRIVILEGE_GOVERNANCE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_no_real_privilege_changes(tmp_path):
    result = PrivilegeGovernanceService(tmp_path, []).assess()

    assert result["real_privilege_granted"] is False
    assert result["real_privilege_revoked"] is False
    assert result["token_rotated"] is False
    assert result["secret_read"] is False
    assert result["command_executed"] is False
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
