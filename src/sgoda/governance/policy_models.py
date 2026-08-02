"""Modelos normalizados del Policy Governance Core SGD-114C."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any


class Severity(str, Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    BLOCKER = "BLOCKER"


class RuleStatus(str, Enum):
    PASSED = "PASSED"
    FAILED = "FAILED"
    NOT_APPLICABLE = "NOT_APPLICABLE"


@dataclass(frozen=True, slots=True)
class PolicyRule:
    code: str
    name: str
    description: str
    severity: Severity
    category: str


@dataclass(frozen=True, slots=True)
class RuleResult:
    rule: PolicyRule
    status: RuleStatus
    message: str
    evidence: tuple[str, ...] = ()
    remediation: str = ""
    details: dict[str, Any] = field(default_factory=dict)

    @property
    def passed(self) -> bool:
        return self.status in {
            RuleStatus.PASSED,
            RuleStatus.NOT_APPLICABLE,
        }

    @property
    def blocking(self) -> bool:
        return (
            self.rule.severity == Severity.BLOCKER
            and self.status == RuleStatus.FAILED
        )


@dataclass(frozen=True, slots=True)
class PolicyEvaluation:
    policy_code: str
    policy_version: str
    increment: str
    approved: bool
    results: tuple[RuleResult, ...]
    generated_at_utc: str

    @property
    def blocking_rules(self) -> tuple[RuleResult, ...]:
        return tuple(item for item in self.results if item.blocking)

    @property
    def failed_rules(self) -> tuple[RuleResult, ...]:
        return tuple(
            item
            for item in self.results
            if item.status == RuleStatus.FAILED
        )

    @property
    def exit_code(self) -> int:
        return 0 if self.approved else 2