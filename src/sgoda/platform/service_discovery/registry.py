from datetime import datetime, timezone
from typing import Dict, Iterable, Tuple

from .models import ServiceDefinition, ServiceRecord, ServiceStatus
from .versioning import is_compatible


class ServiceRegistryError(RuntimeError):
    pass


class DuplicateServiceError(ServiceRegistryError):
    pass


class ServiceNotFoundError(ServiceRegistryError):
    pass


class InstitutionalServiceRegistry:
    def __init__(self) -> None:
        self._records: Dict[str, ServiceRecord] = {}

    def register(self, definition: ServiceDefinition) -> ServiceRecord:
        if definition.service_id in self._records:
            raise DuplicateServiceError(
                "service already registered: {0}".format(
                    definition.service_id
                )
            )

        record = ServiceRecord(definition=definition)
        self._records[definition.service_id] = record
        return record

    def unregister(self, service_id: str) -> None:
        self._records.pop(service_id, None)

    def get(self, service_id: str) -> ServiceRecord:
        try:
            return self._records[service_id]
        except KeyError as exc:
            raise ServiceNotFoundError(
                "service not registered: {0}".format(service_id)
            ) from exc

    def heartbeat(
        self,
        service_id: str,
        status: ServiceStatus = ServiceStatus.AVAILABLE,
    ) -> ServiceRecord:
        record = self.get(service_id)
        record.status = status
        record.last_heartbeat_utc = datetime.now(timezone.utc).isoformat()
        return record

    def set_status(
        self,
        service_id: str,
        status: ServiceStatus,
    ) -> ServiceRecord:
        record = self.get(service_id)
        record.status = status
        return record

    def discover(
        self,
        name: str = "",
        capability: str = "",
        minimum_version: str = "0.0.0",
        maximum_version: str = "",
        available_only: bool = True,
    ) -> Tuple[ServiceRecord, ...]:
        matches = []

        for record in self._records.values():
            definition = record.definition

            if name and definition.name != name:
                continue
            if capability and capability not in definition.capabilities:
                continue
            if available_only and record.status != ServiceStatus.AVAILABLE:
                continue
            if not is_compatible(
                definition.version,
                minimum_version,
                maximum_version,
            ):
                continue

            matches.append(record)

        return tuple(
            sorted(
                matches,
                key=lambda item: (
                    item.definition.name,
                    item.definition.version,
                    item.definition.service_id,
                ),
            )
        )

    def records(self) -> Iterable[ServiceRecord]:
        return tuple(self._records.values())