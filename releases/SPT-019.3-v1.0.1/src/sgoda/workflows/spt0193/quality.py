from dataclasses import dataclass
from typing import Dict, Iterable, Tuple


@dataclass(frozen=True)
class GateResult:
    name: str
    passed: bool
    detail: str


@dataclass(frozen=True)
class QualityReport:
    passed: bool
    results: Tuple[GateResult, ...]


class InstitutionalQualityGate:
    def evaluate(self, checks: Dict[str, bool]) -> QualityReport:
        if not checks:
            raise ValueError("at least one quality check is required")

        results = tuple(
            GateResult(
                name=name,
                passed=bool(passed),
                detail="APPROVED" if passed else "FAILED",
            )
            for name, passed in sorted(checks.items())
        )
        return QualityReport(
            passed=all(item.passed for item in results),
            results=results,
        )

    def require(self, checks: Dict[str, bool]) -> QualityReport:
        report = self.evaluate(checks)
        if not report.passed:
            failed = ", ".join(item.name for item in report.results if not item.passed)
            raise RuntimeError("quality gates failed: {0}".format(failed))
        return report