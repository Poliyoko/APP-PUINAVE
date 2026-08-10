from __future__ import annotations

from pathlib import Path
from typing import Any

from .governance import CategoryGovernance, GovernanceDecision
from .ledger import CategoryChangeLedger
from .proposal import CategoryProposal
from .registry import CatalogSnapshot, CategoryRegistryStore


class Spt0233Layer3GovernanceService:
    """Capa final de SPT-023.3: persistencia, aprobaciÃ³n y trazabilidad de cambios."""

    def __init__(
        self,
        registry_path: str | Path,
        ledger_path: str | Path,
    ) -> None:
        self.registry = CategoryRegistryStore(registry_path)
        self.ledger = CategoryChangeLedger(ledger_path)
        self.governance = CategoryGovernance()

    def review_proposal(
        self,
        proposal: CategoryProposal,
        *,
        approve: bool,
        reviewer: str,
        reason: str,
        category_id: str | None = None,
        parent_id: str | None = None,
    ) -> dict[str, Any]:
        before = self.registry.load()

        decision = self.governance.review(
            proposal,
            approve=approve,
            reviewer=reviewer,
            reason=reason,
            category_id=category_id,
            parent_id=parent_id,
        )

        if decision.decision == "REJECTED":
            event = self.ledger.append(
                action="PROPOSAL_REJECTED",
                proposal_id=proposal.proposal_id,
                reviewer=decision.reviewer,
                reason=decision.reason,
                registry_version_before=before.version,
                registry_version_after=before.version,
                registry_sha_before=before.sha256,
                registry_sha_after=before.sha256,
                category_id=None,
            )
            return self._result(decision, before, before, event)

        assert decision.category is not None

        candidate = [dict(item) for item in before.categories]

        existing_ids = {str(item["id"]) for item in candidate}
        existing_names = {str(item["name"]).casefold() for item in candidate}

        if decision.category["id"] in existing_ids:
            raise ValueError("Approved category_id already exists.")
        if str(decision.category["name"]).casefold() in existing_names:
            raise ValueError("Approved category name already exists.")

        candidate.append(dict(decision.category))

        had_registry = self.registry.path.exists()
        previous_bytes = (
            self.registry.path.read_bytes()
            if had_registry
            else None
        )

        try:
            after = self.registry.save(
                version=before.version + 1,
                categories=candidate,
            )

            event = self.ledger.append(
                action="CATEGORY_APPROVED_AND_REGISTERED",
                proposal_id=proposal.proposal_id,
                reviewer=decision.reviewer,
                reason=decision.reason,
                registry_version_before=before.version,
                registry_version_after=after.version,
                registry_sha_before=before.sha256,
                registry_sha_after=after.sha256,
                category_id=str(decision.category["id"]),
            )
        except Exception:
            if had_registry and previous_bytes is not None:
                self.registry.path.write_bytes(previous_bytes)
            elif self.registry.path.exists():
                self.registry.path.unlink()
            raise

        return self._result(decision, before, after, event)

    @staticmethod
    def _result(
        decision: GovernanceDecision,
        before: CatalogSnapshot,
        after: CatalogSnapshot,
        event: dict[str, Any],
    ) -> dict[str, Any]:
        return {
            "component": "SPT-023.3",
            "layer": "3",
            "scope_status": "COMPLETE",
            "decision": decision.to_dict(),
            "registry_before": before.to_dict(),
            "registry_after": after.to_dict(),
            "ledger_event": dict(event),
            "automatic_category_creation": False,
            "human_approval_required": True,
            "traceability": "SHA256_CHAIN",
            "next_component": "SPT-023.4",
        }
