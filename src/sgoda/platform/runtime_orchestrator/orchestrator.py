from typing import Callable, Dict, List, Optional, Tuple

from .models import RuntimeEvent, RuntimeState, RuntimeUnitDefinition
from .planner import RuntimePlanner
from .registry import RuntimeUnitRegistry


class RuntimeTransitionError(RuntimeError):
    pass


class RuntimeStartError(RuntimeError):
    pass


class InstitutionalRuntimeOrchestrator:
    def __init__(
        self,
        registry: Optional[RuntimeUnitRegistry] = None,
    ) -> None:
        self.registry = registry or RuntimeUnitRegistry()
        self.planner = RuntimePlanner(self.registry)
        self.history: List[RuntimeEvent] = []
        self._hooks: Dict[str, List[Callable]] = {}

    def register(self, definition: RuntimeUnitDefinition):
        return self.registry.register(definition)

    def add_hook(self, action: str, hook: Callable) -> None:
        if not callable(hook):
            raise ValueError("hook must be callable")
        self._hooks.setdefault(action, []).append(hook)

    def _emit(
        self,
        unit_id: str,
        previous_state: RuntimeState,
        current_state: RuntimeState,
        action: str,
        detail: str = "",
    ) -> RuntimeEvent:
        event = RuntimeEvent(
            unit_id=unit_id,
            previous_state=previous_state,
            current_state=current_state,
            action=action,
            detail=detail,
        )
        self.history.append(event)

        for hook in self._hooks.get(action, ()):
            hook(event)

        return event

    def start_unit(self, unit_id: str) -> RuntimeEvent:
        record = self.registry.get(unit_id)

        if record.state == RuntimeState.RUNNING:
            raise RuntimeTransitionError(
                "runtime unit already running: {0}".format(unit_id)
            )

        for dependency in record.definition.dependencies:
            dependency_record = self.registry.get(dependency)
            if dependency_record.state != RuntimeState.RUNNING:
                raise RuntimeTransitionError(
                    "runtime dependency is not running: {0}".format(
                        dependency
                    )
                )

        previous = record.state
        record.state = RuntimeState.STARTING
        self._emit(
            unit_id,
            previous,
            RuntimeState.STARTING,
            "STARTING",
        )

        try:
            record.definition.start()
        except Exception as exc:
            record.last_error = str(exc)
            record.state = RuntimeState.FAILED
            self._emit(
                unit_id,
                RuntimeState.STARTING,
                RuntimeState.FAILED,
                "START_FAILED",
                str(exc),
            )
            raise RuntimeStartError(
                "runtime start failed: {0}".format(unit_id)
            ) from exc

        record.last_error = ""
        record.state = RuntimeState.RUNNING
        return self._emit(
            unit_id,
            RuntimeState.STARTING,
            RuntimeState.RUNNING,
            "STARTED",
        )

    def stop_unit(self, unit_id: str) -> RuntimeEvent:
        record = self.registry.get(unit_id)

        if record.state not in (
            RuntimeState.RUNNING,
            RuntimeState.FAILED,
        ):
            raise RuntimeTransitionError(
                "runtime unit cannot be stopped from state: {0}".format(
                    record.state.value
                )
            )

        previous = record.state
        record.state = RuntimeState.STOPPING
        self._emit(
            unit_id,
            previous,
            RuntimeState.STOPPING,
            "STOPPING",
        )

        record.definition.stop()
        record.state = RuntimeState.STOPPED

        return self._emit(
            unit_id,
            RuntimeState.STOPPING,
            RuntimeState.STOPPED,
            "STOPPED",
        )

    def start_all(self) -> Tuple[RuntimeEvent, ...]:
        started = []
        events = []

        try:
            for unit_id in self.planner.startup_order():
                event = self.start_unit(unit_id)
                started.append(unit_id)
                events.append(event)
        except Exception:
            for started_id in reversed(started):
                record = self.registry.get(started_id)
                if record.state == RuntimeState.RUNNING:
                    self.stop_unit(started_id)
            raise

        return tuple(events)

    def stop_all(self) -> Tuple[RuntimeEvent, ...]:
        events = []

        for unit_id in self.planner.shutdown_order():
            record = self.registry.get(unit_id)

            if record.state in (
                RuntimeState.RUNNING,
                RuntimeState.FAILED,
            ):
                events.append(self.stop_unit(unit_id))

        return tuple(events)