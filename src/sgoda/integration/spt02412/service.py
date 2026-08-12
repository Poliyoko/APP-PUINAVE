from pathlib import Path
from typing import Iterable

from .audit import InfrastructureSecurityAuditor
from .gate import InfrastructureSecurityGate


class InfrastructureSecurityService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = InfrastructureSecurityAuditor(self.root, self.discovered_paths).assess()
        passed, failed = InfrastructureSecurityGate.evaluate(result["controls"])
        result["status"] = "INFRASTRUCTURE_SECURITY_GATE_PASS" if passed else "INFRASTRUCTURE_SECURITY_GATE_HOLD"
        result["failed_blocking_controls"] = failed
        return result
