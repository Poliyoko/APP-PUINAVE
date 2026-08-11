from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .custody import validate_custody
from .lifecycle import transition
from .models import KeyControl
from .revocation import build_revocation_record
from .rotation import build_rotation_plan
from .versioning import validate_versions


class KeyLifecycleGovernanceAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        lifecycle = {"key_id": "SGODA-DATA-KEY", "state": "PLANNED"}
        lifecycle = transition(lifecycle, "ACTIVE")
        lifecycle = transition(lifecycle, "ROTATION_DUE")
        lifecycle = transition(lifecycle, "RETIRED")
        lifecycle = transition(lifecycle, "DESTROYED")

        versions = validate_versions([
            {"key_id": "SGODA-DATA-KEY", "version": 1},
            {"key_id": "SGODA-DATA-KEY", "version": 2},
            {"key_id": "SGODA-DATA-KEY", "version": 3},
        ])

        custody = validate_custody({
            "owner": "PISI_SECURITY_OWNER",
            "primary_custodian": "CRYPTO_CUSTODIAN_A",
            "secondary_custodian": "CRYPTO_CUSTODIAN_B",
            "recovery_authority": "INSTITUTIONAL_RECOVERY_AUTHORITY",
        })

        rotation = build_rotation_plan({
            "key_id": "SGODA-DATA-KEY",
            "current_version": 3,
            "rotation_interval_days": 90,
            "approval_required": True,
        })

        revocation = build_revocation_record({
            "key_id": "SGODA-DATA-KEY",
            "version": 2,
            "reason": "Cryptographic lifecycle retirement",
            "approved_by": "PISI_SECURITY_OWNER",
        })

        controls = [
            KeyControl(
                "KEY-LIFECYCLE",
                "Cryptographic key lifecycle",
                lifecycle["state"] == "DESTROYED",
                True,
                True,
                "Lifecycle supports activation, rotation due, retirement and destruction.",
            ),
            KeyControl(
                "KEY-VERSIONING",
                "Cryptographic key versioning",
                versions["valid"] is True,
                True,
                True,
                "Key versions are positive, unique, ordered and belong to one key family.",
            ),
            KeyControl(
                "KEY-ROTATION",
                "Planned key rotation",
                rotation["valid"] is True
                and rotation["to_version"] == rotation["from_version"] + 1,
                True,
                True,
                "Rotation is planned, versioned and approval-gated.",
            ),
            KeyControl(
                "KEY-REVOCATION",
                "Key revocation governance",
                revocation["valid"] is True,
                True,
                True,
                "Revocation requires key identity, version, reason and approval.",
            ),
            KeyControl(
                "KEY-CUSTODY",
                "Separated key custody",
                custody["valid"] is True,
                True,
                True,
                "Ownership, dual custody and recovery authority are separated.",
            ),
            KeyControl(
                "KEY-NO-REAL-MATERIAL",
                "No real key material access",
                custody["key_material_read"] is False
                and rotation["key_material_read"] is False
                and revocation["key_material_read"] is False,
                True,
                True,
                "Gate never reads production key material.",
            ),
            KeyControl(
                "KEY-NO-SIDE-EFFECTS",
                "No operational key mutation",
                rotation["rotation_executed"] is False
                and revocation["revocation_executed"] is False
                and rotation["external_connection_opened"] is False,
                True,
                True,
                "Gate models lifecycle operations without executing production changes.",
            ),
            KeyControl(
                "KEY-SECRET-SAFETY",
                "No secret values exposed",
                custody["secret_values_exposed"] is False
                and rotation["secret_values_exposed"] is False
                and revocation["secret_values_exposed"] is False,
                True,
                True,
                "Evidence contains governance metadata only.",
            ),
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and item.applicable and not item.passed
        ]

        return {
            "status": "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS" if not failed else "KEY_LIFECYCLE_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "lifecycle_final_state": lifecycle["state"],
            "versioning": versions,
            "custody": custody,
            "rotation_plan": rotation,
            "revocation_plan": revocation,
            "discovered_key_governance_surfaces": len(self.discovered_paths),
            "real_key_material_read": False,
            "real_key_rotated": False,
            "real_key_revoked": False,
            "production_crypto_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
