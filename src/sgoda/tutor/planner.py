from __future__ import annotations

from sgoda.knowledge_engine.graph import KnowledgeGraph

from .models import (
    LearnerProfile,
    LearningActivity,
    LearningPath,
)


class LearningPathPlanner:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.graph = graph

    def build(
        self,
        profile: LearnerProfile,
        seed_node_id: str,
        limit: int = 5,
    ) -> LearningPath:
        nodes, _ = self.graph.neighborhood(
            seed_node_id,
            depth=2,
            validated_only=True,
        )

        available = [
            node
            for node in nodes
            if node.node_type == "lexical_entry"
            and node.node_id not in profile.completed_entry_ids
        ]

        if not available:
            seed = self.graph.get_node(seed_node_id)
            if seed is not None and seed.node_type == "lexical_entry":
                available = [seed]

        activities = []

        for index, node in enumerate(
            sorted(available, key=lambda item: item.node_id)[:limit],
            start=1,
        ):
            activities.append(
                LearningActivity(
                    activity_id=f"{profile.learner_id}-ACT-{index:03d}",
                    activity_type="recognition",
                    title=f"Reconocer {node.label}",
                    entry_ids=(node.node_id,),
                    instructions=(
                        f"Escucha, observa y reconoce el término "
                        f"{node.label}."
                    ),
                    expected_answer=node.label,
                    metadata={
                        "language": node.language,
                        "source_ref": node.source_ref,
                    },
                )
            )

        return LearningPath(
            path_id=f"PATH-{profile.learner_id}-{seed_node_id}",
            learner_id=profile.learner_id,
            level=profile.level,
            activities=tuple(activities),
        )