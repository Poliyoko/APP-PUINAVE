
from __future__ import annotations

import hashlib
import json
from typing import Any, Protocol

from .adaptation import infer_difficulty, select_strategy
from .evidence import build_decision_evidence
from .models import (
    LearnerProfile,
    PedagogicalContext,
    PedagogicalRecommendation,
)
from .policy import is_domain_allowed, safeguards_for_domain


class KnowledgeProvider(Protocol):
    def search(self, query: Any) -> Any:
        ...


class SGODAPedagogicalAI:
    component_code = "SPT-018"
    version = "1.0.0"

    def __init__(self, knowledge_provider: KnowledgeProvider) -> None:
        self.knowledge_provider = knowledge_provider

    def recommend(
        self,
        profile: LearnerProfile,
        context: PedagogicalContext,
        permissions: tuple[str, ...] = (),
    ) -> PedagogicalRecommendation:
        if not profile.learner_id.strip():
            raise ValueError("learner_id is required")
        if not context.objective.strip():
            raise ValueError("objective is required")

        safeguards = safeguards_for_domain(
            context.cultural_domain
        )

        if not is_domain_allowed(
            context.cultural_domain,
            permissions,
        ):
            return self._blocked_recommendation(
                profile,
                context,
                safeguards,
            )

        result = self.knowledge_provider.search(
            self._knowledge_query(context)
        )
        records = tuple(getattr(result, "records", ()))
        content_ids = tuple(
            str(getattr(item, "record_id", ""))
            for item in records[: context.max_items]
            if str(getattr(item, "record_id", "")).strip()
        )

        difficulty = infer_difficulty(profile)
        strategy = select_strategy(profile)

        evidence = (
            "SPT-017 knowledge retrieval",
            "SPT-016 learning analytics profile",
            "SPT-015 adaptive assessment signals",
        )

        explanation = (
            f"Se seleccionó la estrategia {strategy} "
            f"con dificultad {difficulty} para apoyar "
            f"el objetivo: {context.objective}."
        )

        decision = build_decision_evidence(
            profile.learner_id,
            ("SPT-017", "SPT-016", "SPT-015"),
            evidence,
        )

        return PedagogicalRecommendation(
            recommendation_id=self._recommendation_id(
                profile,
                context,
                content_ids,
            ),
            learner_id=profile.learner_id,
            objective=context.objective,
            strategy=strategy,
            difficulty=difficulty,
            content_ids=content_ids,
            explanation=explanation,
            evidence=evidence,
            safeguards=safeguards,
            confidence=self._confidence(
                profile,
                content_ids,
            ),
            metadata={
                "decision_evidence": decision,
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": [],
            },
        )

    def health(self) -> dict[str, Any]:
        return {
            "component": self.component_code,
            "version": self.version,
            "status": "operational",
            "native_ecosystem": True,
            "mandatory_proprietary_dependencies": [],
            "knowledge_source": "SPT-017",
            "adaptive_sources": ["SPT-015", "SPT-016"],
            "tutor_integration": "SPT-008",
        }

    @staticmethod
    def _knowledge_query(context: PedagogicalContext) -> Any:
        from sgoda.puinave_knowledge_center.models import (
            KnowledgeQuery,
        )

        return KnowledgeQuery(
            text=context.knowledge_query,
            cultural_domain=context.cultural_domain,
            limit=context.max_items,
        )

    @staticmethod
    def _recommendation_id(
        profile: LearnerProfile,
        context: PedagogicalContext,
        content_ids: tuple[str, ...],
    ) -> str:
        payload = json.dumps(
            {
                "learner_id": profile.learner_id,
                "objective": context.objective,
                "content_ids": content_ids,
            },
            sort_keys=True,
            ensure_ascii=False,
        ).encode("utf-8")
        return "rec:" + hashlib.sha256(payload).hexdigest()[:16]

    @staticmethod
    def _confidence(
        profile: LearnerProfile,
        content_ids: tuple[str, ...],
    ) -> float:
        base = 0.55
        if profile.recent_scores:
            base += 0.15
        if profile.needs:
            base += 0.10
        if content_ids:
            base += 0.15
        return round(min(base, 0.95), 2)

    @staticmethod
    def _blocked_recommendation(
        profile: LearnerProfile,
        context: PedagogicalContext,
        safeguards: tuple[str, ...],
    ) -> PedagogicalRecommendation:
        return PedagogicalRecommendation(
            recommendation_id=(
                "blocked:"
                + hashlib.sha256(
                    (
                        profile.learner_id
                        + context.objective
                    ).encode("utf-8")
                ).hexdigest()[:16]
            ),
            learner_id=profile.learner_id,
            objective=context.objective,
            strategy="human_cultural_review",
            difficulty="not_applicable",
            content_ids=(),
            explanation=(
                "El dominio cultural requiere autorización "
                "comunitaria antes de generar una recomendación."
            ),
            evidence=(
                "SPT-018 cultural safeguard policy",
            ),
            safeguards=safeguards,
            confidence=1.0,
            status="blocked",
            metadata={
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": [],
            },
        )
