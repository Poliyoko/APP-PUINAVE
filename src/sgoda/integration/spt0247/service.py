from pathlib import Path
from typing import Iterable

from .audit import SupplyChainSecurityAuditor
from .gate import SupplyChainSecurityGate


class SupplyChainSecurityService:
    def __init__(self, root: Path, tracked_paths: Iterable[str]):
        self.root = Path(root)
        self.tracked_paths = list(tracked_paths)

    def assess(self):
        result = SupplyChainSecurityAuditor(self.root, self.tracked_paths).assess()
        passed, failed = SupplyChainSecurityGate.evaluate(result["controls"])
        result["status"] = "SUPPLY_CHAIN_SECURITY_GATE_PASS" if passed else "SUPPLY_CHAIN_SECURITY_GATE_HOLD"
        result["failed_control_ids"] = failed
        return result
