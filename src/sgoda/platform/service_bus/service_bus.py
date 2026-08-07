from dataclasses import dataclass
from typing import Any, Dict, List, Tuple

from .contracts import InstitutionalMessage
from .registry import InstitutionalServiceRegistry


class RoutingError(RuntimeError):
    pass


@dataclass(frozen=True)
class DeliveryResult:
    service_name: str
    output: Any


@dataclass(frozen=True)
class BusReceipt:
    message_id: str
    topic: str
    deliveries: Tuple[DeliveryResult, ...]


class InstitutionalServiceBus:
    def __init__(self) -> None:
        self.registry = InstitutionalServiceRegistry()
        self.history: List[BusReceipt] = []
        self._middleware = []

    def register_service(self, name: str, service: Any, topics=()):
        return self.registry.register(name, service, topics)

    def add_middleware(self, middleware) -> None:
        if not callable(middleware):
            raise ValueError("middleware must be callable")
        self._middleware.append(middleware)

    def publish(
        self,
        topic: str,
        payload: Dict[str, Any],
        source: str,
    ) -> BusReceipt:
        message = InstitutionalMessage(topic, payload, source)

        for middleware in self._middleware:
            message = middleware(message)
            if message is None:
                raise RuntimeError("middleware cannot return None")

        descriptors = self.registry.find_by_topic(message.topic)

        if not descriptors:
            raise RoutingError(
                "no service available for topic: {0}".format(message.topic)
            )

        deliveries = tuple(
            DeliveryResult(
                service_name=descriptor.name,
                output=descriptor.service.handle(message),
            )
            for descriptor in descriptors
        )

        receipt = BusReceipt(
            message_id=message.message_id,
            topic=message.topic,
            deliveries=deliveries,
        )
        self.history.append(receipt)
        return receipt