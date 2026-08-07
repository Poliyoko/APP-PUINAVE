from typing import Callable, Dict, List, Optional, Tuple

from .models import ComponentDefinition, LifecycleEvent
from .registry import ComponentLifecycleRegistry
from .states import ALLOWED_TRANSITIONS, ComponentState


class LifecycleTransitionError(RuntimeError):
    pass


class DependencyValidationError(RuntimeError):
    pass


class ComponentLifecycleManager:
    def __init__(
        self,
        registry: Optional[ComponentLifecycleRegistry] = None,
    ) -> None:
        self.registry = registry or ComponentLifecycleRegistry()
        self.history: List[LifecycleEvent] = []
        self._hooks: Dict[ComponentState, List[Callable]] = {}

    def register(self, definition: ComponentDefinition):
        return self.registry.register(definition)

    def add_hook(self, state: ComponentState, hook: Callable) -> None:
        if not callable(hook):
            raise ValueError("hook must be callable")
        self._hooks.setdefault(state, []).append(hook)

    def validate_dependencies(self, component_id: str) -> Tuple[str, ...]:
        record = self.registry.get(component_id)
        missing = tuple(
            dependency
            for dependency in record.definition.dependencies
            if not self.registry.exists(dependency)
        )

        if missing:
            raise DependencyValidationError(
                "missing dependencies: {0}".format(", ".join(missing))
            )

        return missing

    def transition(
        self,
        component_id: str,
        target_state: ComponentState,
        reason: str = "",
    ) -> LifecycleEvent:
        record = self.registry.get(component_id)
        previous_state = record.state

        if target_state not in ALLOWED_TRANSITIONS[previous_state]:
            raise LifecycleTransitionError(
                "invalid transition: {0} -> {1}".format(
                    previous_state.value,
                    target_state.value,
                )
            )

        if target_state in (ComponentState.INSTALLED, ComponentState.ACTIVE):
            self.validate_dependencies(component_id)

        record.state = target_state
        event = LifecycleEvent(
            component_id=component_id,
            previous_state=previous_state,
            current_state=target_state,
            reason=reason,
        )
        self.history.append(event)

        for hook in self._hooks.get(target_state, ()):
            hook(event)

        return event

    def install(self, component_id: str, reason: str = "") -> LifecycleEvent:
        return self.transition(component_id, ComponentState.INSTALLED, reason)

    def activate(self, component_id: str, reason: str = "") -> LifecycleEvent:
        return self.transition(component_id, ComponentState.ACTIVE, reason)

    def suspend(self, component_id: str, reason: str = "") -> LifecycleEvent:
        return self.transition(component_id, ComponentState.SUSPENDED, reason)

    def retire(self, component_id: str, reason: str = "") -> LifecycleEvent:
        return self.transition(component_id, ComponentState.RETIRED, reason)