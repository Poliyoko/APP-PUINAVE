from dataclasses import dataclass
from typing import Tuple

from .registry import InstitutionalServiceRegistry


@dataclass(frozen=True)
class ServiceHealth:
    name: str
    healthy: bool


@dataclass(frozen=True)
class BusHealthReport:
    healthy: bool
    services: Tuple[ServiceHealth, ...]


class InstitutionalBusHealthMonitor:
    def evaluate(self, registry: InstitutionalServiceRegistry) -> BusHealthReport:
        results = []

        for descriptor in registry.descriptors():
            health_method = getattr(descriptor.service, "health", None)

            if callable(health_method):
                healthy = bool(health_method())
            else:
                healthy = callable(getattr(descriptor.service, "handle", None))

            results.append(ServiceHealth(descriptor.name, healthy))

        return BusHealthReport(
            healthy=all(item.healthy for item in results),
            services=tuple(results),
        )