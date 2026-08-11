from pathlib import Path
from typing import Iterable

from .audit import DataPrivacyGovernanceAuditor
from .gate import DataPrivacyGovernanceGate


class DataPrivacyGovernanceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = DataPrivacyGovernanceAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = DataPrivacyGovernanceGate.evaluate(result["controls"])
        result["status"] = "DATA_PRIVACY_GOVERNANCE_GATE_PASS" if passed else "DATA_PRIVACY_GOVERNANCE_GATE_HOLD"
        result["failed_blocking_controls"] = failed

        return result
