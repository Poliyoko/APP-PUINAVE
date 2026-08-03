"""Repositorios de preguntas e intentos."""

from __future__ import annotations

from .models import AssessmentItem, LearnerAttempt


class AssessmentRepository:
    def __init__(self) -> None:
        self._items: dict[str, AssessmentItem] = {}
        self._attempts: list[LearnerAttempt] = []

    def add_item(self, item: AssessmentItem) -> AssessmentItem:
        if item.item_id in self._items:
            raise ValueError(f"El ítem ya existe: {item.item_id}")

        self._items[item.item_id] = item
        return item

    def upsert_item(self, item: AssessmentItem) -> AssessmentItem:
        self._items[item.item_id] = item
        return item

    def get_item(self, item_id: str) -> AssessmentItem | None:
        return self._items.get(str(item_id or "").strip())

    def items(self) -> tuple[AssessmentItem, ...]:
        return tuple(self._items[key] for key in sorted(self._items))

    def items_for_competency(
        self,
        competency: str,
        validated_only: bool = True,
    ) -> tuple[AssessmentItem, ...]:
        items = [
            item
            for item in self.items()
            if item.competency == competency
        ]

        if validated_only:
            items = [item for item in items if item.validated]

        return tuple(items)

    def add_attempt(self, attempt: LearnerAttempt) -> None:
        self._attempts.append(attempt)

    def attempts_for(
        self,
        learner_id: str,
        competency: str | None = None,
    ) -> tuple[LearnerAttempt, ...]:
        attempts = [
            item
            for item in self._attempts
            if item.learner_id == learner_id
        ]

        if competency is not None:
            attempts = [
                item
                for item in attempts
                if item.competency == competency
            ]

        return tuple(attempts)