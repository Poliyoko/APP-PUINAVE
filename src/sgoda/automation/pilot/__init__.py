"""Piloto controlado de proveedores SPT-003C."""

from __future__ import annotations

from typing import Any

__all__ = [
    "AprobacionPiloto",
    "CircuitBreaker",
    "DecisionPiloto",
    "LibroConsumo",
    "RegistroConsumo",
    "ResumenPiloto",
    "evaluate_activation",
    "estimate_cost",
    "load_approval",
    "run_pilot",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)

    if name in {
        "AprobacionPiloto",
        "DecisionPiloto",
        "RegistroConsumo",
        "ResumenPiloto",
    }:
        from . import models
        return getattr(models, name)

    if name in {"LibroConsumo", "estimate_cost"}:
        from . import budget
        return getattr(budget, name)

    if name == "CircuitBreaker":
        from . import circuit_breaker
        return getattr(circuit_breaker, name)

    if name in {"evaluate_activation", "load_approval"}:
        from . import governance
        return getattr(governance, name)

    if name == "run_pilot":
        from . import runner
        return getattr(runner, name)

    raise AttributeError(name)