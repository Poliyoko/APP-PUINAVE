from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict
from uuid import uuid4


@dataclass(frozen=True)
class InstitutionalMessage:
    topic: str
    payload: Dict[str, Any]
    source: str
    message_id: str = field(default_factory=lambda: str(uuid4()))
    created_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    def __post_init__(self) -> None:
        if not self.topic or not self.topic.strip():
            raise ValueError("topic is required")
        if not self.source or not self.source.strip():
            raise ValueError("source is required")

        object.__setattr__(self, "topic", self.topic.strip())
        object.__setattr__(self, "source", self.source.strip())
        object.__setattr__(self, "payload", dict(self.payload))