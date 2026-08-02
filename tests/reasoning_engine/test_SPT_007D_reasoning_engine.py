from sgoda.knowledge_engine import (
    KnowledgeEdge,
    KnowledgeGraph,
    KnowledgeNode,
)
from sgoda.reasoning_engine import LinguisticReasoningService


def _graph():
    graph = KnowledgeGraph()

    for node in (
        KnowledgeNode("A", "concept", "A", validated=True),
        KnowledgeNode("B", "concept", "B", validated=True),
        KnowledgeNode("C", "category", "C", validated=True),
    ):
        graph.add_node(node)

    graph.add_edge(
        KnowledgeEdge(
            "A",
            "B",
            "is_a",
            validated=True,
        )
    )
    graph.add_edge(
        KnowledgeEdge(
            "B",
            "C",
            "is_a",
            validated=True,
        )
    )
    return graph


def test_SPT_007D_returns_direct_conclusion():
    result = LinguisticReasoningService(_graph()).ask(
        "¿Qué es A?",
        "A",
        ("is_a",),
    )
    assert result["conclusions"]
    assert result["conclusions"][0]["subject_id"] == "A"


def test_SPT_007D_supports_transitive_reasoning():
    result = LinguisticReasoningService(_graph()).ask(
        "¿A pertenece a C?",
        "A",
        ("is_a",),
        max_depth=3,
    )
    objects = {
        item["object_id"]
        for item in result["conclusions"]
    }
    assert "C" in objects


def test_SPT_007D_is_explainable():
    result = LinguisticReasoningService(_graph()).ask(
        "Explica A",
        "A",
        ("is_a",),
    )
    assert result["conclusions"][0]["explanation"]
    assert result["conclusions"][0]["evidence"]


def test_SPT_007D_no_invention_when_node_missing():
    result = LinguisticReasoningService(_graph()).ask(
        "Consulta inexistente",
        "ZZZ",
    )
    assert result["unresolved"] is True
    assert result["no_invention"] is True
    assert result["conclusions"] == []


def test_SPT_007D_uses_validated_edges_only():
    graph = _graph()
    graph.add_node(
        KnowledgeNode("X", "concept", "X", validated=False)
    )
    graph.add_edge(
        KnowledgeEdge(
            "A",
            "X",
            "is_a",
            validated=False,
        )
    )
    result = LinguisticReasoningService(graph).ask(
        "Consulta",
        "A",
        ("is_a",),
    )
    assert "X" not in {
        item["object_id"]
        for item in result["conclusions"]
    }


def test_SPT_007D_is_deterministic():
    service = LinguisticReasoningService(_graph())
    first = service.ask("Consulta", "A", ("is_a",))
    second = service.ask("Consulta", "A", ("is_a",))
    assert first == second