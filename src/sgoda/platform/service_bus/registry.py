from dataclasses import dataclass
from typing import Any, Dict, Iterable, Tuple


class ServiceRegistrationError(RuntimeError):
    pass


@dataclass(frozen=True)
class ServiceDescriptor:
    name: str
    service: Any
    topics: Tuple[str, ...]


class InstitutionalServiceRegistry:
    def __init__(self) -> None:
        self._services: Dict[str, ServiceDescriptor] = {}

    def register(self, name: str, service: Any, topics=()) -> ServiceDescriptor:
        if not name or not name.strip():
            raise ValueError("service name is required")
        if service is None:
            raise ValueError("service instance is required")
        if not callable(getattr(service, "handle", None)):
            raise ServiceRegistrationError("service must implement handle(message)")

        descriptor = ServiceDescriptor(
            name=name.strip(),
            service=service,
            topics=tuple(sorted(set(topics))),
        )
        self._services[descriptor.name] = descriptor
        return descriptor

    def get(self, name: str) -> Any:
        try:
            return self._services[name].service
        except KeyError as exc:
            raise ServiceRegistrationError(
                "service not registered: {0}".format(name)
            ) from exc

    def find_by_topic(self, topic: str):
        return tuple(
            item
            for item in self._services.values()
            if not item.topics or topic in item.topics
        )

    def descriptors(self) -> Iterable[ServiceDescriptor]:
        return tuple(self._services.values())