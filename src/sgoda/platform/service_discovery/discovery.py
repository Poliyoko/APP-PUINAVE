from datetime import datetime, timezone
from typing import Tuple

from .models import ServiceRecord, ServiceStatus
from .registry import InstitutionalServiceRegistry


class NoServiceAvailableError(RuntimeError):
    pass


class InstitutionalServiceDiscovery:
    def __init__(self, registry: InstitutionalServiceRegistry) -> None:
        self.registry = registry

    def resolve(
        self,
        capability: str,
        minimum_version: str = "0.0.0",
        maximum_version: str = "",
    ) -> ServiceRecord:
        matches = self.registry.discover(
            capability=capability,
            minimum_version=minimum_version,
            maximum_version=maximum_version,
            available_only=True,
        )

        if not matches:
            raise NoServiceAvailableError(
                "no service available for capability: {0}".format(
                    capability
                )
            )

        return matches[-1]

    def expire_stale(
        self,
        max_age_seconds: int,
        now_utc: datetime = None,
    ) -> Tuple[str, ...]:
        if max_age_seconds < 0:
            raise ValueError("max_age_seconds cannot be negative")

        now = now_utc or datetime.now(timezone.utc)
        expired = []

        for record in self.registry.records():
            heartbeat = datetime.fromisoformat(record.last_heartbeat_utc)
            age = (now - heartbeat).total_seconds()

            if (
                age > max_age_seconds
                and record.status != ServiceStatus.RETIRED
            ):
                record.status = ServiceStatus.UNAVAILABLE
                expired.append(record.definition.service_id)

        return tuple(sorted(expired))