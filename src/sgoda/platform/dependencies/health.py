from dataclasses import dataclass
from typing import Tuple

from .manager import InstitutionalComponentDependencyManager


@dataclass(frozen=True)
class DependencyHealthItem:
    component_id: str
    valid: bool


@dataclass(frozen=True)
class DependencyHealthReport:
    healthy: bool
    components: Tuple[DependencyHealthItem, ...]


class DependencyHealthMonitor:
    def evaluate(
        self,
        manager: InstitutionalComponentDependencyManager,
    ) -> DependencyHealthReport:
        items = []

        for component in manager.registry.components():
            valid = True
            try:
                manager.validate_component(component.component_id)
            except RuntimeError:
                valid = False

            items.append(
                DependencyHealthItem(
                    component_id=component.component_id,
                    valid=valid,
                )
            )

        return DependencyHealthReport(
            healthy=all(item.valid for item in items),
            components=tuple(items),
        )