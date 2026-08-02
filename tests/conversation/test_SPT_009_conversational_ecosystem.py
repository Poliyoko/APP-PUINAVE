from sgoda.conversation import (
    ConversationMessage,
    ConversationRequest,
    ConversationalEcosystemService,
)
from sgoda.knowledge_engine import (
    KnowledgeEdge,
    KnowledgeEngineService,
    KnowledgeGraph,
    KnowledgeNode,
)
from sgoda.reasoning_engine import LinguisticReasoningService
from sgoda.tutor import PuinaveTutorService


def _services():
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

    return ConversationalEcosystemService(
        KnowledgeEngineService(graph),
        LinguisticReasoningService(graph),
        PuinaveTutorService(graph),
    )


def test_SPT_009_routes_tutor_intent():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Quiero aprender esta palabra",
            ),
            context_node_id="LEX-001",
        )
    )
    assert response.intent == "tutor"
    assert response.unresolved is False


def test_SPT_009_routes_reasoning_intent():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Explica la relación",
            ),
            context_node_id="LEX-001",
        )
    )
    assert response.intent == "reasoning"


def test_SPT_009_returns_knowledge_response():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Muéstrame información",
            ),
            context_node_id="LEX-001",
        )
    )
    assert response.intent == "knowledge"
    assert response.text
    assert response.no_invention is True


def test_SPT_009_requires_validated_context():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Consulta",
            ),
            context_node_id=None,
        )
    )
    assert response.unresolved is True
    assert response.sources == ()


def test_SPT_009_prepares_audio_text():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Muéstrame información",
                language="es",
            ),
            context_node_id="LEX-001",
        )
    )
    assert response.audio_text == response.text


def test_SPT_009_keeps_session_memory():
    service = _services()
    request = ConversationRequest(
        "SES-001",
        ConversationMessage(
            "user",
            "Muéstrame información",
        ),
        context_node_id="LEX-001",
    )
    service.converse(request)
    assert len(service.memory.history("SES-001")) == 2