from __future__ import annotations

from typing import Any, Callable

from .bindings import EffectiveAdapterRegistry
from .contracts import PIPELINE
from .service import Spt0236Layer1Service


ComponentHandler = Callable[[dict[str, Any]], dict[str, Any]]


class Spt0236Layer2Bridge:
    """Puente efectivo entre el motor de Capa 1 y adaptadores institucionales."""

    def __init__(
        self,
        *,
        orchestrator: Spt0236Layer1Service,
        adapters: EffectiveAdapterRegistry,
        core_handlers: dict[str, ComponentHandler],
    ) -> None:
        self.orchestrator = orchestrator
        self.adapters = adapters
        self.core_handlers = dict(core_handlers)

    def handlers(self) -> dict[str, ComponentHandler]:
        merged = dict(self.core_handlers)
        merged.update(self.adapters.build_handlers())
        return merged

    def validate_bindings(self) -> dict[str, Any]:
        bindings = self.adapters.bindings()
        available = set(self.handlers())

        required_core = {
            "SPT-023.1",
            "SPT-023.2",
            "SPT-023.3",
            "SPT-023.4",
            "SPT-023.5",
        }
        missing_core = sorted(required_core - available)
        if missing_core:
            raise ValueError(
                "Missing core integration handlers: " + ", ".join(missing_core)
            )

        return {
            "component": "SPT-023.6",
            "layer": "2",
            "bindings": [
                {
                    "component": item.component,
                    "mode": item.mode,
                    "target": item.target,
                    "enabled": item.enabled,
                }
                for item in bindings
            ],
            "core_handlers_present": sorted(required_core),
            "pipeline_components": [step.component for step in PIPELINE],
            "paid_api_used": False,
            "valid": True,
        }

    def execute(
        self,
        *,
        lexical_id: str,
    ) -> dict[str, Any]:
        self.validate_bindings()
        run = self.orchestrator.create_run(lexical_id=lexical_id)
        result = self.orchestrator.execute_with_handlers(
            orchestration_id=run["orchestration_id"],
            handlers=self.handlers(),
        )
        result["integration_layer"] = 2
        result["effective_adapters"] = True
        result["paid_api_used"] = False
        result["next_component"] = "SPT-023.6-CAPA-3"
        return result
