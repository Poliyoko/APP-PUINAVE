from dataclasses import dataclass
from typing import Tuple

from .registry import ComponentLifecycleRegistry


@dataclass(frozen=True)
class ComponentHealth:
    component_id: str
    version: str
    state: str


@dataclass(frozen=True)
class LifecycleHealthSnapshot:
    healthy: bool
    components: Tuple[ComponentHealth, ...]


class LifecycleHealthMonitor:
    def snapshot(
        self,
        registry: ComponentLifecycleRegistry,
    ) -> LifecycleHealthSnapshot:
        components = tuple(
            ComponentHealth(
                component_id=record.definition.component_id,
                version=record.definition.version,
                state=record.state.value,
            )
            for record in registry.records()
        )

        return LifecycleHealthSnapshot(
            healthy=True,
            components=components,
        )