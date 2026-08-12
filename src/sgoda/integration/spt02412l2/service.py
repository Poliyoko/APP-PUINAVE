from pathlib import Path
from typing import Iterable

from .audit import InfrastructureHardeningGovernanceAuditor
from .gate import InfrastructureHardeningGovernanceGate


class InfrastructureHardeningGovernanceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = InfrastructureHardeningGovernanceAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = InfrastructureHardeningGovernanceGate.evaluate(result["controls"])
        result["status"] = (
            "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"
            if passed
            else "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_HOLD"
        )
        result["failed_blocking_controls"] = failed
        return result
