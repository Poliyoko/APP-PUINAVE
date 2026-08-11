from pathlib import Path

from .closure import build_governance_assessment
from .gate import IncidentGovernanceClosureGate


class IncidentGovernanceClosureService:
    def __init__(self, root: Path):
        self.root = Path(root)

    def close(self, inputs: dict):
        result = build_governance_assessment(self.root, inputs)
        passed, failed = IncidentGovernanceClosureGate.evaluate(result["controls"])

        result["status"] = "INSTITUTIONALLY_CLOSED" if passed else "CLOSURE_HOLD"
        result["failed_blocking_controls"] = failed

        return result
