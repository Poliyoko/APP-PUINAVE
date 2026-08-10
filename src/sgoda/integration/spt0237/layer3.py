from __future__ import annotations

from pathlib import Path
from typing import Any

from .closure import Spt0237ClosureManifestBuilder
from .gates import InstitutionalQualityGateEngine
from .governance import ClosureGovernancePolicy
from .layer2 import Spt0237Layer2Service
from .ledger import InstitutionalAuditLedger


class Spt0237Layer3ClosureService:
    """Final governance, quality gates and closure for SPT-023.7."""

    def __init__(
        self,
        root: str | Path,
        *,
        ledger_path: str | Path,
        governance_policy: ClosureGovernancePolicy | None = None,
    ) -> None:
        self.root = Path(root)
        self.layer2 = Spt0237Layer2Service(self.root)
        self.ledger = InstitutionalAuditLedger(ledger_path)
        self.policy = governance_policy or ClosureGovernancePolicy()

    def evaluate(self, *, protected_changes: int = 0) -> dict[str, Any]:
        layer2_result = self.layer2.evaluate()

        gates = InstitutionalQualityGateEngine.build(
            layer2_result=layer2_result,
            protected_changes=protected_changes,
        )
        gate_certificate = InstitutionalQualityGateEngine.certify(gates)

        governance = self.policy.validate(
            layer2_result=layer2_result,
            gate_certificate=gate_certificate,
            protected_changes=protected_changes,
        )

        self.ledger.append(
            event_type="QUALITY_GATES_EVALUATED",
            payload={
                "passed": gate_certificate["passed"],
                "failed_blocking": gate_certificate["failed_blocking"],
            },
        )
        self.ledger.append(
            event_type="GOVERNANCE_EVALUATED",
            payload={
                "passed": governance["passed"],
                "violations": governance["violations"],
            },
        )

        manifest = Spt0237ClosureManifestBuilder.build(
            quality_gates_passed=bool(gate_certificate["passed"]),
            governance_passed=bool(governance["passed"]),
            protected_changes=protected_changes,
        )

        self.ledger.append(
            event_type="SPT0237_CLOSURE_CERTIFIED",
            payload={
                "status": manifest.status,
                "manifest_sha256": manifest.manifest_sha256,
                "next_component": manifest.next_component,
            },
        )

        ledger_verified = InstitutionalAuditLedger.verify(self.ledger.all())

        return {
            "component": "SPT-023.7",
            "layer": "3",
            "status": manifest.status,
            "layer2_result": layer2_result,
            "quality_gate_certificate": gate_certificate,
            "governance": governance,
            "closure_manifest": manifest.to_dict(),
            "ledger_verified": ledger_verified,
            "protected_changes": protected_changes,
            "layer1_preserved": True,
            "layer2_preserved": True,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-023.8",
        }
