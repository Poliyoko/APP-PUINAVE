from __future__ import annotations

from collections import deque

from sgoda.knowledge_engine.graph import KnowledgeGraph

from .models import (
    ReasoningConclusion,
    ReasoningQuestion,
    ReasoningResponse,
)
from .rules import rule_for_relation


class LinguisticReasoner:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.graph = graph

    def reason(
        self,
        question: ReasoningQuestion,
    ) -> ReasoningResponse:
        start = question.start_node_id

        if not start or self.graph.get_node(start) is None:
            return ReasoningResponse(
                question=question,
                conclusions=(),
                unresolved=True,
                metadata={"reason": "start_node_missing"},
            )

        relation_filter = {
            item.strip().casefold()
            for item in question.relation_filter
            if item.strip()
        }

        conclusions: dict[
            tuple[str, str, str],
            ReasoningConclusion,
        ] = {}

        queue = deque([(start, 0, 1.0, (start,))])
        visited: set[tuple[str, int]] = set()

        while queue:
            current, depth, confidence, path = queue.popleft()

            if depth >= question.max_depth:
                continue

            state = (current, depth)
            if state in visited:
                continue
            visited.add(state)

            for edge in self.graph.outgoing(
                current,
                validated_only=True,
            ):
                if (
                    relation_filter
                    and edge.relation_type not in relation_filter
                ):
                    continue

                rule = rule_for_relation(edge.relation_type)
                next_confidence = confidence * edge.weight
                evidence = (*path, edge.target_id)

                conclusion = ReasoningConclusion(
                    subject_id=start,
                    relation_type=edge.relation_type,
                    object_id=edge.target_id,
                    confidence=round(next_confidence, 6),
                    explanation=(
                        rule.explanation_template.format(
                            subject=start,
                            object=edge.target_id,
                        )
                        if rule is not None
                        else (
                            f"{start} se relaciona con "
                            f"{edge.target_id} mediante "
                            f"{edge.relation_type}."
                        )
                    ),
                    evidence=evidence,
                )

                conclusions[
                    (
                        conclusion.subject_id,
                        conclusion.relation_type,
                        conclusion.object_id,
                    )
                ] = conclusion

                if rule is not None and rule.transitive:
                    queue.append(
                        (
                            edge.target_id,
                            depth + 1,
                            next_confidence,
                            evidence,
                        )
                    )

        ordered = tuple(
            conclusions[key]
            for key in sorted(
                conclusions,
                key=lambda item: (
                    -conclusions[item].confidence,
                    item,
                ),
            )
        )

        return ReasoningResponse(
            question=question,
            conclusions=ordered,
            unresolved=not ordered,
            metadata={
                "start_node_id": start,
                "evaluated_relations": sorted(relation_filter),
            },
        )