from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Callable, Dict, List


@dataclass(frozen=True)
class InstitutionalEvent:
    name: str
    payload: Dict[str, Any]
    occurred_at_utc: str


class InstitutionalEventBus:
    def __init__(self) -> None:
        self._subscribers: Dict[str, List[Callable[[InstitutionalEvent], None]]] = {}
        self.history: List[InstitutionalEvent] = []

    def subscribe(self, event_name: str, handler: Callable[[InstitutionalEvent], None]) -> None:
        self._subscribers.setdefault(event_name, []).append(handler)

    def publish(self, event_name: str, payload: Dict[str, Any]) -> InstitutionalEvent:
        event = InstitutionalEvent(
            name=event_name,
            payload=dict(payload),
            occurred_at_utc=datetime.now(timezone.utc).isoformat(),
        )
        self.history.append(event)
        for handler in self._subscribers.get(event_name, ()):
            handler(event)
        return event