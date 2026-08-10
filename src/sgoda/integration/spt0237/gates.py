from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class QualityGate:
    gate_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "gate_id": self.gate_id,
            "name": self.name,
            "passed": self.passed,
            "blocking": self.blocking,
            "detail": self.detail,
        }


class InstitutionalQualityGateEngine:
    """Converts the Layer 2 verdict into final institutional closure gates."""

    REQUIRED_GATE_IDS = (
        "GATE-TRANSVERSAL-AUDIT",
        "GATE-CORRELATION",
        "GATE-RISK",
        "GATE-EVIDENCE",
        "GATE-CROSS-COMPONENT",
        "GATE-VERDICT",
        "GATE-PRESERVATION",
    )

    @classmethod
    def build(
        cls,
        *,
        layer2_result: dict[str, Any],
        protected_changes: int,
    ) -> list[QualityGate]:
        verdict = dict(layer2_result.get("verdict") or {})
        risk = dict(layer2_result.get("risk") or {})
        evidence = dict(layer2_result.get("evidence_bundle") or {})
        inconsistencies = list(
            layer2_result.get("cross_component_inconsistencies") or []
        )

        blocking_cross = sum(
            1
            for item in inconsistencies
            if str(item.get("severity") or "").upper() in {"ERROR", "CRITICAL"}
        )

        return [
            QualityGate(
                "GATE-TRANSVERSAL-AUDIT",
                "Transversal audit",
                bool(verdict.get("publishable")),
                True,
                str(verdict.get("status") or ""),
            ),
            QualityGate(
                "GATE-CORRELATION",
                "Finding correlation",
                "correlations" in layer2_result,
                True,
                f"groups={len(layer2_result.get('correlations') or [])}",
            ),
            QualityGate(
                "GATE-RISK",
                "Institutional risk",
                str(risk.get("level") or "").upper() not in {"HIGH", "CRITICAL"},
                True,
                f"level={risk.get('level', '')};score={risk.get('score', '')}",
            ),
            QualityGate(
                "GATE-EVIDENCE",
                "Evidence integrity",
                len(str(evidence.get("sha256") or "")) == 64,
                True,
                str(evidence.get("sha256") or ""),
            ),
            QualityGate(
                "GATE-CROSS-COMPONENT",
                "Cross-component consistency",
                blocking_cross == 0,
                True,
                f"blocking={blocking_cross}",
            ),
            QualityGate(
                "GATE-VERDICT",
                "Institutional verdict",
                str(verdict.get("status") or "") == "INSTITUTIONAL_AUDIT_APPROVED",
                True,
                str(verdict.get("status") or ""),
            ),
            QualityGate(
                "GATE-PRESERVATION",
                "Closed component preservation",
                int(protected_changes) == 0,
                True,
                f"protected_changes={protected_changes}",
            ),
        ]

    @classmethod
    def certify(cls, gates: list[QualityGate]) -> dict[str, Any]:
        by_id = {gate.gate_id: gate for gate in gates}
        missing = [gate_id for gate_id in cls.REQUIRED_GATE_IDS if gate_id not in by_id]
        failed_blocking = [
            gate.gate_id
            for gate in gates
            if gate.blocking and not gate.passed
        ]
        return {
            "required": list(cls.REQUIRED_GATE_IDS),
            "missing": missing,
            "failed_blocking": failed_blocking,
            "passed": not missing and not failed_blocking,
            "gates": [gate.to_dict() for gate in gates],
        }
