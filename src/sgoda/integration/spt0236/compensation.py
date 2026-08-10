from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable


CompensationHandler = Callable[[dict[str, Any]], dict[str, Any]]


@dataclass(frozen=True)
class CompensationResult:
    component: str
    status: str
    detail: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": self.component,
            "status": self.status,
            "detail": dict(self.detail),
        }


class CompensationRegistry:
    def __init__(self) -> None:
        self._handlers: dict[str, CompensationHandler] = {}

    def register(
        self,
        component: str,
        handler: CompensationHandler,
    ) -> None:
        component = str(component or "").strip()
        if not component:
            raise ValueError("component is required.")
        self._handlers[component] = handler

    def compensate(
        self,
        component: str,
        payload: dict[str, Any],
    ) -> CompensationResult:
        handler = self._handlers.get(component)
        if handler is None:
            return CompensationResult(
                component=component,
                status="NO_COMPENSATION_REGISTERED",
                detail={},
            )

        result = dict(handler(dict(payload)) or {})
        status = str(result.get("status") or "").strip()
        if not status:
            raise ValueError("Compensation handler must return status.")
        return CompensationResult(
            component=component,
            status=status,
            detail=result,
        )
