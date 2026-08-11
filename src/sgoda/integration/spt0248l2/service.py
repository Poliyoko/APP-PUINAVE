from pathlib import Path
from typing import Iterable

from .audit import EventCorrelationAuditor
from .gate import EventCorrelationGate


class EventCorrelationService:
    def __init__(self, root: Path, source_paths: Iterable[str]):
        self.root = Path(root)
        self.source_paths = list(source_paths)

    def assess(self):
        result = EventCorrelationAuditor(
            self.root,
            self.source_paths,
        ).assess()

        passed, failed = EventCorrelationGate.evaluate(result["controls"])
        result["status"] = "INCIDENT_RESPONSE_GATE_PASS" if passed else "INCIDENT_RESPONSE_GATE_HOLD"
        result["failed_blocking_controls"] = failed
        return result
