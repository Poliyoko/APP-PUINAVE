from dataclasses import dataclass

from .service_bus import InstitutionalEventBus


@dataclass(frozen=True)
class EventBusHealthReport:
    healthy: bool
    subscribers: int
    deliveries: int
    dead_letters: int


class EventBusHealthMonitor:
    def evaluate(self, bus: InstitutionalEventBus) -> EventBusHealthReport:
        subscribers = len(tuple(bus.registry.subscriptions()))
        dead_letters = len(bus.dead_letters)

        return EventBusHealthReport(
            healthy=(dead_letters == 0),
            subscribers=subscribers,
            deliveries=len(bus.history),
            dead_letters=dead_letters,
        )