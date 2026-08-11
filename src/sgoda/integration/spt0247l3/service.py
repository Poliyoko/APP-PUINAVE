from pathlib import Path

from .closure import build_controls
from .gate import SupplyChainClosureGate


class SupplyChainClosureService:
    def __init__(self, root: Path):
        self.root = Path(root)

    def close(self, layer2_assessment, layer2_sbom, layer2_integrity, evidence_paths):
        payload = build_controls(
            self.root,
            layer2_assessment,
            layer2_sbom,
            layer2_integrity,
            evidence_paths,
        )

        passed, failed = SupplyChainClosureGate.evaluate(payload["controls"])
        payload["status"] = "INSTITUTIONALLY_CLOSED" if passed else "CLOSURE_HOLD"
        payload["failed_blocking_controls"] = failed
        return payload
