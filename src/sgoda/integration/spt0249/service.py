from pathlib import Path
from typing import Iterable

from .audit import IdentityAccessSecurityAuditor
from .gate import IdentityAccessSecurityGate


class IdentityAccessSecurityService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = IdentityAccessSecurityAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = IdentityAccessSecurityGate.evaluate(result["controls"])

        result["status"] = "IDENTITY_ACCESS_GATE_PASS" if passed else "IDENTITY_ACCESS_GATE_HOLD"
        result["failed_blocking_controls"] = failed

        return result
