from pathlib import Path
from typing import Iterable

from .audit import ContinuityResilienceAuditor
from .gate import ContinuityResilienceGate


class ContinuityResilienceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = ContinuityResilienceAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = ContinuityResilienceGate.evaluate(result["controls"])
        result["status"] = (
            "CONTINUITY_RESILIENCE_GATE_PASS"
            if passed
            else "CONTINUITY_RESILIENCE_GATE_HOLD"
        )
        result["failed_blocking_controls"] = failed
        return result
