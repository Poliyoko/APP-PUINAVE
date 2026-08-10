from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from .analysis import RemediationFinding


@dataclass(frozen=True)
class RemediationGate:
    passed: bool
    blocking_reasons: tuple[str, ...]
    confirmed_risks: int
    review_required: int
    tracked_confirmed_risks: int
    history_confirmed_risks: int
    gitignore_passed: bool

    def to_dict(self) -> dict:
        return {
            "passed": self.passed,
            "blocking_reasons": list(self.blocking_reasons),
            "confirmed_risks": self.confirmed_risks,
            "review_required": self.review_required,
            "tracked_confirmed_risks": self.tracked_confirmed_risks,
            "history_confirmed_risks": self.history_confirmed_risks,
            "gitignore_passed": self.gitignore_passed,
        }


class RemediationSecurityGate:
    @staticmethod
    def certify(
        findings: Iterable[RemediationFinding],
        *,
        gitignore_passed: bool,
    ) -> RemediationGate:
        findings = list(findings)
        confirmed = [
            item for item in findings
            if item.disposition == "CONFIRMED_RISK"
        ]
        review = [
            item for item in findings
            if item.disposition == "REVIEW_REQUIRED"
        ]

        reasons: list[str] = []

        if confirmed:
            reasons.append("CONFIRMED_SECRET_RISK_REMAINS")
        if review:
            reasons.append("CANDIDATES_REQUIRE_MANUAL_REVIEW")
        if not gitignore_passed:
            reasons.append("GITIGNORE_SECURITY_CONTROL_FAILED")

        return RemediationGate(
            passed=not reasons,
            blocking_reasons=tuple(reasons),
            confirmed_risks=len(confirmed),
            review_required=len(review),
            tracked_confirmed_risks=sum(1 for item in confirmed if item.tracked),
            history_confirmed_risks=sum(
                1 for item in confirmed if item.history_reference
            ),
            gitignore_passed=gitignore_passed,
        )
