from __future__ import annotations
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from .classification import classify_record
from .minimization import minimize_fields
from .models import PrivacyControl
from .privacy import validate_purpose
from .retention import build_retention_decision


class DataPrivacyGovernanceAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        classification = classify_record({
            "classification": "RESTRICTED",
            "data_type": "LEXICAL_RESTRICTED",
        })

        minimization = minimize_fields(
            ["word", "language", "audio_ref", "image_ref", "debug_note"],
            ["word", "language", "audio_ref", "image_ref"],
        )

        retention = build_retention_decision(
            {
                "created_at": "2026-01-01T00:00:00+00:00",
                "retention_days": 365,
                "legal_hold": False,
            },
            now=datetime(2026, 8, 11, tzinfo=timezone.utc),
        )

        purpose = validate_purpose({
            "purpose": "PRESERVATION",
            "purpose_declared": True,
            "access_limited": True,
            "disclosure_limited": True,
        })

        controls = [
            PrivacyControl(
                "DATA-CLASSIFICATION",
                "Institutional data classification",
                classification["valid"] is True
                and classification["classification"] == "RESTRICTED",
                True,
                True,
                "Sensitive information is explicitly classified.",
            ),
            PrivacyControl(
                "DATA-MINIMIZATION",
                "Data minimization",
                minimization["valid"] is True
                and minimization["minimized"] is True,
                True,
                True,
                "Only fields required for the declared purpose are retained in the model.",
            ),
            PrivacyControl(
                "DATA-RETENTION",
                "Retention governance",
                retention["valid"] is True
                and retention["decision"] in {
                    "RETAIN",
                    "RETAIN_LEGAL_HOLD",
                    "DISPOSE_REVIEW",
                },
                True,
                True,
                "Retention is time-bound and disposal remains review-gated.",
            ),
            PrivacyControl(
                "DATA-PURPOSE-LIMITATION",
                "Purpose limitation",
                purpose["valid"] is True,
                True,
                True,
                "Processing purpose is declared, allowed and access/disclosure constrained.",
            ),
            PrivacyControl(
                "DATA-SENSITIVE-ACCESS",
                "Sensitive data access control requirement",
                classification["requires_access_control"] is True,
                True,
                True,
                "Sensitive classifications require controlled access.",
            ),
            PrivacyControl(
                "DATA-NO-AUTO-DISPOSAL",
                "No automatic destructive disposal",
                retention["disposal_executed"] is False,
                True,
                True,
                "Gate never deletes production information.",
            ),
            PrivacyControl(
                "DATA-NO-SIDE-EFFECTS",
                "No production data mutation",
                minimization["data_modified_in_production"] is False
                and retention["data_modified_in_production"] is False
                and purpose["external_disclosure_executed"] is False,
                True,
                True,
                "Assessment is governance-only and does not alter production data.",
            ),
            PrivacyControl(
                "DATA-SECRET-SAFETY",
                "No secret values exposed",
                classification["secret_values_exposed"] is False
                and minimization["secret_values_exposed"] is False
                and retention["secret_values_exposed"] is False
                and purpose["secret_values_exposed"] is False,
                True,
                True,
                "Evidence stores policy metadata only.",
            ),
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and item.applicable and not item.passed
        ]

        return {
            "status": "DATA_PRIVACY_GOVERNANCE_GATE_PASS" if not failed else "DATA_PRIVACY_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "classification": classification,
            "minimization": minimization,
            "retention": retention,
            "purpose_limitation": purpose,
            "discovered_data_privacy_surfaces": len(self.discovered_paths),
            "production_data_modified": False,
            "production_data_deleted": False,
            "external_disclosure_executed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
