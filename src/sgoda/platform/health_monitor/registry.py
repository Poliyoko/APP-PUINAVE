from dataclasses import dataclass
from typing import Callable, Dict, Iterable, Tuple


class HealthRegistryError(RuntimeError):
    pass


class DuplicateHealthCheckError(HealthRegistryError):
    pass


@dataclass(frozen=True)
class RegisteredHealthCheck:
    check_id: str
    component_id: str
    provider: Callable


class InstitutionalHealthRegistry:
    def __init__(self) -> None:
        self._checks: Dict[str, RegisteredHealthCheck] = {}

    def register(
        self,
        check_id: str,
        component_id: str,
        provider: Callable,
    ) -> RegisteredHealthCheck:
        if not check_id or not check_id.strip():
            raise ValueError("check_id is required")
        if not component_id or not component_id.strip():
            raise ValueError("component_id is required")
        if not callable(provider):
            raise ValueError("provider must be callable")
        if check_id in self._checks:
            raise DuplicateHealthCheckError(
                "health check already registered: {0}".format(check_id)
            )

        registered = RegisteredHealthCheck(
            check_id=check_id.strip(),
            component_id=component_id.strip(),
            provider=provider,
        )
        self._checks[registered.check_id] = registered
        return registered

    def unregister(self, check_id: str) -> None:
        self._checks.pop(check_id, None)

    def checks(self) -> Iterable[RegisteredHealthCheck]:
        return tuple(self._checks.values())

    def by_component(
        self,
        component_id: str,
    ) -> Tuple[RegisteredHealthCheck, ...]:
        return tuple(
            check
            for check in self._checks.values()
            if check.component_id == component_id
        )