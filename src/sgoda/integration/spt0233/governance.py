from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .proposal import CategoryProposal


@dataclass(frozen=True)
class GovernanceDecision:
    proposal_id: str
    decision: str
    reviewer: str
    reason: str
    category: dict[str, Any] | None
    automatic_creation: bool = False
    human_approval: bool = True

    def to_dict(self) -> dict[str, Any]:
        return {
            "proposal_id": self.proposal_id,
            "decision": self.decision,
            "reviewer": self.reviewer,
            "reason": self.reason,
            "category": None if self.category is None else dict(self.category),
            "automatic_creation": self.automatic_creation,
            "human_approval": self.human_approval,
        }


class CategoryGovernance:
    """Gobierna propuestas sin permitir creaciÃ³n automÃ¡tica de categorÃ­as."""

    def review(
        self,
        proposal: CategoryProposal,
        *,
        approve: bool,
        reviewer: str,
        reason: str,
        category_id: str | None = None,
        parent_id: str | None = None,
    ) -> GovernanceDecision:
        reviewer = str(reviewer or "").strip()
        reason = str(reason or "").strip()

        if not reviewer:
            raise ValueError("Human reviewer is required.")
        if not reason:
            raise ValueError("Decision reason is required.")

        if not approve:
            return GovernanceDecision(
                proposal_id=proposal.proposal_id,
                decision="REJECTED",
                reviewer=reviewer,
                reason=reason,
                category=None,
            )

        category_id = str(category_id or "").strip()
        if not category_id:
            raise ValueError("Approved proposal requires institutional category_id.")

        category = {
            "id": category_id,
            "name": proposal.proposed_name,
            "aliases": [],
            "keywords": [],
            "metadata": {
                "parent_id": str(parent_id).strip() if parent_id else None,
                "source_proposal_id": proposal.proposal_id,
                "approved_by": reviewer,
                "approval_reason": reason,
            },
        }

        return GovernanceDecision(
            proposal_id=proposal.proposal_id,
            decision="APPROVED_FOR_REGISTRY",
            reviewer=reviewer,
            reason=reason,
            category=category,
        )
