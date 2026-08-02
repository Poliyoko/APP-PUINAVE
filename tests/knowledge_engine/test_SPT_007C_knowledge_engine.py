import json
from pathlib import Path

import pytest

from sgoda.knowledge_engine import (
    KnowledgeEdge,
    KnowledgeEngineService,
    KnowledgeGraph,
    KnowledgeNode,
    concept_path,
    infer_transitive_edges,
    learning_resources,
    recommend_related,
)


def _graph() -> KnowledgeGraph:
    graph = KnowledgeGraph()

    for node in (
        KnowledgeNode(
            "LEX-001",
            "lexical_entry",
            "AMDA",
            language="pu",
            validated=True,
            source_ref="RLB:LEX-001",
        ),
        KnowledgeNode(
            "CON-001",
            "concept",
            "Casa",
            language="es",
            validated=True,
        ),
        KnowledgeNode(
            "CON-002",
            "concept",
            "Vivienda",
            language="es",
            validated=True,
        ),
        KnowledgeNode(
            "CAT-001",
            "category",
            "Construcciones",
            validated=True,
        ),
        KnowledgeNode(
            "ODA-001",
            "oda",
            "Aprender AMDA",
            validated=True,
            source_ref="ODA:ODA-001",
        ),
        KnowledgeNode(
            "MED-001",
            "media",
            "Imagen de casa",
            validated=True,
            source_ref="media/images/LEX-001.webp",
        ),
    ):
        graph.add_node(node)

    for edge in (
        KnowledgeEdge(
            "LEX-001",
            "CON-001",
            "related_to",
            validated=True,
        ),
        KnowledgeEdge(
            "CON-001",
            "CON-002",
            "is_a",
            validated=True,
        ),
        KnowledgeEdge(
            "CON-002",
            "CAT-001",
            "is_a",
            validated=True,
        ),
        KnowledgeEdge(
            "LEX-001",
            "ODA-001",
            "has_oda",
            validated=True,
        ),
        KnowledgeEdge(
            "LEX-001",
            "MED-001",
            "has_media",
            validated=True,
        ),
    ):
        graph.add_edge(edge)

    return graph


def test_SPT_007C_builds_knowledge_graph() -> None:
    graph = _graph()

    assert graph.get_node("LEX-001").label == "AMDA"
    assert len(graph.nodes()) == 6


def test_SPT_007C_rejects_unknown_node_type() -> None:
    graph = KnowledgeGraph()

    with pytest.raises(ValueError):
        graph.add_node(
            KnowledgeNode(
                "X",
                "unknown_type",
                "X",
            )
        )


def test_SPT_007C_rejects_unknown_relation() -> None:
    graph = KnowledgeGraph()
    graph.add_node(KnowledgeNode("A", "concept", "A"))
    graph.add_node(KnowledgeNode("B", "concept", "B"))

    with pytest.raises(ValueError):
        graph.add_edge(
            KnowledgeEdge(
                "A",
                "B",
                "invented_relation",
            )
        )


def test_SPT_007C_creates_symmetric_relation() -> None:
    graph = _graph()
    reverse = [
        item
        for item in graph.outgoing("CON-001")
        if item.target_id == "LEX-001"
    ]

    assert reverse
    assert reverse[0].metadata["generated_reverse"] is True


def test_SPT_007C_neighborhood_is_deterministic() -> None:
    graph = _graph()

    first = graph.neighborhood("LEX-001", depth=2)
    second = graph.neighborhood("LEX-001", depth=2)

    assert first == second


def test_SPT_007C_infers_transitive_relation() -> None:
    inferred = infer_transitive_edges(
        _graph(),
        "CON-001",
        max_depth=3,
    )

    targets = {
        item.target_id
        for item in inferred
        if item.relation_type == "is_a"
    }

    assert "CAT-001" in targets


def test_SPT_007C_inference_is_explainable() -> None:
    result = KnowledgeEngineService(_graph()).explore(
        "CON-001",
        depth=2,
        include_inference=True,
    )

    assert result.inference_steps
    assert result.inference_steps[0].rule_code


def test_SPT_007C_finds_concept_path() -> None:
    path = concept_path(
        _graph(),
        "CON-001",
        "CAT-001",
    )

    assert path == (
        "CON-001",
        "CON-002",
        "CAT-001",
    )


def test_SPT_007C_recommends_related_nodes() -> None:
    recommendations = recommend_related(
        _graph(),
        "LEX-001",
    )

    assert "CON-001" in recommendations
    assert "ODA-001" in recommendations


def test_SPT_007C_integrates_oda_and_media() -> None:
    resources = learning_resources(
        _graph(),
        "LEX-001",
    )

    assert resources["odas"][0]["node_id"] == "ODA-001"
    assert resources["media"][0]["node_id"] == "MED-001"


def test_SPT_007C_no_invention_contract() -> None:
    payload = KnowledgeEngineService(_graph()).query(
        "LEX-001"
    )

    assert payload["no_invention"] is True
    assert all(
        _graph().get_node(item["node_id"]) is not None
        for item in payload["nodes"]
    )


def test_SPT_007C_uses_validated_edges_only() -> None:
    graph = _graph()
    graph.add_node(
        KnowledgeNode(
            "CON-999",
            "concept",
            "No validado",
            validated=False,
        )
    )
    graph.add_edge(
        KnowledgeEdge(
            "LEX-001",
            "CON-999",
            "related_to",
            validated=False,
        )
    )

    nodes, _ = graph.neighborhood(
        "LEX-001",
        depth=1,
        validated_only=True,
    )

    assert "CON-999" not in {
        item.node_id for item in nodes
    }


def test_SPT_007C_reads_json_graph(tmp_path: Path) -> None:
    path = tmp_path / "graph.json"
    path.write_text(
        json.dumps(
            {
                "nodes": [
                    {
                        "node_id": "A",
                        "node_type": "concept",
                        "label": "A",
                        "validated": True,
                    },
                    {
                        "node_id": "B",
                        "node_type": "concept",
                        "label": "B",
                        "validated": True,
                    },
                ],
                "edges": [
                    {
                        "source_id": "A",
                        "target_id": "B",
                        "relation_type": "related_to",
                        "validated": True,
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    graph = KnowledgeGraph.from_json(path)

    assert graph.get_node("A").label == "A"
    assert graph.outgoing("A")[0].target_id == "B"


def test_SPT_007C_service_serializes_query() -> None:
    payload = KnowledgeEngineService(_graph()).query(
        "LEX-001"
    )

    assert payload["query_node_id"] == "LEX-001"
    assert payload["learning_resources"]["odas"]
    assert payload["recommendations"]