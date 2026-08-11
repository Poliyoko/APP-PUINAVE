from pathlib import Path
from typing import Iterable

from .audit import KeyLifecycleGovernanceAuditor
from .gate import KeyLifecycleGovernanceGate


class KeyLifecycleGovernanceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = KeyLifecycleGovernanceAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = KeyLifecycleGovernanceGate.evaluate(result["controls"])
        result["status"] = "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS" if passed else "KEY_LIFECYCLE_GOVERNANCE_GATE_HOLD"
        result["failed_blocking_controls"] = failed
        return result
