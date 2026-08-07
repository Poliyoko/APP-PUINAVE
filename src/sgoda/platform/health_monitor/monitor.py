from typing import Dict, List, Optional, Tuple

from .models import (
    HealthAlert,
    HealthCheckResult,
    HealthSeverity,
    HealthSnapshot,
    HealthStatus,
)
from .registry import InstitutionalHealthRegistry


class InstitutionalHealthMonitor:
    def __init__(
        self,
        registry: Optional[InstitutionalHealthRegistry] = None,
        degraded_threshold: int = 1,
        unhealthy_threshold: int = 1,
    ) -> None:
        if degraded_threshold < 1:
            raise ValueError("degraded_threshold must be at least 1")
        if unhealthy_threshold < 1:
            raise ValueError("unhealthy_threshold must be at least 1")

        self.registry = registry or InstitutionalHealthRegistry()
        self.degraded_threshold = degraded_threshold
        self.unhealthy_threshold = unhealthy_threshold
        self.history: List[HealthSnapshot] = []

    def register(
        self,
        check_id: str,
        component_id: str,
        provider,
    ):
        return self.registry.register(check_id, component_id, provider)

    def run(
        self,
        component_id: str = "",
    ) -> HealthSnapshot:
        checks = (
            self.registry.by_component(component_id)
            if component_id
            else tuple(self.registry.checks())
        )

        results = []
        alerts = []

        for check in checks:
            try:
                raw = check.provider()

                if isinstance(raw, HealthCheckResult):
                    result = raw
                elif isinstance(raw, bool):
                    result = HealthCheckResult(
                        check_id=check.check_id,
                        component_id=check.component_id,
                        healthy=raw,
                        detail="HEALTHY" if raw else "FAILED",
                    )
                elif isinstance(raw, dict):
                    result = HealthCheckResult(
                        check_id=check.check_id,
                        component_id=check.component_id,
                        healthy=bool(raw.get("healthy", False)),
                        severity=raw.get(
                            "severity",
                            HealthSeverity.ERROR,
                        ),
                        detail=str(raw.get("detail", "")),
                        metrics=dict(raw.get("metrics", {})),
                    )
                else:
                    raise TypeError(
                        "health provider returned unsupported value"
                    )
            except Exception as exc:
                result = HealthCheckResult(
                    check_id=check.check_id,
                    component_id=check.component_id,
                    healthy=False,
                    severity=HealthSeverity.CRITICAL,
                    detail=str(exc),
                )

            results.append(result)

            if not result.healthy:
                alerts.append(
                    HealthAlert(
                        check_id=result.check_id,
                        component_id=result.component_id,
                        severity=result.severity,
                        detail=result.detail,
                    )
                )

        failed = sum(1 for result in results if not result.healthy)
        degraded = sum(
            1
            for result in results
            if (
                not result.healthy
                and result.severity <= HealthSeverity.WARNING
            )
        )
        critical_failures = sum(
            1
            for result in results
            if (
                not result.healthy
                and result.severity >= HealthSeverity.ERROR
            )
        )
        healthy = sum(1 for result in results if result.healthy)

        if not results:
            status = HealthStatus.UNKNOWN
        elif critical_failures >= self.unhealthy_threshold:
            status = HealthStatus.UNHEALTHY
        elif degraded >= self.degraded_threshold or failed > 0:
            status = HealthStatus.DEGRADED
        else:
            status = HealthStatus.HEALTHY

        snapshot = HealthSnapshot(
            status=status,
            healthy_checks=healthy,
            degraded_checks=degraded,
            failed_checks=failed,
            results=tuple(results),
            alerts=tuple(alerts),
        )
        self.history.append(snapshot)
        return snapshot

    def latest(self) -> HealthSnapshot:
        if not self.history:
            raise RuntimeError("no health snapshot available")
        return self.history[-1]

    def component_summary(self) -> Dict[str, HealthStatus]:
        if not self.history:
            return {}

        latest = self.history[-1]
        grouped = {}

        for result in latest.results:
            current = grouped.get(
                result.component_id,
                HealthStatus.HEALTHY,
            )

            if not result.healthy:
                if result.severity >= HealthSeverity.ERROR:
                    grouped[result.component_id] = HealthStatus.UNHEALTHY
                elif current != HealthStatus.UNHEALTHY:
                    grouped[result.component_id] = HealthStatus.DEGRADED
            else:
                grouped.setdefault(
                    result.component_id,
                    HealthStatus.HEALTHY,
                )

        return grouped