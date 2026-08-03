from __future__ import annotations

from pathlib import Path

from sgoda.learning_analytics import (
    AnalyticsCommand,
    LearningAnalyticsEngine,
    LearningEvent,
    alerts,
    mastery,
    progress,
    recommend,
    score_trend,
)


def _event(
    event_id: str = "EVT-001",
    event_type: str = "assessment_completed",
    score: float | None = 1.0,
    duration: float | None = 30.0,
) -> dict:
    return {
        "event_id": event_id,
        "learner_id": "LEARNER-001",
        "event_type": event_type,
        "entry_id": "LEX-001",
        "competency": "vocabulary",
        "score": score,
        "duration_seconds": duration,
        "resource_id": "MED-001",
        "timestamp": "2026-08-02T22:00:00-05:00",
    }


def test_registers_event() -> None:
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    assert result.status == "ok"


def test_rejects_invalid_event_id() -> None:
    payload = _event()
    payload["event_id"] = "BAD"
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=payload,
        )
    )
    assert result.status == "invalid_event"


def test_rejects_missing_learner() -> None:
    payload = _event()
    payload["learner_id"] = ""
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=payload,
        )
    )
    assert result.status == "invalid_event"


def test_rejects_invalid_type() -> None:
    payload = _event()
    payload["event_type"] = "other"
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=payload,
        )
    )
    assert result.status == "invalid_event"


def test_rejects_invalid_score() -> None:
    payload = _event()
    payload["score"] = 2
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=payload,
        )
    )
    assert result.status == "invalid_event"


def test_detects_duplicate() -> None:
    engine = LearningAnalyticsEngine()
    command = AnalyticsCommand(
        operation="record_event",
        payload=_event(),
    )
    engine.execute(command)
    assert engine.execute(command).status == "duplicate_id"


def test_mastery_without_events() -> None:
    assert mastery(()) == 0.0


def test_mastery_average() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=1.0),
        LearningEvent("2", "L", "assessment_completed", score=0.5),
    )
    assert mastery(events) == 0.75


def test_progress_counts_events() -> None:
    events = (
        LearningEvent(
            "1",
            "L",
            "resource_viewed",
            duration_seconds=10,
        ),
    )
    assert progress(events)["events"] == 1
    assert progress(events)["duration_seconds"] == 10


def test_trend_improving() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=0.2),
        LearningEvent("2", "L", "assessment_completed", score=0.8),
    )
    assert score_trend(events) == "improving"


def test_trend_declining() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=0.8),
        LearningEvent("2", "L", "assessment_completed", score=0.2),
    )
    assert score_trend(events) == "declining"


def test_alerts_low_mastery() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=0.2),
        LearningEvent("2", "L", "assessment_completed", score=0.4),
    )
    assert any(
        item["code"] == "LOW_MASTERY"
        for item in alerts(events)
    )


def test_recommend_reinforcement() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=0.2),
    )
    assert recommend(events)["action"] == "reinforce"


def test_recommend_advance() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=1.0),
    )
    assert recommend(events)["action"] == "advance"


def test_dashboard() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(
            operation="learner_dashboard",
            payload={"learner_id": "LEARNER-001"},
        )
    )
    assert result.status == "ok"
    assert result.data["progress"]["mastery"] == 1.0


def test_entry_analytics() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(
            operation="entry_analytics",
            payload={
                "learner_id": "LEARNER-001",
                "entry_id": "LEX-001",
            },
        )
    )
    assert result.data["entry_id"] == "LEX-001"


def test_competency_analytics() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(
            operation="competency_analytics",
            payload={
                "learner_id": "LEARNER-001",
                "competency": "vocabulary",
            },
        )
    )
    assert result.data["competency"] == "vocabulary"


def test_recommendation_operation() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(
            operation="recommendation",
            payload={"learner_id": "LEARNER-001"},
        )
    )
    assert result.data["action"] == "advance"


def test_export_dashboard(tmp_path: Path) -> None:
    target = tmp_path / "dashboard.json"
    engine = LearningAnalyticsEngine()
    result = engine.execute(
        AnalyticsCommand(
            operation="export_dashboard",
            payload={
                "learner_id": "LEARNER-001",
                "path": str(target),
            },
        )
    )
    assert result.status == "ok"
    assert target.exists()


def test_stats() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(operation="stats")
    )
    assert result.data["events"] == 1


def test_no_invention() -> None:
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(operation="stats")
    )
    assert result.no_invention is True


def test_unknown_operation() -> None:
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(operation="unknown")
    )
    assert result.status == "unsupported_operation"