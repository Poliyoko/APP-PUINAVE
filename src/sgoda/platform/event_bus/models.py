from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import IntEnum
from typing import Any, Dict
from uuid import uuid4


class EventPriority(IntEnum):
    LOW = 10
    NORMAL = 20
    HIGH = 30
    CRITICAL = 40


@dataclass(frozen=True)
class InstitutionalEvent:
    event_type: str
    payload: Dict[str, Any]
    source: str
    priority: EventPriority = EventPriority.NORMAL
    event_id: str = field(default_factory=lambda: str(uuid4()))
    occurred_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    def __post_init__(self) -> None:
        if not self.event_type or not self.event_type.strip():
            raise ValueError("event_type is required")
        if not self.source or not self.source.strip():
            raise ValueError("source is required")

        object.__setattr__(self, "event_type", self.event_type.strip())
        object.__setattr__(self, "source", self.source.strip())
        object.__setattr__(self, "payload", dict(self.payload))


@dataclass(frozen=True)
class EventDelivery:
    event_id: str
    subscriber_name: str
    delivered: bool
    attempts: int
    error: str = ""


@dataclass(frozen=True)
class DeadLetter:
    event: InstitutionalEvent
    subscriber_name: str
    attempts: int
    error: str