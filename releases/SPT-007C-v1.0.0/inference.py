"""Inferencia controlada, explicable y sin invención."""

from __future__ import annotations

from collections import defaultdict

from .graph import KnowledgeGraph
from .models import InferenceStep, KnowledgeEdge
from .ontology import TRANSITIVE_RELATIONS


def infer_transitive_edges(
    graph: KnowledgeGraph,
    source_id: str,
    max_depth: int = 3,
) -> tuple[KnowledgeEdge, ...]:
    inferred: dict[
        tuple[str, str, str],
        KnowledgeEdge,
    ] = {}

    grouped: dict[str, list[KnowledgeEdge]] = defaultdict(list)

    for edge in graph.outgoing(source_id, validated_only=True):
        if edge.relation_type in TRANSITIVE_RELATIONS:
            grouped[edge.relation_type].append(edge)

    for relation_type, first_edges in grouped.items():
        frontier = [
            (edge.target_id, 1, edge.weight)
            for edge in first_edges
        ]
        visited = {source_id}

        while frontier:
            current, depth, weight = frontier.pop(0)

            if current in visited:
                continue

            visited.add(current)

            if depth >= 2:
                inferred[
                    (source_id, current, relation_type)
                ] = KnowledgeEdge(
                    source_id=source_id,
                    target_id=current,
                    relation_type=relation_type,
                    weight=round(weight, 6),
                    validated=True,
                    cultural=False,
                    source_ref="SPT-007C-INFERENCE",
                    metadata={
                        "inferred": True,
                        "depth": depth,
                    },
                )

            if depth >= max_depth:
                continue

            for edge in graph.outgoing(
                current,
                validated_only=True,
            ):
                if edge.relation_type != relation_type:
                    continue

                frontier.append(
                    (
                        edge.target_id,
                        depth + 1,
                        weight * edge.weight,
                    )
                )

    return tuple(
        inferred[key]
        for key in sorted(inferred)
    )


def explain_inference(
    edges: tuple[KnowledgeEdge, ...],
) -> tuple[InferenceStep, ...]:
    return tuple(
        InferenceStep(
            source_id=edge.source_id,
            relation_type=edge.relation_type,
            target_id=edge.target_id,
            rule_code="SPT007C-RULE-TRANSITIVE",
            explanation=(
                f"{edge.source_id} se relaciona con "
                f"{edge.target_id} mediante transitividad "
                f"de {edge.relation_type}."
            ),
        )
        for edge in edges
    )