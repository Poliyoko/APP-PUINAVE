"""Servicio principal del Motor de Evaluación Adaptativa."""

from __future__ import annotations

from typing import Any

from .adaptation import (
    recommended_difficulty,
    select_next_item,
)
from .exporter import export_result
from .feedback import build_feedback
from .models import (
    AssessmentCommand,
    AssessmentItem,
    AssessmentResult,
    LearnerAttempt,
)
from .repository import AssessmentRepository
from .scoring import mastery, score_answer


_ALLOWED_TYPES = {
    "diagnostic",
    "formative",
    "summative",
}


def _item_from_payload(
    payload: dict[str, Any],
) -> AssessmentItem:
    return AssessmentItem(
        item_id=str(payload.get("item_id") or "").strip(),
        entry_id=str(payload.get("entry_id") or "").strip(),
        competency=str(payload.get("competency") or "").strip(),
        assessment_type=str(
            payload.get("assessment_type") or ""
        ).strip(),
        difficulty=int(payload.get("difficulty", 1)),
        prompt=str(payload.get("prompt") or "").strip(),
        correct_answer=str(
            payload.get("correct_answer") or ""
        ).strip(),
        options=tuple(
            str(item)
            for item in payload.get("options", []) or []
        ),
        media_resource_ids=tuple(
            str(item)
            for item in payload.get(
                "media_resource_ids",
                [],
            ) or []
        ),
        validated=bool(payload.get("validated", False)),
        metadata=dict(payload.get("metadata") or {}),
    )


def _item_to_dict(item: AssessmentItem) -> dict[str, Any]:
    return {
        "item_id": item.item_id,
        "entry_id": item.entry_id,
        "competency": item.competency,
        "assessment_type": item.assessment_type,
        "difficulty": item.difficulty,
        "prompt": item.prompt,
        "correct_answer": item.correct_answer,
        "options": list(item.options),
        "media_resource_ids": list(item.media_resource_ids),
        "validated": item.validated,
        "metadata": dict(item.metadata),
    }


def _validate_item(payload: dict[str, Any]) -> tuple[str, ...]:
    errors = []
    item_id = str(payload.get("item_id") or "").strip()
    entry_id = str(payload.get("entry_id") or "").strip()
    competency = str(payload.get("competency") or "").strip()
    assessment_type = str(
        payload.get("assessment_type") or ""
    ).strip()
    prompt = str(payload.get("prompt") or "").strip()
    correct_answer = str(
        payload.get("correct_answer") or ""
    ).strip()

    try:
        difficulty = int(payload.get("difficulty", 0))
    except (TypeError, ValueError):
        difficulty = 0

    if not item_id.startswith("QST-"):
        errors.append("item_id debe iniciar con QST-.")

    if not entry_id.startswith("LEX-"):
        errors.append("entry_id debe iniciar con LEX-.")

    if not competency:
        errors.append("La competencia es obligatoria.")

    if assessment_type not in _ALLOWED_TYPES:
        errors.append("assessment_type no está permitido.")

    if difficulty not in {1, 2, 3}:
        errors.append("difficulty debe ser 1, 2 o 3.")

    if not prompt:
        errors.append("El enunciado es obligatorio.")

    if not correct_answer:
        errors.append("La respuesta correcta es obligatoria.")

    return tuple(errors)


