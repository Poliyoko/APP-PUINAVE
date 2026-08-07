from dataclasses import dataclass
from typing import Tuple

from .models import ServiceStatus
from .registry import InstitutionalServiceRegistry


@dataclass(frozen=True)
class RegisteredServiceHealth:
    service_id: str
    status: str
    capabilities: Tuple[str, ...]


@dataclass(frozen=True)
class ServiceRegistryHealthReport:
    healthy: bool
    total_services: int
    available_services: int
    services: Tuple[RegisteredServiceHealth, ...]


class ServiceRegistryHealthMonitor:
    def evaluate(
        self,
        registry: InstitutionalServiceRegistry,
    ) -> ServiceRegistryHealthReport:
        items = tuple(
            RegisteredServiceHealth(
                service_id=record.definition.service_id,
                status=record.status.value,
                capabilities=record.definition.capabilities,
            )
            for record in registry.records()
        )

        available = sum(
            1
            for record in registry.records()
            if record.status == ServiceStatus.AVAILABLE
        )

        return ServiceRegistryHealthReport(
            healthy=(len(items) == 0 or available > 0),
            total_services=len(items),
            available_services=available,
            services=items,
        )