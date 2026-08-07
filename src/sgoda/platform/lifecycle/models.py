from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, Tuple

from .states import ComponentState


@dataclass(frozen=True)
class ComponentDefinition:
    component_id: str
    version: str
    dependencies: Tuple[str, ...] = ()
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.component_id or not self.component_id.strip():
            raise ValueError("component_id is required")
        if not self.version or not self.version.strip():
            raise ValueError("version is required")

        object.__setattr__(self, "component_id", self.component_id.strip())
        object.__setattr__(self, "version", self.version.strip())
        object.__setattr__(self, "dependencies", tuple(self.dependencies))
        object.__setattr__(self, "metadata", dict(self.metadata))


@dataclass(frozen=True)
class LifecycleEvent:
    component_id: str
    previous_state: ComponentState
    current_state: ComponentState
    reason: str
    occurred_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )


@dataclass
class ComponentRecord:
    definition: ComponentDefinition
    state: ComponentState = ComponentState.REGISTERED