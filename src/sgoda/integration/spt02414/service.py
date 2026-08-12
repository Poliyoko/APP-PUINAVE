from pathlib import Path
from typing import Iterable

from .audit import SecurityRiskGovernanceAuditor
from .gate import SecurityRiskGovernanceGate


class SecurityRiskGovernanceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = SecurityRiskGovernanceAuditor(self.root, self.discovered_paths).assess()
        passed, failed = SecurityRiskGovernanceGate.evaluate(result["controls"])
        result["status"] = "SECURITY_RISK_GOVERNANCE_GATE_PASS" if passed else "SECURITY_RISK_GOVERNANCE_GATE_HOLD"
        result["failed_blocking_controls"] = failed
        return result
