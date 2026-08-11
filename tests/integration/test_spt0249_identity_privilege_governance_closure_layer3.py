import json
from pathlib import Path

from sgoda.integration.spt0249l3.recertification import (
    build_recertification_record,
    validate_recertification,
)
from sgoda.integration.spt0249l3.service import IdentityPrivilegeClosureService


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def fixture(tmp_path):
    l1 = "l1/assessment.json"
    l2 = "l2/assessment.json"
    pam = "l2/pam.json"
    lifecycle = "l2/lifecycle.json"
    e1 = "l1/evidence.json"
    e2 = "l2/evidence.json"

    write_json(tmp_path / l1, {
        "status": "IDENTITY_ACCESS_GATE_PASS",
        "secret_values_exposed": False,
        "controls": [
            {
                "control_id": "IAM-SEPARATION-DUTIES",
                "passed": True,
            }
        ],
    })

    write_json(tmp_path / l2, {
        "status": "PRIVILEGE_GOVERNANCE_GATE_PASS",
        "secret_values_exposed": False,
        "real_privilege_granted": False,
        "real_privilege_revoked": False,
        "token_rotated": False,
        "secret_read": False,
        "command_executed": False,
        "external_connection_opened": False,
        "controls": [
            {
                "control_id": "PAM-APPROVAL",
                "passed": True,
            }
        ],
    })

    write_json(tmp_path / pam, {
        "standing_admin": False,
        "session": {
            "credential_materialized": False,
            "command_executed": False,
        },
    })

    write_json(tmp_path / lifecycle, {
        "states": [
            "REQUESTED",
            "APPROVED",
            "ACTIVE",
            "SUSPENDED",
            "EXPIRED",
            "REVOKED",
            "CLOSED",
        ],
        "sample_final_state": "CLOSED",
    })

    write_json(tmp_path / e1, {"status": "PASS"})
    write_json(tmp_path / e2, {"status": "PASS"})

    return {
        "layer1_assessment": l1,
        "layer2_assessment": l2,
        "layer2_pam_baseline": pam,
        "layer2_lifecycle_baseline": lifecycle,
        "required_evidence": [l1, l2, pam, lifecycle, e1, e2],
    }


def test_full_closure_passes(tmp_path):
    result = IdentityPrivilegeClosureService(tmp_path).close(fixture(tmp_path))
    assert result["status"] == "INSTITUTIONALLY_CLOSED"
    assert result["failed_blocking_controls"] == []


def test_missing_evidence_blocks(tmp_path):
    inputs = fixture(tmp_path)
    inputs["required_evidence"].append("missing.json")
    result = IdentityPrivilegeClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IAMG-EVIDENCE-INTEGRITY" in result["failed_blocking_controls"]


def test_layer1_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    write_json(tmp_path / inputs["layer1_assessment"], {
        "status": "IDENTITY_ACCESS_GATE_HOLD",
        "secret_values_exposed": False,
        "controls": [{"control_id": "IAM-SEPARATION-DUTIES", "passed": True}],
    })
    result = IdentityPrivilegeClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IAMG-CAPA1-PASS" in result["failed_blocking_controls"]


def test_layer2_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["status"] = "PRIVILEGE_GOVERNANCE_GATE_HOLD"
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = IdentityPrivilegeClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IAMG-CAPA2-PASS" in result["failed_blocking_controls"]


def test_separation_of_duties_failure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer1_assessment"]).read_text(encoding="utf-8"))
    data["controls"][0]["passed"] = False
    write_json(tmp_path / inputs["layer1_assessment"], data)
    result = IdentityPrivilegeClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IAMG-SEPARATION-DUTIES" in result["failed_blocking_controls"]


def test_lifecycle_without_revocation_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_lifecycle_baseline"]).read_text(encoding="utf-8"))
    data["states"] = ["REQUESTED", "APPROVED", "ACTIVE", "CLOSED"]
    write_json(tmp_path / inputs["layer2_lifecycle_baseline"], data)
    result = IdentityPrivilegeClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IAMG-LIFECYCLE" in result["failed_blocking_controls"]


def test_standing_admin_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_pam_baseline"]).read_text(encoding="utf-8"))
    data["standing_admin"] = True
    write_json(tmp_path / inputs["layer2_pam_baseline"], data)
    result = IdentityPrivilegeClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IAMG-PAM" in result["failed_blocking_controls"]


def test_secret_exposure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["secret_values_exposed"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = IdentityPrivilegeClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IAMG-SECRET-SAFETY" in result["failed_blocking_controls"]


def test_side_effect_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["real_privilege_granted"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = IdentityPrivilegeClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IAMG-NO-SIDE-EFFECTS" in result["failed_blocking_controls"]


def test_recertification_overdue_requires_review():
    record = build_recertification_record(
        identity_id="USR-1",
        permission="publication:publish",
        last_reviewed_at="2026-01-01T00:00:00+00:00",
        review_period_days=30,
    )
    assert record["overdue"] is True
    assert record["decision"] == "REVIEW"
    assert record["executed"] is False


def test_recertification_validator_rejects_empty():
    assert validate_recertification([]) is False
