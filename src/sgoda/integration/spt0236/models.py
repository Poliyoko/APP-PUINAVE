from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True)
class OrchestrationStep:
    step_id: str
    component: str
    action: str
    required_input_status: str | None
    success_status: str
    critical: bool
    metadata: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class OrchestrationPlan:
    orchestration_id: str
    lexical_id: str
    current_status: str
    steps: tuple[OrchestrationStep, ...]
    next_component: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": "SPT-023.6",
            "layer": "1",
            "orchestration_id": self.orchestration_id,
            "lexical_id": self.lexical_id,
            "current_status": self.current_status,
            "steps": [step.to_dict() for step in self.steps],
            "next_component": self.next_component,
        }
