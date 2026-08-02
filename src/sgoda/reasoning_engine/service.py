from __future__ import annotations

from sgoda.knowledge_engine.graph import KnowledgeGraph

from .models import ReasoningQuestion
from .reasoner import LinguisticReasoner


class LinguisticReasoningService:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.reasoner = LinguisticReasoner(graph)

    def ask(
        self,
        text: str,
        start_node_id: str,
        relations: tuple[str, ...] = (),
        max_depth: int = 3,
    ) -> dict:
        response = self.reasoner.reason(
            ReasoningQuestion(
                text=text,
                start_node_id=start_node_id,
                relation_filter=relations,
                max_depth=max_depth,
            )
        )

        return {
            "question": text,
            "start_node_id": start_node_id,
            "unresolved": response.unresolved,
            "no_invention": response.no_invention,
            "conclusions": [
                {
                    "subject_id": item.subject_id,
                    "relation_type": item.relation_type,
                    "object_id": item.object_id,
                    "confidence": item.confidence,
                    "explanation": item.explanation,
                    "evidence": list(item.evidence),
                }
                for item in response.conclusions
            ],
            "metadata": response.metadata or {},
        }