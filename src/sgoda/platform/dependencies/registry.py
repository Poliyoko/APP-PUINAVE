from typing import Dict, Iterable

from .models import DependencyComponent


class DependencyRegistryError(RuntimeError):
    pass


class ComponentDependencyRegistry:
    def __init__(self) -> None:
        self._components: Dict[str, DependencyComponent] = {}

    def register(self, component: DependencyComponent) -> None:
        if component.component_id in self._components:
            raise DependencyRegistryError(
                "component already registered: {0}".format(
                    component.component_id
                )
            )
        self._components[component.component_id] = component

    def get(self, component_id: str) -> DependencyComponent:
        try:
            return self._components[component_id]
        except KeyError as exc:
            raise DependencyRegistryError(
                "component not registered: {0}".format(component_id)
            ) from exc

    def exists(self, component_id: str) -> bool:
        return component_id in self._components

    def components(self) -> Iterable[DependencyComponent]:
        return tuple(self._components.values())