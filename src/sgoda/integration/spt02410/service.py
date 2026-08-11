from pathlib import Path
from typing import Iterable

from .audit import CryptographicProtectionAuditor
from .gate import CryptographicProtectionGate


class CryptographicProtectionService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = CryptographicProtectionAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = CryptographicProtectionGate.evaluate(result["controls"])

        result["status"] = "CRYPTOGRAPHIC_PROTECTION_GATE_PASS" if passed else "CRYPTOGRAPHIC_PROTECTION_GATE_HOLD"
        result["failed_blocking_controls"] = failed

        return result
