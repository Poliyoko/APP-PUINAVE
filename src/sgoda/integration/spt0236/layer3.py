from __future__ import annotations

from pathlib import Path
from typing import Any, Callable

from .compensation import CompensationRegistry
from .events import OrchestrationEventLedger
from .governance import HealthGateResult, RetryPolicy, evaluate_health_gates
from .runtime import GovernedExecutionRuntime


HealthProbe = Callable[[], HealthGateResult]


class Spt0236Layer3GovernanceService:
    """Gobierno final de ejecuciÃ³n y cierre del Orquestador Inteligente."""

    REQUIRED_HEALTH = (
        "ORCHESTRATOR",
        "STATE_STORE",
        "PMO_DIGITAL",
        "AUDITOR_INSTITUCIONAL",
        "SGD-002",
    )

    def __init__(
        self,
        *,
        ledger_path: str | Path,
        retry_policy: RetryPolicy | None = None,
    ) -> None:
        self.ledger = OrchestrationEventLedger(ledger_path)
        self.compensation = CompensationRegistry()
        self.runtime = GovernedExecutionRuntime(
            ledger=self.ledger,
            compensation=self.compensation,
            retry_policy=retry_policy,
        )

    def register_compensation(
        self,
        component: str,
        handler: Callable[[dict[str, Any]], dict[str, Any]],
    ) -> None:
        self.compensation.register(component, handler)

    def health_gate(
        self,
        probes: dict[str, HealthProbe],
    ) -> dict[str, Any]:
        results: list[HealthGateResult] = []
        for component in self.REQUIRED_HEALTH:
            probe = probes.get(component)
            if probe is None:
                continue
            result = probe()
            if result.component != component:
                raise ValueError("Health probe component mismatch.")
            results.append(result)

        gate = evaluate_health_gates(
            results,
            required_components=self.REQUIRED_HEALTH,
        )
        gate["component"] = "SPT-023.6"
        gate["layer"] = "3"
        return gate

    def certify_closure(
        self,
        *,
        orchestration_id: str,
        health_gate: dict[str, Any],
        orchestration_complete: bool,
        adapters_effective: bool,
    ) -> dict[str, Any]:
        if not bool(health_gate.get("passed")):
            raise ValueError("Health gates must pass before SPT-023.6 closure.")
        if not orchestration_complete:
            raise ValueError("Orchestration must be complete before closure.")
        if not adapters_effective:
            raise ValueError("Effective adapters are required before closure.")

        self.ledger.append(
            orchestration_id=orchestration_id,
            event_type="SPT0236_CLOSURE_CERTIFIED",
            payload={
                "health_gate": True,
                "orchestration_complete": True,
                "adapters_effective": True,
            },
        )

        return {
            "component": "SPT-023.6",
            "layer": "3",
            "status": "SPT0236_INSTITUTIONALLY_CLOSED",
            "orchestration_id": orchestration_id,
            "health_gate": "PASS",
            "event_ledger_verified": OrchestrationEventLedger.verify(
                self.ledger.all()
            ),
            "retries_governed": True,
            "compensation_governed": True,
            "adapters_effective": True,
            "orchestration_complete": True,
            "paid_api_used": False,
            "next_component": "SPT-023.7",
        }
