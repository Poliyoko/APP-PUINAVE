from __future__ import annotations

from pathlib import Path
from typing import Any

from .audit import ApiSecurityAuditor
from .gateway import GatewaySecurityPolicy
from .models import ApiSecurityReport


class Spt0243ApiSecurityService:
    def __init__(
        self,
        root: str | Path,
        policy: GatewaySecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or GatewaySecurityPolicy()

    def evaluate(self) -> dict[str, Any]:
        auditor = ApiSecurityAuditor(self.root, self.policy)
        controls, exposures = auditor.audit()
        report = ApiSecurityReport(
            controls=controls,
            exposures=exposures,
        )

        return {
            "component": "SPT-024.3",
            "status": (
                "API_SECURITY_GATE_PASS"
                if report.conformant
                else "API_SECURITY_GATE_HOLD"
            ),
            "report": report.to_dict(),
            "gateway_policy": self.policy.to_dict(),
            "secret_values_exposed": False,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-024.4",
        }
