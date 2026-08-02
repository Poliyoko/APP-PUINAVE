"""Fachada integrada de la Plataforma Digital."""

from __future__ import annotations

from typing import Any

from sgoda.conversation import (
    ConversationMessage,
    ConversationRequest,
    ConversationalEcosystemService,
)
from sgoda.knowledge_engine import KnowledgeEngineService, KnowledgeGraph
from sgoda.reasoning_engine import LinguisticReasoningService
from sgoda.tutor import PuinaveTutorService

from .models import PlatformRequest, PlatformResponse
from .registry import CapabilityRegistry


class IntegratedPlatformFacade:
    def __init__(
        self,
        graph: KnowledgeGraph,
        registry: CapabilityRegistry,
    ) -> None:
        self.graph = graph
        self.registry = registry
        self.knowledge = KnowledgeEngineService(graph)
        self.reasoning = LinguisticReasoningService(graph)
        self.tutor = PuinaveTutorService(graph)
        self.conversation = ConversationalEcosystemService(
            self.knowledge,
            self.reasoning,
            self.tutor,
        )

    def execute(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        if request.operation not in self.registry.operations():
            return PlatformResponse(
                operation=request.operation,
                status="unsupported_operation",
                data={},
                warnings=(
                    "La operación no está registrada.",
                ),
            )

        handlers = {
            "knowledge": self._knowledge,
            "reasoning": self._reasoning,
            "learning_path": self._learning_path,
            "evaluate_activity": self._evaluate_activity,
            "conversation": self._conversation,
            "identity": self._identity,
            "translate": self._not_yet_bound,
            "tts": self._not_yet_bound,
            "lexical_search": self._not_yet_bound,
            "semantic_search": self._not_yet_bound,
        }

        handler = handlers.get(
            request.operation,
            self._not_yet_bound,
        )
        return handler(request)

    def _knowledge(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        node_id = (
            request.context_node_id
            or str(request.payload.get("node_id") or "")
        )

        if not node_id:
            return PlatformResponse(
                "knowledge",
                "validation_error",
                {},
                warnings=("node_id es obligatorio.",),
            )

        payload = self.knowledge.query(node_id)
        sources = tuple(
            item["source_ref"]
            for item in payload["nodes"]
            if item.get("source_ref")
        )

        return PlatformResponse(
            "knowledge",
            "ok" if payload["nodes"] else "not_found",
            payload,
            sources=tuple(dict.fromkeys(sources)),
        )

    def _reasoning(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        node_id = (
            request.context_node_id
            or str(request.payload.get("node_id") or "")
        )
        text = str(request.payload.get("question") or "")

        payload = self.reasoning.ask(
            text=text,
            start_node_id=node_id,
            relations=tuple(
                request.payload.get("relations", ())
            ),
            max_depth=int(
                request.payload.get("max_depth", 3)
            ),
        )

        sources = tuple(
            value
            for conclusion in payload["conclusions"]
            for value in conclusion["evidence"]
        )

        return PlatformResponse(
            "reasoning",
            "ok" if not payload["unresolved"] else "unresolved",
            payload,
            sources=tuple(dict.fromkeys(sources)),
        )

    def _learning_path(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        node_id = (
            request.context_node_id
            or str(request.payload.get("node_id") or "")
        )

        payload = self.tutor.create_path(
            learner_id=request.session_id,
            seed_node_id=node_id,
            level=str(
                request.payload.get("level", "beginner")
            ),
            preferred_language=request.language,
        )

        sources = tuple(
            entry_id
            for activity in payload["activities"]
            for entry_id in activity["entry_ids"]
        )

        return PlatformResponse(
            "learning_path",
            "ok" if payload["activities"] else "not_found",
            payload,
            sources=tuple(dict.fromkeys(sources)),
        )

    def _evaluate_activity(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        activity = request.payload.get("activity")
        answer = str(request.payload.get("answer") or "")

        if not isinstance(activity, dict):
            return PlatformResponse(
                "evaluate_activity",
                "validation_error",
                {},
                warnings=("activity debe ser un objeto.",),
            )

        return PlatformResponse(
            "evaluate_activity",
            "ok",
            self.tutor.evaluate(activity, answer),
        )

    def _conversation(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        message = str(request.payload.get("message") or "")

        response = self.conversation.converse(
            ConversationRequest(
                session_id=request.session_id,
                message=ConversationMessage(
                    role="user",
                    text=message,
                    language=request.language,
                ),
                context_node_id=request.context_node_id,
            )
        )

        return PlatformResponse(
            "conversation",
            "ok" if not response.unresolved else "unresolved",
            {
                "session_id": response.session_id,
                "text": response.text,
                "language": response.language,
                "intent": response.intent,
                "audio_text": response.audio_text,
                "unresolved": response.unresolved,
            },
            sources=response.sources,
        )

    def _identity(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        return PlatformResponse(
            "identity",
            "ok",
            {
                "display_name": request.payload.get(
                    "display_name",
                    "SGODA-PUINAVE",
                ),
                "configurable": True,
                "requires_community_approval": True,
            },
        )

    def _not_yet_bound(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        return PlatformResponse(
            request.operation,
            "adapter_pending",
            {
                "registered": True,
                "message": (
                    "La capacidad está registrada y requiere "
                    "un adaptador de datos operativo."
                ),
            },
            warnings=("Adaptador operativo pendiente.",),
        )