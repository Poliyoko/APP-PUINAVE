from pathlib import Path
from typing import Iterable

from .audit import SecurityMonitoringAuditor
from .gate import SecurityMonitoringGate


class SecurityMonitoringService:
    def __init__(self, root: Path, source_paths: Iterable[str]):
        self.root = Path(root)
        self.source_paths = list(source_paths)

    def assess(self):
        result = SecurityMonitoringAuditor(
            self.root,
            self.source_paths,
        ).assess()

        passed, failed = SecurityMonitoringGate.evaluate(result["controls"])
        result["status"] = "SECURITY_MONITORING_GATE_PASS" if passed else "SECURITY_MONITORING_GATE_HOLD"
        result["failed_blocking_controls"] = failed
        return result
