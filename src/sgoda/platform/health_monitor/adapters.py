from typing import Any, Callable, Dict

from .models import HealthCheckResult, HealthSeverity


def boolean_health_adapter(
    check_id: str,
    component_id: str,
    provider: Callable[[], bool],
    failure_detail: str = "health check failed",
):
    def check() -> HealthCheckResult:
        healthy = bool(provider())
        return HealthCheckResult(
            check_id=check_id,
            component_id=component_id,
            healthy=healthy,
            severity=HealthSeverity.ERROR,
            detail="HEALTHY" if healthy else failure_detail,
        )

    return check


def metric_threshold_adapter(
    check_id: str,
    component_id: str,
    provider: Callable[[], float],
    maximum: float,
    metric_name: str,
):
    def check() -> HealthCheckResult:
        value = float(provider())
        healthy = value <= maximum
        return HealthCheckResult(
            check_id=check_id,
            component_id=component_id,
            healthy=healthy,
            severity=HealthSeverity.WARNING,
            detail=(
                "WITHIN_THRESHOLD"
                if healthy
                else "THRESHOLD_EXCEEDED"
            ),
            metrics={
                metric_name: value,
                "maximum": maximum,
            },
        )

    return check