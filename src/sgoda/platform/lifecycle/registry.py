from typing import Dict, Iterable

from .models import ComponentDefinition, ComponentRecord


class ComponentRegistryError(RuntimeError):
    pass


class ComponentLifecycleRegistry:
    def __init__(self) -> None:
        self._records: Dict[str, ComponentRecord] = {}

    def register(self, definition: ComponentDefinition) -> ComponentRecord:
        component_id = definition.component_id

        if component_id in self._records:
            raise ComponentRegistryError(
                "component already registered: {0}".format(component_id)
            )

        record = ComponentRecord(definition=definition)
        self._records[component_id] = record
        return record

    def get(self, component_id: str) -> ComponentRecord:
        try:
            return self._records[component_id]
        except KeyError as exc:
            raise ComponentRegistryError(
                "component not registered: {0}".format(component_id)
            ) from exc

    def exists(self, component_id: str) -> bool:
        return component_id in self._records

    def records(self) -> Iterable[ComponentRecord]:
        return tuple(self._records.values())