
from __future__ import annotations

from pathlib import Path
from typing import Any

from sgoda.puinave_knowledge_center.service import (
    PuinaveKnowledgeCenter,
)

from .engine import SGODAPedagogicalAI
from .models import LearnerProfile, PedagogicalContext


class PedagogicalAIService:
    def __init__(
        self,
        knowledge_storage: str | Path | None = None,
    ) -> None:
        self.knowledge_center = PuinaveKnowledgeCenter(
            knowledge_storage
        )
        self.engine = SGODAPedagogicalAI(
            self.knowledge_center
        )

    def recommend(
        self,
        profile: LearnerProfile,
        context: PedagogicalContext,
        permissions: tuple[str, ...] = (),
    ) -> dict[str, Any]:
        return self.engine.recommend(
            profile,
            context,
            permissions,
        ).to_dict()

    def health(self) -> dict[str, Any]:
        return self.engine.health()
