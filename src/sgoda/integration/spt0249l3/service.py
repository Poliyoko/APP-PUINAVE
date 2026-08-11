from pathlib import Path

from .closure import build_closure_assessment
from .gate import IdentityPrivilegeClosureGate


class IdentityPrivilegeClosureService:
    def __init__(self, root: Path):
        self.root = Path(root)

    def close(self, inputs: dict):
        result = build_closure_assessment(self.root, inputs)
        passed, failed = IdentityPrivilegeClosureGate.evaluate(result["controls"])
        result["status"] = "INSTITUTIONALLY_CLOSED" if passed else "CLOSURE_HOLD"
        result["failed_blocking_controls"] = failed
        return result
