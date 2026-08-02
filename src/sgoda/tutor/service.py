from __future__ import annotations

from sgoda.knowledge_engine.graph import KnowledgeGraph

from .exercises import evaluate_answer
from .models import LearnerProfile
from .planner import LearningPathPlanner


class PuinaveTutorService:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.graph = graph
        self.planner = LearningPathPlanner(graph)

    def create_path(
        self,
        learner_id: str,
        seed_node_id: str,
        level: str = "beginner",
        preferred_language: str = "es",
    ) -> dict:
        path = self.planner.build(
            LearnerProfile(
                learner_id=learner_id,
                level=level,
                preferred_language=preferred_language,
            ),
            seed_node_id,
        )

        return {
            "path_id": path.path_id,
            "learner_id": path.learner_id,
            "level": path.level,
            "activities": [
                {
                    "activity_id": item.activity_id,
                    "activity_type": item.activity_type,
                    "title": item.title,
                    "entry_ids": list(item.entry_ids),
                    "instructions": item.instructions,
                    "expected_answer": item.expected_answer,
                    "metadata": item.metadata,
                }
                for item in path.activities
            ],
            "no_invention": True,
        }

    def evaluate(
        self,
        activity_payload: dict,
        answer: str,
    ) -> dict:
        from .models import LearningActivity

        activity = LearningActivity(
            activity_id=activity_payload["activity_id"],
            activity_type=activity_payload["activity_type"],
            title=activity_payload["title"],
            entry_ids=tuple(activity_payload["entry_ids"]),
            instructions=activity_payload["instructions"],
            expected_answer=activity_payload.get("expected_answer"),
            metadata=dict(activity_payload.get("metadata", {})),
        )
        feedback = evaluate_answer(activity, answer)

        return {
            "correct": feedback.correct,
            "score": feedback.score,
            "message": feedback.message,
            "remediation": feedback.remediation,
        }