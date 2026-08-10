from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .evidence import EvidenceBundle
from .risk import RiskAssessment


@dataclass(frozen=True)
class InstitutionalVerdict:
    status: str
    publishable: bool
    blocking_reasons: tuple[str, ...]
    risk_level: str
    evidence_sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "publishable": self.publishable,
            "blocking_reasons": list(self.blocking_reasons),
            "risk_level": self.risk_level,
            "evidence_sha256": self.evidence_sha256,
        }


class InstitutionalVerdictEngine:
    @staticmethod
    def issue(
        *,
        report_conformant: bool,
        risk: RiskAssessment,
        evidence: EvidenceBundle,
        cross_inconsistency_count: int,
        blocking_cross_inconsistency_count: int,
    ) -> InstitutionalVerdict:
        reasons: list[str] = []

        if not report_conformant:
            reasons.append("TRANSVERSAL_AUDIT_NOT_CONFORMANT")
        if risk.blocking_findings > 0:
            reasons.append("BLOCKING_FINDINGS_PRESENT")
        if blocking_cross_inconsistency_count > 0:
            reasons.append("BLOCKING_CROSS_COMPONENT_INCONSISTENCIES")
        if not evidence.sha256 or len(evidence.sha256) != 64:
            reasons.append("EVIDENCE_BUNDLE_INVALID")

        publishable = not reasons
        status = (
            "INSTITUTIONAL_AUDIT_APPROVED"
            if publishable
            else "INSTITUTIONAL_AUDIT_HOLD"
        )

        return InstitutionalVerdict(
            status=status,
            publishable=publishable,
            blocking_reasons=tuple(reasons),
            risk_level=risk.level,
            evidence_sha256=evidence.sha256,
        )
