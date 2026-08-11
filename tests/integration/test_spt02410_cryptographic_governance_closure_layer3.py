import json
from pathlib import Path

from sgoda.integration.spt02410l3.recertification import (
    build_key_recertification_record,
    validate_recertification,
)
from sgoda.integration.spt02410l3.service import CryptographicClosureService


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def fixture(tmp_path):
    l1 = "l1/assessment.json"
    l2 = "l2/assessment.json"
    lifecycle = "l2/lifecycle.json"
    rotation = "l2/rotation.json"
    custody = "l2/custody.json"
    e1 = "l1/evidence.json"
    e2 = "l2/evidence.json"

    write_json(tmp_path / l1, {
        "status": "CRYPTOGRAPHIC_PROTECTION_GATE_PASS",
        "real_key_material_read": False,
        "real_key_rotated": False,
        "production_data_encrypted": False,
        "production_data_decrypted": False,
        "secret_values_exposed": False,
        "controls": [
            {"control_id": "CRYPTO-ALGORITHM-POLICY", "passed": True},
            {"control_id": "CRYPTO-SENSITIVE-DATA", "passed": True},
            {"control_id": "CRYPTO-INTEGRITY", "passed": True},
        ],
    })

    write_json(tmp_path / l2, {
        "status": "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS",
        "real_key_material_read": False,
        "real_key_rotated": False,
        "real_key_revoked": False,
        "production_crypto_changed": False,
        "secret_values_exposed": False,
        "controls": [
            {"control_id": "KEY-LIFECYCLE", "passed": True},
            {"control_id": "KEY-ROTATION", "passed": True},
            {"control_id": "KEY-REVOCATION", "passed": True},
            {"control_id": "KEY-CUSTODY", "passed": True},
        ],
    })

    write_json(tmp_path / lifecycle, {
        "states": [
            "PLANNED",
            "ACTIVE",
            "ROTATION_DUE",
            "RETIRED",
            "REVOKED",
            "DESTROYED",
        ],
        "sample_final_state": "DESTROYED",
    })

    write_json(tmp_path / rotation, {
        "versioning": {"valid": True},
        "rotation_plan": {"valid": True},
        "real_rotation_executed": False,
    })

    write_json(tmp_path / custody, {
        "custody": {"valid": True},
        "revocation_plan": {"valid": True},
        "real_revocation_executed": False,
        "secret_values_exposed": False,
    })

    write_json(tmp_path / e1, {"status": "PASS"})
    write_json(tmp_path / e2, {"status": "PASS"})

    return {
        "layer1_assessment": l1,
        "layer2_assessment": l2,
        "layer2_lifecycle": lifecycle,
        "layer2_rotation": rotation,
        "layer2_custody": custody,
        "required_evidence": [l1, l2, lifecycle, rotation, custody, e1, e2],
    }


def test_full_closure_passes(tmp_path):
    result = CryptographicClosureService(tmp_path).close(fixture(tmp_path))
    assert result["status"] == "INSTITUTIONALLY_CLOSED"
    assert result["failed_blocking_controls"] == []


def test_missing_evidence_blocks(tmp_path):
    inputs = fixture(tmp_path)
    inputs["required_evidence"].append("missing.json")
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "CRYPTOG-EVIDENCE-INTEGRITY" in result["failed_blocking_controls"]


def test_layer1_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer1_assessment"]).read_text(encoding="utf-8"))
    data["status"] = "CRYPTOGRAPHIC_PROTECTION_GATE_HOLD"
    write_json(tmp_path / inputs["layer1_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-CAPA1-PASS" in result["failed_blocking_controls"]


def test_layer2_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["status"] = "KEY_LIFECYCLE_GOVERNANCE_GATE_HOLD"
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-CAPA2-PASS" in result["failed_blocking_controls"]


def test_algorithm_policy_failure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer1_assessment"]).read_text(encoding="utf-8"))
    data["controls"][0]["passed"] = False
    write_json(tmp_path / inputs["layer1_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-POLICY" in result["failed_blocking_controls"]


def test_lifecycle_without_revocation_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_lifecycle"]).read_text(encoding="utf-8"))
    data["states"] = ["PLANNED", "ACTIVE", "ROTATION_DUE", "RETIRED", "DESTROYED"]
    write_json(tmp_path / inputs["layer2_lifecycle"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-LIFECYCLE" in result["failed_blocking_controls"]


def test_rotation_governance_failure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_rotation"]).read_text(encoding="utf-8"))
    data["rotation_plan"]["valid"] = False
    write_json(tmp_path / inputs["layer2_rotation"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-ROTATION-VERSIONING" in result["failed_blocking_controls"]


def test_custody_failure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_custody"]).read_text(encoding="utf-8"))
    data["custody"]["valid"] = False
    write_json(tmp_path / inputs["layer2_custody"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-CUSTODY" in result["failed_blocking_controls"]


def test_secret_exposure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["secret_values_exposed"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-SECRET-SAFETY" in result["failed_blocking_controls"]


def test_real_key_change_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["real_key_rotated"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-NO-SIDE-EFFECTS" in result["failed_blocking_controls"]


def test_recertification_overdue_requires_review():
    record = build_key_recertification_record(
        key_id="K1",
        version=1,
        last_reviewed_at="2026-01-01T00:00:00+00:00",
        review_period_days=30,
    )
    assert record["overdue"] is True
    assert record["decision"] == "REVIEW"
    assert record["rotation_executed"] is False
    assert record["revocation_executed"] is False


def test_recertification_validator_rejects_empty():
    assert validate_recertification([]) is False