class AdaptiveAssessmentEngine:
    def __init__(
        self,
        repository: AssessmentRepository | None = None,
    ) -> None:
        self.repository = repository or AssessmentRepository()

    def execute(
        self,
        command: AssessmentCommand,
    ) -> AssessmentResult:
        handlers = {
            "register_item": self._register_item,
            "upsert_item": self._upsert_item,
            "next_item": self._next_item,
            "submit_answer": self._submit_answer,
            "mastery": self._mastery,
            "history": self._history,
            "stats": self._stats,
            "export_result": self._export_result,
        }

        handler = handlers.get(command.operation)

        if handler is None:
            return AssessmentResult(
                operation=command.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(command.payload)

    def _register_item(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        errors = _validate_item(payload)

        if errors:
            return AssessmentResult(
                operation="register_item",
                status="invalid_item",
                data={"errors": list(errors)},
                warnings=errors,
            )

        item = _item_from_payload(payload)

        try:
            self.repository.add_item(item)
        except ValueError as error:
            return AssessmentResult(
                operation="register_item",
                status="duplicate_id",
                data={"item_id": item.item_id},
                warnings=(str(error),),
            )

        return AssessmentResult(
            operation="register_item",
            status="ok",
            data=_item_to_dict(item),
        )

    def _upsert_item(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        errors = _validate_item(payload)

        if errors:
            return AssessmentResult(
                operation="upsert_item",
                status="invalid_item",
                data={"errors": list(errors)},
                warnings=errors,
            )

        item = self.repository.upsert_item(
            _item_from_payload(payload)
        )

        return AssessmentResult(
            operation="upsert_item",
            status="ok",
            data=_item_to_dict(item),
        )

    def _next_item(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        competency = str(
            payload.get("competency") or ""
        ).strip()
        attempts = self.repository.attempts_for(
            learner_id,
            competency,
        )
        items = self.repository.items_for_competency(
            competency,
            validated_only=True,
        )
        selected = select_next_item(items, attempts)

        if selected is None:
            return AssessmentResult(
                operation="next_item",
                status="not_found",
                data={
                    "learner_id": learner_id,
                    "competency": competency,
                },
            )

        return AssessmentResult(
            operation="next_item",
            status="ok",
            data={
                "item": _item_to_dict(selected),
                "recommended_difficulty": (
                    recommended_difficulty(attempts)
                ),
            },
        )

    def _submit_answer(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        item_id = str(payload.get("item_id") or "").strip()
        answer = str(payload.get("answer") or "")
        item = self.repository.get_item(item_id)

        if item is None:
            return AssessmentResult(
                operation="submit_answer",
                status="not_found",
                data={"item_id": item_id},
            )

        correct, score = score_answer(
            answer,
            item.correct_answer,
        )
        attempt = LearnerAttempt(
            learner_id=learner_id,
            item_id=item.item_id,
            answer=answer,
            correct=correct,
            score=score,
            difficulty=item.difficulty,
            competency=item.competency,
        )
        self.repository.add_attempt(attempt)
        attempts = self.repository.attempts_for(
            learner_id,
            item.competency,
        )
        mastery_score = mastery(attempts)

        return AssessmentResult(
            operation="submit_answer",
            status="ok",
            data={
                "learner_id": learner_id,
                "item_id": item_id,
                "correct": correct,
                "score": score,
                "mastery": mastery_score,
                "feedback": build_feedback(
                    correct,
                    mastery_score,
                    item.competency,
                ),
                "next_difficulty": (
                    recommended_difficulty(attempts)
                ),
            },
        )

    def _mastery(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        competency = str(
            payload.get("competency") or ""
        ).strip()
        attempts = self.repository.attempts_for(
            learner_id,
            competency,
        )

        return AssessmentResult(
            operation="mastery",
            status="ok",
            data={
                "learner_id": learner_id,
                "competency": competency,
                "attempts": len(attempts),
                "mastery": mastery(attempts),
                "recommended_difficulty": (
                    recommended_difficulty(attempts)
                ),
            },
        )

    def _history(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        attempts = self.repository.attempts_for(learner_id)

        return AssessmentResult(
            operation="history",
            status="ok",
            data={
                "learner_id": learner_id,
                "total": len(attempts),
                "attempts": [
                    {
                        "item_id": item.item_id,
                        "answer": item.answer,
                        "correct": item.correct,
                        "score": item.score,
                        "difficulty": item.difficulty,
                        "competency": item.competency,
                    }
                    for item in attempts
                ],
            },
        )

    def _stats(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        items = self.repository.items()

        return AssessmentResult(
            operation="stats",
            status="ok",
            data={
                "items": len(items),
                "validated_items": sum(
                    1 for item in items if item.validated
                ),
                "diagnostic": sum(
                    1
                    for item in items
                    if item.assessment_type == "diagnostic"
                ),
                "formative": sum(
                    1
                    for item in items
                    if item.assessment_type == "formative"
                ),
                "summative": sum(
                    1
                    for item in items
                    if item.assessment_type == "summative"
                ),
            },
        )

    def _export_result(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        path = str(payload.get("path") or "").strip()
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        history = self._history(
            {"learner_id": learner_id}
        ).data
        export_result(
            path,
            {
                "schema": "SPT-015",
                "version": "1.0.0",
                "learner": history,
            },
        )

        return AssessmentResult(
            operation="export_result",
            status="ok",
            data={
                "path": path,
                "learner_id": learner_id,
            },
        )