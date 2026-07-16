import json

from sgoda.operations import (
    HistoryEvent,
    history_to_json,
    history_to_text,
)


def sample() -> HistoryEvent:
    return HistoryEvent.create(
        event_type="project_migrated",
        occurred_at="2026-07-15T00:00:00+00:00",
        actor="SGODA Project Builder",
        builder_version="1.7.0",
        project_name="Proyecto",
        schema_version="1.3",
        health="HEALTHY",
    )


def test_text_serializer() -> None:
    output = history_to_text(".", [sample()])
    assert "Historial SGODA" in output
    assert "project_migrated" in output
    assert "Eventos: 1" in output


def test_json_serializer() -> None:
    payload = json.loads(history_to_json([sample()]))
    assert payload["count"] == 1
    assert payload["events"][0]["event_type"] == "project_migrated"
