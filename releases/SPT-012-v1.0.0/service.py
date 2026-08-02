"""Servicio principal de SPT-012."""

from __future__ import annotations

from .curriculum import build_learning_path
from .digital_dictionary import DigitalDictionary
from .integration_bridge import IntegrationBridge
from .media_library import MediaLibrary
from .models import LearningRequest, LearningResponse
from .oda_factory import build_oda
from .progress import ProgressTracker


class LearningPlatformService:
    def __init__(
        self,
        dictionary: DigitalDictionary,
        media: MediaLibrary,
        progress: ProgressTracker | None = None,
        bridge: IntegrationBridge | None = None,
    ) -> None:
        self.dictionary = dictionary
        self.media = media
        self.progress = progress or ProgressTracker()
        self.bridge = bridge or IntegrationBridge()

    def execute(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        handlers = {
            "search_dictionary": self._search_dictionary,
            "get_oda": self._get_oda,
            "build_path": self._build_path,
            "evaluate_answer": self._evaluate_answer,
            "record_progress": self._record_progress,
            "get_progress": self._get_progress,
            "capabilities": self._capabilities,
        }

        handler = handlers.get(request.operation)

        if handler is None:
            return LearningResponse(
                operation=request.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(request)

    def _entry(
        self,
        request: LearningRequest,
    ) -> dict | None:
        entry_id = (
            request.entry_id
            or str(request.payload.get("entry_id") or "")
        )
        return self.dictionary.get(entry_id)

    def _search_dictionary(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        query = str(request.payload.get("query") or "")
        results = self.dictionary.search(query)

        return LearningResponse(
            operation="search_dictionary",
            status="ok",
            data={
                "query": query,
                "total": len(results),
                "results": list(results),
            },
            sources=tuple(
                f"RLB:{item['entry_id']}"
                for item in results
            ),
        )

    def _get_oda(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry = self._entry(request)

        if entry is None:
            return LearningResponse(
                operation="get_oda",
                status="not_found",
                data={},
            )

        return LearningResponse(
            operation="get_oda",
            status="ok",
            data=build_oda(
                entry,
                self.media.for_entry(entry["entry_id"]),
            ),
            sources=(f"RLB:{entry['entry_id']}",),
        )

    def _build_path(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry = self._entry(request)

        if entry is None:
            return LearningResponse(
                operation="build_path",
                status="not_found",
                data={},
            )

        level = str(request.payload.get("level") or "initial")

        return LearningResponse(
            operation="build_path",
            status="ok",
            data=build_learning_path(entry, level),
            sources=(f"RLB:{entry['entry_id']}",),
        )

    def _evaluate_answer(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry = self._entry(request)

        if entry is None:
            return LearningResponse(
                operation="evaluate_answer",
                status="not_found",
                data={},
            )

        answer = str(request.payload.get("answer") or "")
        result = self.bridge.tutor_feedback(entry, answer)

        return LearningResponse(
            operation="evaluate_answer",
            status="ok",
            data=result,
            sources=(result["source"],),
        )

    def _record_progress(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry = self._entry(request)

        if entry is None:
            return LearningResponse(
                operation="record_progress",
                status="not_found",
                data={},
            )

        step = str(request.payload.get("step") or "").strip()

        if not step:
            return LearningResponse(
                operation="record_progress",
                status="invalid_request",
                data={},
                warnings=("El paso completado es obligatorio.",),
            )

        score = request.payload.get("score")
        data = self.progress.record(
            request.learner_id,
            entry["entry_id"],
            step,
            score,
        )

        return LearningResponse(
            operation="record_progress",
            status="ok",
            data=data,
            sources=(f"RLB:{entry['entry_id']}",),
        )

    def _get_progress(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry_id = (
            request.entry_id
            or str(request.payload.get("entry_id") or "")
        )

        return LearningResponse(
            operation="get_progress",
            status="ok",
            data=self.progress.get(
                request.learner_id,
                entry_id,
            ),
        )

    def _capabilities(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        return LearningResponse(
            operation="capabilities",
            status="ok",
            data=self.bridge.capabilities(),
        )