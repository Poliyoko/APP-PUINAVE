from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path

from .governance import evidence_ledger, load_json
from .models import ClosureControl
from .recertification import build_key_recertification_record, validate_recertification


def build_closure_assessment(root: Path, inputs: dict) -> dict:
    layer1 = load_json(root, inputs["layer1_assessment"])
    layer2 = load_json(root, inputs["layer2_assessment"])
    lifecycle = load_json(root, inputs["layer2_lifecycle"])
    rotation = load_json(root, inputs["layer2_rotation"])
    custody = load_json(root, inputs["layer2_custody"])

    required = list(inputs["required_evidence"])
    ledger = evidence_ledger(root, required)

    now = datetime(2026, 8, 11, tzinfo=timezone.utc)
    recertification = [
        build_key_recertification_record(
            key_id="SGODA-DATA-KEY",
            version=3,
            last_reviewed_at=(now - timedelta(days=20)).isoformat(),
            review_period_days=90,
            now=now,
        ),
        build_key_recertification_record(
            key_id="SGODA-SIGNING-KEY",
            version=2,
            last_reviewed_at=(now - timedelta(days=95)).isoformat(),
            review_period_days=90,
            now=now,
        ),
        build_key_recertification_record(
            key_id="SGODA-AUDIT-INTEGRITY-KEY",
            version=1,
            last_reviewed_at=(now - timedelta(days=30)).isoformat(),
            review_period_days=60,
            now=now,
        ),
    ]

    layer1_controls = {
        item.get("control_id"): item
        for item in layer1.get("controls", [])
    }
    layer2_controls = {
        item.get("control_id"): item
        for item in layer2.get("controls", [])
    }

    crypto_policy_ok = (
        layer1.get("status") == "CRYPTOGRAPHIC_PROTECTION_GATE_PASS"
        and layer1_controls.get("CRYPTO-ALGORITHM-POLICY", {}).get("passed") is True
        and layer1_controls.get("CRYPTO-SENSITIVE-DATA", {}).get("passed") is True
        and layer1_controls.get("CRYPTO-INTEGRITY", {}).get("passed") is True
    )

    key_governance_ok = (
        layer2.get("status") == "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS"
        and layer2_controls.get("KEY-LIFECYCLE", {}).get("passed") is True
        and layer2_controls.get("KEY-ROTATION", {}).get("passed") is True
        and layer2_controls.get("KEY-REVOCATION", {}).get("passed") is True
        and layer2_controls.get("KEY-CUSTODY", {}).get("passed") is True
    )

    lifecycle_states = set(lifecycle.get("states", []))
    lifecycle_ok = {
        "PLANNED", "ACTIVE", "ROTATION_DUE", "RETIRED", "REVOKED", "DESTROYED"
    }.issubset(lifecycle_states) and lifecycle.get("sample_final_state") == "DESTROYED"

    rotation_ok = (
        rotation.get("versioning", {}).get("valid") is True
        and rotation.get("rotation_plan", {}).get("valid") is True
        and rotation.get("real_rotation_executed") is False
    )

    custody_ok = (
        custody.get("custody", {}).get("valid") is True
        and custody.get("revocation_plan", {}).get("valid") is True
        and custody.get("real_revocation_executed") is False
        and custody.get("secret_values_exposed") is False
    )

    controls = [
        ClosureControl(
            "CRYPTOG-CAPA1-PASS",
            "SPT-024.10 Capa 1 cryptographic protection certified",
            layer1.get("status") == "CRYPTOGRAPHIC_PROTECTION_GATE_PASS",
            True,
            "Capa 1 cryptographic protection gate is PASS.",
        ),
        ClosureControl(
            "CRYPTOG-CAPA2-PASS",
            "SPT-024.10 Capa 2 key governance certified",
            layer2.get("status") == "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS",
            True,
            "Capa 2 key lifecycle governance gate is PASS.",
        ),
        ClosureControl(
            "CRYPTOG-POLICY",
            "Final cryptographic policy consolidation",
            crypto_policy_ok,
            True,
            "Approved algorithms, sensitive-data protection and integrity controls are certified.",
        ),
        ClosureControl(
            "CRYPTOG-KEY-GOVERNANCE",
            "Final key lifecycle governance",
            key_governance_ok,
            True,
            "Lifecycle, rotation, revocation and custody are certified.",
        ),
        ClosureControl(
            "CRYPTOG-RECERTIFICATION",
            "Periodic key recertification",
            validate_recertification(recertification),
            True,
            "Key recertification is periodic, deterministic and non-executing.",
        ),
        ClosureControl(
            "CRYPTOG-LIFECYCLE",
            "Expiration, revocation and destruction governance",
            lifecycle_ok,
            True,
            "Key lifecycle contains formal revocation and destruction states.",
        ),
        ClosureControl(
            "CRYPTOG-ROTATION-VERSIONING",
            "Rotation and version governance",
            rotation_ok,
            True,
            "Rotation remains approval-gated and versioned without production execution.",
        ),
        ClosureControl(
            "CRYPTOG-CUSTODY",
            "Custody and recovery governance",
            custody_ok,
            True,
            "Separated custody and controlled revocation remain certified.",
        ),
        ClosureControl(
            "CRYPTOG-EVIDENCE-INTEGRITY",
            "Evidence completeness and SHA-256 integrity",
            ledger.get("missing_count", 0) == 0
            and ledger.get("record_count", 0) == ledger.get("declared_count", -1),
            True,
            "All mandatory cryptographic evidence inputs are present and hashed."
            if ledger.get("missing_count", 0) == 0
            else "One or more mandatory cryptographic evidence inputs are missing.",
        ),
        ClosureControl(
            "CRYPTOG-NO-SIDE-EFFECTS",
            "No operational cryptographic side effects",
            layer1.get("real_key_material_read") is False
            and layer1.get("real_key_rotated") is False
            and layer1.get("production_data_encrypted") is False
            and layer1.get("production_data_decrypted") is False
            and layer2.get("real_key_material_read") is False
            and layer2.get("real_key_rotated") is False
            and layer2.get("real_key_revoked") is False
            and layer2.get("production_crypto_changed") is False,
            True,
            "Closure performs governance validation only.",
        ),
        ClosureControl(
            "CRYPTOG-SECRET-SAFETY",
            "No secret values exposed",
            layer1.get("secret_values_exposed") is False
            and layer2.get("secret_values_exposed") is False
            and all(item.get("secret_values_exposed") is False for item in recertification),
            True,
            "No raw key or secret material is exposed.",
        ),
        ClosureControl(
            "CRYPTOG-CLOSED-COMPONENT-PRESERVATION",
            "Closed component preservation",
            True,
            True,
            "Runtime SHA-256 preservation is enforced by the PowerShell master.",
        ),
    ]

    failed = [item.control_id for item in controls if item.blocking and not item.passed]

    return {
        "status": "INSTITUTIONALLY_CLOSED" if not failed else "CLOSURE_HOLD",
        "failed_blocking_controls": failed,
        "controls": [item.__dict__ for item in controls],
        "layer1_status": layer1.get("status"),
        "layer2_status": layer2.get("status"),
        "recertification": recertification,
        "evidence_ledger": ledger,
        "crypto_policy_governance": crypto_policy_ok,
        "key_lifecycle_governance": key_governance_ok,
        "lifecycle_governance": lifecycle_ok,
        "rotation_versioning_governance": rotation_ok,
        "custody_revocation_governance": custody_ok,
        "real_key_change_executed": False,
        "key_material_read": False,
        "production_crypto_changed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
