from pathlib import Path
from typing import Iterable

from .audit import PrivilegeGovernanceAuditor
from .gate import PrivilegeGovernanceGate


class PrivilegeGovernanceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = PrivilegeGovernanceAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = PrivilegeGovernanceGate.evaluate(result["controls"])

        result["status"] = "PRIVILEGE_GOVERNANCE_GATE_PASS" if passed else "PRIVILEGE_GOVERNANCE_GATE_HOLD"
        result["failed_blocking_controls"] = failed

        return result
