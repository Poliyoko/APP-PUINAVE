from __future__ import annotations

from pathlib import Path
from typing import Any

from .audit import AutomationSecurityAuditor
from .gate import AutomationSecurityGate
from .policy import AutomationSecurityPolicy


class Spt0245AutomationSecurityService:
    def __init__(
        self,
        root: str | Path,
        policy: AutomationSecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or AutomationSecurityPolicy.default()

    def evaluate(self) -> dict[str, Any]:
        auditor = AutomationSecurityAuditor(self.root, self.policy)
        controls, surfaces = auditor.audit()
        report = AutomationSecurityGate.certify(
            controls,
            surfaces,
        )

        return {
            "component": "SPT-024.5",
            "status": (
                "AUTOMATION_SECURITY_GATE_PASS"
                if report.conformant
                else "AUTOMATION_SECURITY_GATE_HOLD"
            ),
            "report": report.to_dict(),
            "secret_values_exposed": False,
            "n8n_started_by_gate": False,
            "workflow_executed_by_gate": False,
            "webhook_called_by_gate": False,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-024.6",
        }
