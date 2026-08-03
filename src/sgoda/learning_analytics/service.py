"""Servicio principal de SPT-016."""

from __future__ import annotations

from typing import Any

from .exporter import export_dashboard
from .metrics import progress
from .models import (
    AnalyticsCommand,
    AnalyticsResult,
    LearningEvent,
)
from .recommendations import recommend
from .repository import LearningEventRepository
from .trends import alerts, score_trend


_ALLOWED_EVENT_TYPES = {
    "resource_viewed",
    "assessment_completed",
    "word_practiced",
    "lesson_completed",
    "conversation_completed",
}


def _event_from_payload(payload: dict[str, Any]) -> LearningEvent:
    score = payload.get("score")
    duration = payload.get("duration_seconds")

    return LearningEvent(
        event_id=str(payload.get("event_id") or "").strip(),
        learner_id=str(payload.get("learner_id") or "").strip(),
        event_type=str(payload.get("event_type") or "").strip(),
        entry_id=str(payload.get("entry_id") or "").strip(),
        competency=str(payload.get("competency") or "").strip(),
        score=float(score) if score is not None else None,
        duration_seconds=(
            float(duration)
            if duration is not None
            else None
        ),
        resource_id=str(payload.get("resource_id") or "").strip(),
        timestamp=str(payload.get("timestamp") or "").strip(),
        metadata=dict(payload.get("metadata") or {}),
    )


def _event_to_dict(event: LearningEvent) -> dict[str, Any]:
    return {
        "event_id": event.event_id,
        "learner_id": event.learner_id,
        "event_type": event.event_type,
        "entry_id": event.entry_id,
        "competency": event.competency,
        "score": event.score,
        "duration_seconds": event.duration_seconds,
        "resource_id": event.resource_id,
        "timestamp": event.timestamp,
        "metadata": dict(event.metadata),
    }


def _validate(payload: dict[str, Any]) -> tuple[str, ...]:
    errors = []
    event_id = str(payload.get("event_id") or "").strip()
    learner_id = str(payload.get("learner_id") or "").strip()
    event_type = str(payload.get("event_type") or "").strip()

    if not event_id.startswith("EVT-"):
        errors.append("event_id debe iniciar con EVT-.")

    if not learner_id:
        errors.append("learner_id es obligatorio.")

    if event_type not in _ALLOWED_EVENT_TYPES:
        errors.append("event_type no está permitido.")

    score = payload.get("score")
    if score is not None:
        try:
            value = float(score)
            if value < 0 or value > 1:
                errors.append("score debe estar entre 0 y 1.")
        except (TypeError, ValueError):
            errors.append("score debe ser numérico.")

    return tuple(errors)


class LearningAnalyticsEngine:
    def __init__(
        self,
        repository: LearningEventRepository | None = None,
    ) -> None:
        self.repository = repository or LearningEventRepository()

    def execute(
        self,
        command: AnalyticsCommand,
    ) -> AnalyticsResult:
        handlers = {
            "record_event": self._record_event,
            "learner_dashboard": self._learner_dashboard,
            "entry_analytics": self._entry_analytics,
            "competency_analytics": self._competency_analytics,
            "recommendation": self._recommendation,
            "export_dashboard": self._export_dashboard,
            "stats": self._stats,
        }

        handler = handlers.get(command.operation)

        if handler is None:
            return AnalyticsResult(
                operation=command.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(command.payload)

    def _record_event(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        errors = _validate(payload)

        if errors:
            return AnalyticsResult(
                operation="record_event",
                status="invalid_event",
                data={"errors": list(errors)},
                warnings=errors,
            )

        event = _event_from_payload(payload)

        try:
            self.repository.add(event)
        except ValueError as error:
            return AnalyticsResult(
                operation="record_event",
                status="duplicate_id",
                data={"event_id": event.event_id},
                warnings=(str(error),),
            )

        return AnalyticsResult(
            operation="record_event",
            status="ok",
            data=_event_to_dict(event),
        )

    def _dashboard_data(
        self,
        learner_id: str,
    ) -> dict[str, Any]:
        events = self.repository.for_learner(learner_id)

        return {
            "learner_id": learner_id,
            "progress": progress(events),
            "trend": score_trend(events),
            "alerts": list(alerts(events)),
            "recommendation": recommend(events),
            "events": [
                _event_to_dict(event)
                for event in events
            ],
        }

    def _learner_dashboard(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()

        return AnalyticsResult(
            operation="learner_dashboard",
            status="ok",
            data=self._dashboard_data(learner_id),
        )

    def _entry_analytics(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        entry_id = str(payload.get("entry_id") or "").strip()
        events = self.repository.for_entry(
            learner_id,
            entry_id,
        )

        return AnalyticsResult(
            operation="entry_analytics",
            status="ok",
            data={
                "learner_id": learner_id,
                "entry_id": entry_id,
                "progress": progress(events),
                "trend": score_trend(events),
                "alerts": list(alerts(events)),
            },
        )

    def _competency_analytics(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        competency = str(
            payload.get("competency") or ""
        ).strip()
        events = self.repository.for_competency(
            learner_id,
            competency,
        )

        return AnalyticsResult(
            operation="competency_analytics",
            status="ok",
            data={
                "learner_id": learner_id,
                "competency": competency,
                "progress": progress(events),
                "trend": score_trend(events),
                "alerts": list(alerts(events)),
            },
        )

    def _recommendation(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        events = self.repository.for_learner(learner_id)

        return AnalyticsResult(
            operation="recommendation",
            status="ok",
            data={
                "learner_id": learner_id,
                **recommend(events),
            },
        )

    def _export_dashboard(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        path = str(payload.get("path") or "").strip()
        dashboard = self._dashboard_data(learner_id)
        export_dashboard(
            path,
            {
                "schema": "SPT-016",
                "version": "1.0.0",
                "dashboard": dashboard,
            },
        )

        return AnalyticsResult(
            operation="export_dashboard",
            status="ok",
            data={
                "learner_id": learner_id,
                "path": path,
            },
        )

    def _stats(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        events = self.repository.all()

        return AnalyticsResult(
            operation="stats",
            status="ok",
            data={
                "events": len(events),
                "learners": len(
                    {event.learner_id for event in events}
                ),
                "entries": len(
                    {
                        event.entry_id
                        for event in events
                        if event.entry_id
                    }
                ),
                "competencies": len(
                    {
                        event.competency
                        for event in events
                        if event.competency
                    }
                ),
            },
        )