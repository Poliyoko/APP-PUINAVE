from __future__ import annotations

from dataclasses import dataclass

from .models import SecretAssessment
from .policy import SecretManagementPolicy


@dataclass(frozen=True)
class RotationInstruction:
    fingerprint: str
    required: bool
    maximum_age_days: int | None
    reason: str

    def to_dict(self) -> dict:
        return {
            "fingerprint": self.fingerprint,
            "required": self.required,
            "maximum_age_days": self.maximum_age_days,
            "reason": self.reason,
        }


class RotationPolicyEngine:
    def __init__(
        self,
        policy: SecretManagementPolicy | None = None,
    ) -> None:
        self.policy = policy or SecretManagementPolicy.default()

    def plan(self, assessment: SecretAssessment) -> RotationInstruction:
        if not assessment.requires_rotation:
            return RotationInstruction(
                fingerprint=assessment.fingerprint,
                required=False,
                maximum_age_days=None,
                reason="Rotation not required by current classification.",
            )

        days = (
            self.policy.rotation_days_high
            if assessment.severity.upper() == "CRITICAL"
            else self.policy.rotation_days_medium
        )

        return RotationInstruction(
            fingerprint=assessment.fingerprint,
            required=True,
            maximum_age_days=days,
            reason="Probable real credential must be rotated after secure replacement.",
        )
