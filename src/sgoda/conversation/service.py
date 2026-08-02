from __future__ import annotations

from sgoda.knowledge_engine.service import KnowledgeEngineService
from sgoda.reasoning_engine.service import LinguisticReasoningService
from sgoda.tutor.service import PuinaveTutorService

from .memory import ConversationMemory
from .models import (
    ConversationMessage,
    ConversationRequest,
    ConversationResponse,
)
from .router import classify_conversation_intent


class ConversationalEcosystemService:
    def __init__(
        self,
        knowledge: KnowledgeEngineService,
        reasoning: LinguisticReasoningService,
        tutor: PuinaveTutorService,
        memory: ConversationMemory | None = None,
    ) -> None:
        self.knowledge = knowledge
        self.reasoning = reasoning
        self.tutor = tutor
        self.memory = memory or ConversationMemory()

    def converse(
        self,
        request: ConversationRequest,
    ) -> ConversationResponse:
        self.memory.add(
            request.session_id,
            request.message,
        )

        intent = classify_conversation_intent(
            request.message.text
        )
        node_id = request.context_node_id
        language = request.message.language

        if not node_id:
            response = ConversationResponse(
                session_id=request.session_id,
                text=(
                    "Necesito una palabra o concepto validado "
                    "del repositorio para responder."
                ),
                language=language,
                intent=intent,
                sources=(),
                unresolved=True,
            )
            self.memory.add(
                request.session_id,
                ConversationMessage(
                    role="assistant",
                    text=response.text,
                    language=language,
                ),
            )
            return response

        if intent == "tutor":
            payload = self.tutor.create_path(
                learner_id=request.session_id,
                seed_node_id=node_id,
            )
            activities = payload["activities"]
            text = (
                activities[0]["instructions"]
                if activities
                else "No hay una actividad validada disponible."
            )
            sources = tuple(
                entry_id
                for activity in activities
                for entry_id in activity["entry_ids"]
            )
            unresolved = not activities

        elif intent == "reasoning":
            payload = self.reasoning.ask(
                request.message.text,
                node_id,
            )
            conclusions = payload["conclusions"]
            text = (
                conclusions[0]["explanation"]
                if conclusions
                else "No encontré una relación validada."
            )
            sources = tuple(
                source
                for item in conclusions[:3]
                for source in item["evidence"]
            )
            unresolved = not conclusions

        else:
            payload = self.knowledge.query(node_id)
            nodes = payload["nodes"]
            text = (
                "Conocimiento relacionado: "
                + ", ".join(
                    item["label"]
                    for item in nodes[:5]
                )
                if nodes
                else "No encontré conocimiento validado."
            )
            sources = tuple(
                item["source_ref"]
                for item in nodes
                if item.get("source_ref")
            )
            unresolved = not nodes

        response = ConversationResponse(
            session_id=request.session_id,
            text=text,
            language=language,
            intent=intent,
            sources=tuple(dict.fromkeys(sources)),
            audio_text=text,
            unresolved=unresolved,
        )

        self.memory.add(
            request.session_id,
            ConversationMessage(
                role="assistant",
                text=response.text,
                language=language,
                metadata={"intent": intent},
            ),
        )

        return response