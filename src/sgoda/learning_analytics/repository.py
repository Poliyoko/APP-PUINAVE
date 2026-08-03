"""Repositorio de eventos de aprendizaje."""

from __future__ import annotations

from .models import LearningEvent


class LearningEventRepository:
    def __init__(self) -> None:
        self._events: dict[str, LearningEvent] = {}

    def add(self, event: LearningEvent) -> LearningEvent:
        if event.event_id in self._events:
            raise ValueError(
                f"El evento ya existe: {event.event_id}"
            )

        self._events[event.event_id] = event
        return event

    def all(self) -> tuple[LearningEvent, ...]:
        return tuple(
            self._events[key]
            for key in sorted(self._events)
        )

    def for_learner(
        self,
        learner_id: str,
    ) -> tuple[LearningEvent, ...]:
        return tuple(
            event
            for event in self.all()
            if event.learner_id == learner_id
        )

    def for_entry(
        self,
        learner_id: str,
        entry_id: str,
    ) -> tuple[LearningEvent, ...]:
        return tuple(
            event
            for event in self.for_learner(learner_id)
            if event.entry_id == entry_id
        )

    def for_competency(
        self,
        learner_id: str,
        competency: str,
    ) -> tuple[LearningEvent, ...]:
        return tuple(
            event
            for event in self.for_learner(learner_id)
            if event.competency == competency
        )