from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class ClosureGovernancePolicy:
    require_quality_gates: bool = True
    require_layer1_reuse: bool = True
    require_layer2_reuse: bool = True
    require_sha256_evidence: bool = True
    require_zero_protected_changes: bool = True
    require_remote_sync: bool = True
    allow_paid_api: bool = False

    def validate(
        self,
        *,
        layer2_result: dict[str, Any],
        gate_certificate: dict[str, Any],
        protected_changes: int,
    ) -> dict[str, Any]:
        violations: list[str] = []

        if self.require_quality_gates and not gate_certificate.get("passed"):
            violations.append("QUALITY_GATES_NOT_APPROVED")
        if self.require_layer1_reuse and not layer2_result.get("layer1_reused"):
            violations.append("LAYER1_NOT_REUSED")
        if self.require_layer2_reuse and layer2_result.get("layer") != "2":
            violations.append("LAYER2_RESULT_INVALID")
        if self.require_sha256_evidence:
            sha = str(
                (layer2_result.get("evidence_bundle") or {}).get("sha256") or ""
            )
            if len(sha) != 64:
                violations.append("EVIDENCE_SHA256_INVALID")
        if self.require_zero_protected_changes and protected_changes != 0:
            violations.append("PROTECTED_COMPONENTS_CHANGED")
        if bool(layer2_result.get("paid_api_used")):
            violations.append("PAID_API_USAGE_DETECTED")

        return {
            "passed": not violations,
            "violations": violations,
            "policy": {
                "require_quality_gates": self.require_quality_gates,
                "require_layer1_reuse": self.require_layer1_reuse,
                "require_layer2_reuse": self.require_layer2_reuse,
                "require_sha256_evidence": self.require_sha256_evidence,
                "require_zero_protected_changes": self.require_zero_protected_changes,
                "require_remote_sync": self.require_remote_sync,
                "allow_paid_api": self.allow_paid_api,
            },
        }
