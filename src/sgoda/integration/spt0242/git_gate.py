from __future__ import annotations

from typing import Iterable

from .models import CredentialControl, SecretAssessment, SecurityGateResult


class GitSecretGate:
    """Blocking publication gate for secret/credential safety."""

    REQUIRED_CONTROL_IDS = (
        "CTRL-GITIGNORE",
        "CTRL-TRACKED-SECRETS",
        "CTRL-SECRET-POLICY",
        "CTRL-CANDIDATE-CLASSIFICATION",
    )

    @classmethod
    def candidate_control(
        cls,
        assessments: Iterable[SecretAssessment],
    ) -> CredentialControl:
        assessments = list(assessments)
        real_risk = [
            item
            for item in assessments
            if item.classification == "PROBABLE_REAL_SECRET"
        ]

        return CredentialControl(
            "CTRL-CANDIDATE-CLASSIFICATION",
            "Secret candidate classification",
            len(real_risk) == 0,
            True,
            f"probable_real_secrets={len(real_risk)}",
        )

    @classmethod
    def certify(
        cls,
        *,
        controls: Iterable[CredentialControl],
        assessments: Iterable[SecretAssessment],
    ) -> SecurityGateResult:
        controls = list(controls)
        assessments = list(assessments)
        by_id = {item.control_id: item for item in controls}

        missing = [
            control_id
            for control_id in cls.REQUIRED_CONTROL_IDS
            if control_id not in by_id
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and not item.passed
        ]
        failed.extend(f"MISSING:{item}" for item in missing)

        real_risk = sum(
            1
            for item in assessments
            if item.classification == "PROBABLE_REAL_SECRET"
        )
        false_positive = sum(
            1
            for item in assessments
            if item.classification == "LIKELY_FALSE_POSITIVE"
        )

        return SecurityGateResult(
            passed=not failed,
            failed_blocking_controls=tuple(sorted(set(failed))),
            controls=tuple(controls),
            assessed_candidates=len(assessments),
            real_risk_candidates=real_risk,
            false_positive_candidates=false_positive,
        )
