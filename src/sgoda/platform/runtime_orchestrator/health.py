from dataclasses import dataclass
from typing import Tuple

from .models import RuntimeState
from .registry import RuntimeUnitRegistry


@dataclass(frozen=True)
class RuntimeUnitHealth:
    unit_id: str
    state: str
    healthy: bool
    last_error: str


@dataclass(frozen=True)
class RuntimeHealthReport:
    healthy: bool
    running_units: int
    failed_units: int
    units: Tuple[RuntimeUnitHealth, ...]


class RuntimeHealthMonitor:
    def evaluate(
        self,
        registry: RuntimeUnitRegistry,
    ) -> RuntimeHealthReport:
        units = tuple(
            RuntimeUnitHealth(
                unit_id=record.definition.unit_id,
                state=record.state.value,
                healthy=(record.state != RuntimeState.FAILED),
                last_error=record.last_error,
            )
            for record in registry.records()
        )

        running = sum(
            1
            for record in registry.records()
            if record.state == RuntimeState.RUNNING
        )
        failed = sum(
            1
            for record in registry.records()
            if record.state == RuntimeState.FAILED
        )

        return RuntimeHealthReport(
            healthy=(failed == 0),
            running_units=running,
            failed_units=failed,
            units=units,
        )