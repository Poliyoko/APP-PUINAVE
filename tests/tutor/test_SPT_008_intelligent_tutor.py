from sgoda.knowledge_engine import (
    KnowledgeEdge,
    KnowledgeGraph,
    KnowledgeNode,
)
from sgoda.tutor import PuinaveTutorService


def _graph():
    graph = KnowledgeGraph()
    graph.add_node(
        KnowledgeNode(
            "LEX-001",
            "lexical_entry",
            "AMDA",
            language="pu",
            validated=True,
            source_ref="RLB:LEX-001",
        )
    )
    graph.add_node(
        KnowledgeNode(
            "CON-001",
            "concept",
            "Casa",
            validated=True,
        )
    )
    graph.add_edge(
        KnowledgeEdge(
            "LEX-001",
            "CON-001",
            "related_to",
            validated=True,
        )
    )
    return graph


def test_SPT_008_builds_learning_path():
    result = PuinaveTutorService(_graph()).create_path(
        "USR-001",
        "LEX-001",
    )
    assert result["activities"]
    assert result["no_invention"] is True


def test_SPT_008_activity_references_rlb_entry():
    result = PuinaveTutorService(_graph()).create_path(
        "USR-001",
        "LEX-001",
    )
    assert result["activities"][0]["entry_ids"] == ["LEX-001"]


def test_SPT_008_evaluates_correct_answer():
    service = PuinaveTutorService(_graph())
    path = service.create_path("USR-001", "LEX-001")
    feedback = service.evaluate(
        path["activities"][0],
        "AMDA",
    )
    assert feedback["correct"] is True
    assert feedback["score"] == 1.0


def test_SPT_008_evaluates_incorrect_answer():
    service = PuinaveTutorService(_graph())
    path = service.create_path("USR-001", "LEX-001")
    feedback = service.evaluate(
        path["activities"][0],
        "OTRA",
    )
    assert feedback["correct"] is False
    assert feedback["remediation"]


def test_SPT_008_is_deterministic():
    service = PuinaveTutorService(_graph())
    first = service.create_path("USR-001", "LEX-001")
    second = service.create_path("USR-001", "LEX-001")
    assert first == second


def test_SPT_008_does_not_create_unknown_content():
    result = PuinaveTutorService(_graph()).create_path(
        "USR-001",
        "UNKNOWN",
    )
    assert result["activities"] == []
    assert result["no_invention"] is True