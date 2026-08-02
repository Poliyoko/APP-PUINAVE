"""Navegación conceptual y recomendaciones."""

from __future__ import annotations

from .graph import KnowledgeGraph


def concept_path(
    graph: KnowledgeGraph,
    source_id: str,
    target_id: str,
    max_depth: int = 4,
) -> tuple[str, ...]:
    if source_id == target_id:
        return (source_id,)

    queue: list[tuple[str, tuple[str, ...]]] = [
        (source_id, (source_id,))
    ]
    visited = {source_id}

    while queue:
        current, path = queue.pop(0)

        if len(path) > max_depth + 1:
            continue

        for edge in graph.outgoing(
            current,
            validated_only=True,
        ):
            if edge.target_id == target_id:
                return (*path, target_id)

            if edge.target_id not in visited:
                visited.add(edge.target_id)
                queue.append(
                    (
                        edge.target_id,
                        (*path, edge.target_id),
                    )
                )

    return ()


def recommend_related(
    graph: KnowledgeGraph,
    node_id: str,
    limit: int = 10,
) -> tuple[str, ...]:
    scores: dict[str, float] = {}

    for edge in graph.outgoing(
        node_id,
        validated_only=True,
    ):
        scores[edge.target_id] = max(
            scores.get(edge.target_id, 0.0),
            edge.weight,
        )

    return tuple(
        item
        for item, _ in sorted(
            scores.items(),
            key=lambda pair: (-pair[1], pair[0]),
        )[: max(0, limit)]
    )