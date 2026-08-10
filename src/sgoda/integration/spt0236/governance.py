from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True)
class RetryPolicy:
    max_attempts: int = 3
    retryable_exceptions: tuple[str, ...] = ("RuntimeError", "TimeoutError")

    def validate(self) -> None:
        if self.max_attempts < 1:
            raise ValueError("max_attempts must be >= 1.")

    def to_dict(self) -> dict[str, Any]:
        self.validate()
        return asdict(self)


@dataclass(frozen=True)
class HealthGateResult:
    component: str
    healthy: bool
    detail: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def evaluate_health_gates(
    results: list[HealthGateResult],
    *,
    required_components: tuple[str, ...],
) -> dict[str, Any]:
    by_component = {item.component: item for item in results}
    missing = [
        component for component in required_components
        if component not in by_component
    ]
    unhealthy = [
        component for component in required_components
        if component in by_component and not by_component[component].healthy
    ]
    return {
        "required_components": list(required_components),
        "missing": missing,
        "unhealthy": unhealthy,
        "passed": not missing and not unhealthy,
    }
