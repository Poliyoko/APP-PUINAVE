from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from .correlation import CorrelatedFinding
from .models import AuditFinding


SEVERITY_WEIGHT = {
    "INFO": 0,
    "WARNING": 1,
    "ERROR": 3,
    "CRITICAL": 5,
}


@dataclass(frozen=True)
class RiskAssessment:
    score: int
    level: str
    blocking_findings: int
    correlated_groups: int

    def to_dict(self) -> dict:
        return {
            "score": self.score,
            "level": self.level,
            "blocking_findings": self.blocking_findings,
            "correlated_groups": self.correlated_groups,
        }


class InstitutionalRiskEvaluator:
    @staticmethod
    def evaluate(
        findings: Iterable[AuditFinding],
        correlations: Iterable[CorrelatedFinding],
    ) -> RiskAssessment:
        findings = list(findings)
        correlations = list(correlations)

        base = sum(SEVERITY_WEIGHT.get(item.severity.upper(), 2) for item in findings)
        multi_dimension_penalty = sum(
            max(0, len(item.dimensions) - 1)
            for item in correlations
        )
        score = base + multi_dimension_penalty
        blocking = sum(1 for item in findings if item.blocking)

        if blocking > 0 or score >= 12:
            level = "HIGH"
        elif score >= 5:
            level = "MEDIUM"
        elif score > 0:
            level = "LOW"
        else:
            level = "NONE"

        return RiskAssessment(
            score=score,
            level=level,
            blocking_findings=blocking,
            correlated_groups=len(correlations),
        )
