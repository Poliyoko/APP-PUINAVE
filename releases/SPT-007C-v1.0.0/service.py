"""Servicio principal del Motor de Conocimiento SPT-007C."""

from __future__ import annotations

from .graph import KnowledgeGraph
from .inference import explain_inference, infer_transitive_edges
from .models import KnowledgeResult
from .navigation import concept_path, recommend_related
from .oda_bridge import learning_resources


class KnowledgeEngineService:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.graph = graph

    def explore(
        self,
        node_id: str,
        depth: int = 2,
        include_inference: bool = True,
    ) -> KnowledgeResult:
        nodes, edges = self.graph.neighborhood(
            node_id,
            depth=depth,
            validated_only=True,
        )

        inferred = (
            infer_transitive_edges(
                self.graph,
                node_id,
                max_depth=max(2, depth + 1),
            )
            if include_inference
            else ()
        )

        known_ids = {item.node_id for item in nodes}

        inferred_targets = [
            self.graph.get_node(item.target_id)
            for item in inferred
            if item.target_id not in known_ids
        ]

        merged_nodes = {
            item.node_id: item
            for item in (
                *nodes,
                *(
                    item
                    for item in inferred_targets
                    if item is not None
                ),
            )
        }

        merged_edges = {
            (
                item.source_id,
                item.target_id,
                item.relation_type,
            ): item
            for item in (*edges, *inferred)
        }

        return KnowledgeResult(
            query_node_id=node_id,
            nodes=tuple(
                merged_nodes[key]
                for key in sorted(merged_nodes)
            ),
            edges=tuple(
                merged_edges[key]
                for key in sorted(merged_edges)
            ),
            inference_steps=explain_inference(inferred),
            no_invention=True,
        )

    def query(self, node_id: str) -> dict:
        result = self.explore(node_id)

        return {
            "query_node_id": result.query_node_id,
            "no_invention": result.no_invention,
            "nodes": [
                {
                    "node_id": item.node_id,
                    "node_type": item.node_type,
                    "label": item.label,
                    "language": item.language,
                    "validated": item.validated,
                    "cultural_status": item.cultural_status,
                    "source_ref": item.source_ref,
                    "metadata": item.metadata,
                }
                for item in result.nodes
            ],
            "edges": [
                {
                    "source_id": item.source_id,
                    "target_id": item.target_id,
                    "relation_type": item.relation_type,
                    "weight": item.weight,
                    "validated": item.validated,
                    "cultural": item.cultural,
                    "source_ref": item.source_ref,
                    "metadata": item.metadata,
                }
                for item in result.edges
            ],
            "inference": [
                {
                    "source_id": item.source_id,
                    "target_id": item.target_id,
                    "relation_type": item.relation_type,
                    "rule_code": item.rule_code,
                    "explanation": item.explanation,
                }
                for item in result.inference_steps
            ],
            "recommendations": list(
                recommend_related(self.graph, node_id)
            ),
            "learning_resources": learning_resources(
                self.graph,
                node_id,
            ),
        }

    def path(
        self,
        source_id: str,
        target_id: str,
    ) -> tuple[str, ...]:
        return concept_path(
            self.graph,
            source_id,
            target_id,
        )