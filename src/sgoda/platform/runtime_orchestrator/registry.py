from typing import Dict, Iterable

from .models import RuntimeUnitDefinition, RuntimeUnitRecord


class RuntimeRegistryError(RuntimeError):
    pass


class DuplicateRuntimeUnitError(RuntimeRegistryError):
    pass


class RuntimeUnitNotFoundError(RuntimeRegistryError):
    pass


class RuntimeUnitRegistry:
    def __init__(self) -> None:
        self._records: Dict[str, RuntimeUnitRecord] = {}

    def register(
        self,
        definition: RuntimeUnitDefinition,
    ) -> RuntimeUnitRecord:
        if definition.unit_id in self._records:
            raise DuplicateRuntimeUnitError(
                "runtime unit already registered: {0}".format(
                    definition.unit_id
                )
            )

        record = RuntimeUnitRecord(definition=definition)
        self._records[definition.unit_id] = record
        return record

    def get(self, unit_id: str) -> RuntimeUnitRecord:
        try:
            return self._records[unit_id]
        except KeyError as exc:
            raise RuntimeUnitNotFoundError(
                "runtime unit not registered: {0}".format(unit_id)
            ) from exc

    def exists(self, unit_id: str) -> bool:
        return unit_id in self._records

    def records(self) -> Iterable[RuntimeUnitRecord]:
        return tuple(self._records.values())