from pathlib import Path
from typing import Iterable

from .audit import SupplyChainLayer2Auditor
from .gate import SupplyChainLayer2Gate


class SupplyChainLayer2Service:
    def __init__(self, root: Path, workflow_paths: Iterable[str], dependency_paths: Iterable[str]):
        self.root = Path(root)
        self.workflow_paths = list(workflow_paths)
        self.dependency_paths = list(dependency_paths)

    def assess(self):
        result = SupplyChainLayer2Auditor(
            self.root,
            self.workflow_paths,
            self.dependency_paths,
        ).assess()
        passed, failed = SupplyChainLayer2Gate.evaluate(result["controls"])
        result["status"] = "SUPPLY_CHAIN_LAYER2_GATE_PASS" if passed else "SUPPLY_CHAIN_LAYER2_GATE_HOLD"
        result["failed_blocking_controls"] = failed
        return result
