from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import IntEnum, Enum
from typing import Any, Dict, Tuple


class HealthSeverity(IntEnum):
    INFO = 10
    WARNING = 20
    ERROR = 30
    CRITICAL = 40


class HealthStatus(str, Enum):
    HEALTHY = "HEALTHY"
    DEGRADED = "DEGRADED"
    UNHEALTHY = "UNHEALTHY"
    UNKNOWN = "UNKNOWN"


@dataclass(frozen=True)
class HealthCheckResult:
    check_id: str
    component_id: str
    healthy: bool
    severity: HealthSeverity = HealthSeverity.ERROR
    detail: str = ""
    metrics: Dict[str, Any] = field(default_factory=dict)
    checked_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    def __post_init__(self) -> None:
        if not self.check_id or not self.check_id.strip():
            raise ValueError("check_id is required")
        if not self.component_id or not self.component_id.strip():
            raise ValueError("component_id is required")

        object.__setattr__(self, "check_id", self.check_id.strip())
        object.__setattr__(self, "component_id", self.component_id.strip())
        object.__setattr__(self, "metrics", dict(self.metrics))


@dataclass(frozen=True)
class HealthAlert:
    check_id: str
    component_id: str
    severity: HealthSeverity
    detail: str


@dataclass(frozen=True)
class HealthSnapshot:
    status: HealthStatus
    healthy_checks: int
    degraded_checks: int
    failed_checks: int
    results: Tuple[HealthCheckResult, ...]
    alerts: Tuple[HealthAlert, ...]
    generated_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )