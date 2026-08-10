from __future__ import annotations

from pathlib import Path
from typing import Any

from .audit import PostgresProductionAuditor
from .models import DataSecurityReport
from .runtime import PostgresRuntimeSecurityPolicy


class Spt0244RemediationService:
    def __init__(
        self,
        root: str | Path,
        policy: PostgresRuntimeSecurityPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or PostgresRuntimeSecurityPolicy()

    def evaluate(self) -> dict[str, Any]:
        auditor = PostgresProductionAuditor(self.root, self.policy)
        controls, surfaces = auditor.audit()
        report = DataSecurityReport(
            controls=controls,
            surfaces=surfaces,
        )

        return {
            "component": "SPT-024.4-R1",
            "status": (
                "POSTGRES_DATA_SECURITY_GATE_PASS"
                if report.conformant
                else "POSTGRES_DATA_SECURITY_GATE_HOLD"
            ),
            "report": report.to_dict(),
            "runtime_policy": self.policy.to_dict(),
            "database_connection_opened": False,
            "secret_values_exposed": False,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-024.5",
        }
