"""Integración gobernada con ODA y multimedia."""

from __future__ import annotations

from .graph import KnowledgeGraph


def learning_resources(
    graph: KnowledgeGraph,
    node_id: str,
) -> dict:
    media = []
    odas = []

    for edge in graph.outgoing(
        node_id,
        validated_only=True,
    ):
        target = graph.get_node(edge.target_id)

        if target is None:
            continue

        if edge.relation_type == "has_media":
            media.append(
                {
                    "node_id": target.node_id,
                    "label": target.label,
                    "source_ref": target.source_ref,
                    "metadata": target.metadata,
                }
            )

        if edge.relation_type == "has_oda":
            odas.append(
                {
                    "node_id": target.node_id,
                    "label": target.label,
                    "source_ref": target.source_ref,
                    "metadata": target.metadata,
                }
            )

    return {
        "node_id": node_id,
        "media": sorted(media, key=lambda item: item["node_id"]),
        "odas": sorted(odas, key=lambda item: item["node_id"]),
    }