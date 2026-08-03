from __future__ import annotations

from pathlib import Path

from sgoda.adaptive_assessment import (
    AdaptiveAssessmentEngine,
    AssessmentCommand,
    AssessmentRepository,
    AssessmentItem,
    LearnerAttempt,
    mastery,
    recommended_difficulty,
    score_answer,
    select_next_item,
)


def _item(
    item_id: str = "QST-001",
    difficulty: int = 1,
    assessment_type: str = "formative",
    validated: bool = True,
) -> dict:
    return {
        "item_id": item_id,
        "entry_id": "LEX-001",
        "competency": "vocabulary",
        "assessment_type": assessment_type,
        "difficulty": difficulty,
        "prompt": "¿Qué significa AMDA?",
        "correct_answer": "casa",
        "options": ["casa", "río", "fuego"],
        "media_resource_ids": ["MED-001"],
        "validated": validated,
    }


def test_SPT_015_registers_item() -> None:
    engine = AdaptiveAssessmentEngine()
    result = engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    assert result.status == "ok"


def test_SPT_015_rejects_invalid_id() -> None:
    payload = _item()
    payload["item_id"] = "BAD"
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(
            operation="register_item",
            payload=payload,
        )
    )

    assert result.status == "invalid_item"


def test_SPT_015_rejects_invalid_entry_id() -> None:
    payload = _item()
    payload["entry_id"] = "BAD"
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(
            operation="register_item",
            payload=payload,
        )
    )

    assert result.status == "invalid_item"


def test_SPT_015_rejects_invalid_type() -> None:
    payload = _item()
    payload["assessment_type"] = "other"
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(
            operation="register_item",
            payload=payload,
        )
    )

    assert result.status == "invalid_item"


def test_SPT_015_rejects_invalid_difficulty() -> None:
    payload = _item()
    payload["difficulty"] = 9
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(
            operation="register_item",
            payload=payload,
        )
    )

    assert result.status == "invalid_item"


def test_SPT_015_detects_duplicate_id() -> None:
    engine = AdaptiveAssessmentEngine()
    command = AssessmentCommand(
        operation="register_item",
        payload=_item(),
    )
    engine.execute(command)

    assert engine.execute(command).status == "duplicate_id"


def test_SPT_015_scores_correct_answer() -> None:
    assert score_answer("Casa", "casa") == (True, 1.0)


def test_SPT_015_scores_incorrect_answer() -> None:
    assert score_answer("río", "casa") == (False, 0.0)


def test_SPT_015_mastery_is_zero_without_attempts() -> None:
    assert mastery(()) == 0.0


def test_SPT_015_mastery_is_weighted() -> None:
    attempts = (
        LearnerAttempt(
            "L-001",
            "Q1",
            "casa",
            True,
            1.0,
            1,
            "vocabulary",
        ),
        LearnerAttempt(
            "L-001",
            "Q2",
            "río",
            False,
            0.0,
            3,
            "vocabulary",
        ),
    )

    assert mastery(attempts) == 0.25


def test_SPT_015_recommends_low_difficulty() -> None:
    assert recommended_difficulty(()) == 1


def test_SPT_015_recommends_high_difficulty() -> None:
    attempts = (
        LearnerAttempt(
            "L-001",
            "Q1",
            "casa",
            True,
            1.0,
            3,
            "vocabulary",
        ),
    )

    assert recommended_difficulty(attempts) == 3


def test_SPT_015_selects_validated_item() -> None:
    items = (
        AssessmentItem(
            "QST-001",
            "LEX-001",
            "vocabulary",
            "formative",
            1,
            "Prompt",
            "casa",
            validated=False,
        ),
        AssessmentItem(
            "QST-002",
            "LEX-001",
            "vocabulary",
            "formative",
            1,
            "Prompt",
            "casa",
            validated=True,
        ),
    )

    assert select_next_item(items, ()).item_id == "QST-002"


def test_SPT_015_next_item_works() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    result = engine.execute(
        AssessmentCommand(
            operation="next_item",
            payload={
                "learner_id": "L-001",
                "competency": "vocabulary",
            },
        )
    )

    assert result.status == "ok"


def test_SPT_015_submits_correct_answer() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    result = engine.execute(
        AssessmentCommand(
            operation="submit_answer",
            payload={
                "learner_id": "L-001",
                "item_id": "QST-001",
                "answer": "casa",
            },
        )
    )

    assert result.data["correct"] is True
    assert result.data["mastery"] == 1.0


def test_SPT_015_submits_incorrect_answer() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    result = engine.execute(
        AssessmentCommand(
            operation="submit_answer",
            payload={
                "learner_id": "L-001",
                "item_id": "QST-001",
                "answer": "río",
            },
        )
    )

    assert result.data["correct"] is False


def test_SPT_015_reports_history() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )
    engine.execute(
        AssessmentCommand(
            operation="submit_answer",
            payload={
                "learner_id": "L-001",
                "item_id": "QST-001",
                "answer": "casa",
            },
        )
    )

    result = engine.execute(
        AssessmentCommand(
            operation="history",
            payload={"learner_id": "L-001"},
        )
    )

    assert result.data["total"] == 1


def test_SPT_015_reports_stats() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    result = engine.execute(
        AssessmentCommand(operation="stats")
    )

    assert result.data["items"] == 1
    assert result.data["formative"] == 1


def test_SPT_015_exports_result(tmp_path: Path) -> None:
    target = tmp_path / "result.json"
    engine = AdaptiveAssessmentEngine()

    result = engine.execute(
        AssessmentCommand(
            operation="export_result",
            payload={
                "path": str(target),
                "learner_id": "L-001",
            },
        )
    )

    assert result.status == "ok"
    assert target.exists()


def test_SPT_015_preserves_no_invention() -> None:
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(operation="stats")
    )

    assert result.no_invention is True


def test_SPT_015_rejects_unknown_operation() -> None:
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(operation="unknown")
    )

    assert result.status == "unsupported_operation"