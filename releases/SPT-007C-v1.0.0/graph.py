"""Grafo de conocimiento local, determinista y gobernado."""

from __future__ import annotations

import json
from collections import defaultdict, deque
from pathlib import Path
from typing import Any

from .models import KnowledgeEdge, KnowledgeNode
from .ontology import (
    SYMMETRIC_RELATIONS,
    is_allowed_node_type,
    is_allowed_relation_type,
)


class KnowledgeGraph:
    def __init__(self) -> None:
        self._nodes: dict[str, KnowledgeNode] = {}
        self._outgoing: dict[str, list[KnowledgeEdge]] = defaultdict(list)
        self._incoming: dict[str, list[KnowledgeEdge]] = defaultdict(list)

    def add_node(self, node: KnowledgeNode) -> None:
        if not node.node_id.strip():
            raise ValueError("node_id es obligatorio.")

        if not is_allowed_node_type(node.node_type):
            raise ValueError(
                f"Tipo de nodo no permitido: {node.node_type}"
            )

        self._nodes[node.node_id] = node

    def add_edge(self, edge: KnowledgeEdge) -> None:
        if edge.source_id == edge.target_id:
            raise ValueError("No se permiten relaciones autorreferenciales.")

        if edge.source_id not in self._nodes:
            raise KeyError(f"Nodo origen inexistente: {edge.source_id}")

        if edge.target_id not in self._nodes:
            raise KeyError(f"Nodo destino inexistente: {edge.target_id}")

        if not is_allowed_relation_type(edge.relation_type):
            raise ValueError(
                f"Tipo de relación no permitido: {edge.relation_type}"
            )

        normalized = KnowledgeEdge(
            source_id=edge.source_id,
            target_id=edge.target_id,
            relation_type=edge.relation_type.casefold(),
            weight=max(0.0, min(1.0, edge.weight)),
            validated=edge.validated,
            cultural=edge.cultural,
            source_ref=edge.source_ref,
            metadata=edge.metadata,
        )

        self._outgoing[normalized.source_id].append(normalized)
        self._incoming[normalized.target_id].append(normalized)

        if normalized.relation_type in SYMMETRIC_RELATIONS:
            reverse = KnowledgeEdge(
                source_id=normalized.target_id,
                target_id=normalized.source_id,
                relation_type=normalized.relation_type,
                weight=normalized.weight,
                validated=normalized.validated,
                cultural=normalized.cultural,
                source_ref=normalized.source_ref,
                metadata={
                    **normalized.metadata,
                    "generated_reverse": True,
                },
            )
            self._outgoing[reverse.source_id].append(reverse)
            self._incoming[reverse.target_id].append(reverse)

    def get_node(self, node_id: str) -> KnowledgeNode | None:
        return self._nodes.get(node_id)

    def nodes(self) -> tuple[KnowledgeNode, ...]:
        return tuple(
            self._nodes[key]
            for key in sorted(self._nodes)
        )

    def outgoing(
        self,
        node_id: str,
        validated_only: bool = True,
    ) -> tuple[KnowledgeEdge, ...]:
        edges = self._outgoing.get(node_id, [])

        if validated_only:
            edges = [item for item in edges if item.validated]

        return tuple(
            sorted(
                edges,
                key=lambda item: (
                    item.relation_type,
                    item.target_id,
                ),
            )
        )

    def neighborhood(
        self,
        node_id: str,
        depth: int = 1,
        validated_only: bool = True,
    ) -> tuple[tuple[KnowledgeNode, ...], tuple[KnowledgeEdge, ...]]:
        if node_id not in self._nodes:
            return (), ()

        visited = {node_id}
        queue = deque([(node_id, 0)])
        edges: list[KnowledgeEdge] = []

        while queue:
            current, current_depth = queue.popleft()

            if current_depth >= max(0, depth):
                continue

            for edge in self.outgoing(
                current,
                validated_only=validated_only,
            ):
                edges.append(edge)

                if edge.target_id not in visited:
                    visited.add(edge.target_id)
                    queue.append(
                        (edge.target_id, current_depth + 1)
                    )

        nodes = tuple(
            self._nodes[item]
            for item in sorted(visited)
            if item in self._nodes
        )

        unique_edges = {
            (
                item.source_id,
                item.target_id,
                item.relation_type,
            ): item
            for item in edges
        }

        return nodes, tuple(
            unique_edges[key]
            for key in sorted(unique_edges)
        )

    @classmethod
    def from_records(
        cls,
        nodes: list[dict[str, Any]],
        edges: list[dict[str, Any]],
    ) -> "KnowledgeGraph":
        graph = cls()

        for item in nodes:
            graph.add_node(
                KnowledgeNode(
                    node_id=str(item.get("node_id") or "").strip(),
                    node_type=str(item.get("node_type") or "").strip(),
                    label=str(item.get("label") or "").strip(),
                    language=(
                        str(item.get("language")).strip()
                        if item.get("language")
                        else None
                    ),
                    validated=bool(item.get("validated", False)),
                    cultural_status=str(
                        item.get("cultural_status", "pending")
                    ),
                    source_ref=(
                        str(item.get("source_ref")).strip()
                        if item.get("source_ref")
                        else None
                    ),
                    metadata={
                        key: value
                        for key, value in item.items()
                        if key not in {
                            "node_id",
                            "node_type",
                            "label",
                            "language",
                            "validated",
                            "cultural_status",
                            "source_ref",
                        }
                    },
                )
            )

        for item in edges:
            graph.add_edge(
                KnowledgeEdge(
                    source_id=str(
                        item.get("source_id") or ""
                    ).strip(),
                    target_id=str(
                        item.get("target_id") or ""
                    ).strip(),
                    relation_type=str(
                        item.get("relation_type") or ""
                    ).strip(),
                    weight=float(item.get("weight", 1.0)),
                    validated=bool(item.get("validated", False)),
                    cultural=bool(item.get("cultural", False)),
                    source_ref=(
                        str(item.get("source_ref")).strip()
                        if item.get("source_ref")
                        else None
                    ),
                    metadata={
                        key: value
                        for key, value in item.items()
                        if key not in {
                            "source_id",
                            "target_id",
                            "relation_type",
                            "weight",
                            "validated",
                            "cultural",
                            "source_ref",
                        }
                    },
                )
            )

        return graph

    @classmethod
    def from_json(cls, path: str | Path) -> "KnowledgeGraph":
        payload = json.loads(
            Path(path).read_text(encoding="utf-8-sig")
        )

        return cls.from_records(
            list(payload.get("nodes", [])),
            list(payload.get("edges", [])),
        )