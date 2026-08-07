from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Callable, Dict, Tuple


class RuntimeState(str, Enum):
    REGISTERED = "REGISTERED"
    STARTING = "STARTING"
    RUNNING = "RUNNING"
    STOPPING = "STOPPING"
    STOPPED = "STOPPED"
    FAILED = "FAILED"


@dataclass(frozen=True)
class RuntimeUnitDefinition:
    unit_id: str
    version: str
    start: Callable[[], Any]
    stop: Callable[[], Any]
    dependencies: Tuple[str, ...] = ()
    metadata: Dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.unit_id or not self.unit_id.strip():
            raise ValueError("unit_id is required")
        if not self.version or not self.version.strip():
            raise ValueError("version is required")
        if not callable(self.start):
            raise ValueError("start must be callable")
        if not callable(self.stop):
            raise ValueError("stop must be callable")

        object.__setattr__(self, "unit_id", self.unit_id.strip())
        object.__setattr__(self, "version", self.version.strip())
        object.__setattr__(
            self,
            "dependencies",
            tuple(sorted(set(self.dependencies))),
        )
        object.__setattr__(self, "metadata", dict(self.metadata))


@dataclass
class RuntimeUnitRecord:
    definition: RuntimeUnitDefinition
    state: RuntimeState = RuntimeState.REGISTERED
    last_error: str = ""


@dataclass(frozen=True)
class RuntimeEvent:
    unit_id: str
    previous_state: RuntimeState
    current_state: RuntimeState
    action: str
    detail: str = ""
    occurred_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )