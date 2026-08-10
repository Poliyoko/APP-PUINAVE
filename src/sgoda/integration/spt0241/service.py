from __future__ import annotations

from pathlib import Path
from typing import Any

from .models import SecurityBaseline
from .policy import SecurityInventoryPolicy
from .scanner import SecuritySurfaceScanner
from .secrets import SecretMetadataScanner
from .surface import AttackSurfaceModel


class Spt0241SecurityInventoryService:
    """SPT-024.1 institutional security inventory and attack-surface baseline."""

    def __init__(
        self,
        root: str | Path,
        policy: SecurityInventoryPolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.policy = policy or SecurityInventoryPolicy.default()
        self.scanner = SecuritySurfaceScanner(self.root, self.policy)

    def evaluate(self) -> dict[str, Any]:
        files = self.scanner.files()
        assets = self.scanner.inventory()
        findings = self.scanner.detect_findings(assets)
        secret_candidates = SecretMetadataScanner().scan(
            root=self.root,
            paths=files,
        )

        baseline = SecurityBaseline(
            assets=assets,
            findings=findings,
        )

        return {
            "component": "SPT-024.1",
            "status": "SECURITY_BASELINE_ESTABLISHED",
            "read_only_scan": True,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "baseline": baseline.to_dict(),
            "attack_surface": AttackSurfaceModel.build(assets),
            "secret_candidates": [
                item.to_dict()
                for item in secret_candidates
            ],
            "secret_values_exposed": False,
            "next_component": "SPT-024.2",
        }
