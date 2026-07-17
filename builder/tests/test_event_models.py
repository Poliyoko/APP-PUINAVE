from sgoda.operations import HistoryEvent


def test_event_roundtrip() -> None:
    event = HistoryEvent.create(
        event_type="status_collected",
        occurred_at="2026-07-15T00:00:00+00:00",
        actor="SGODA Project Builder",
        builder_version="1.11.0",
        project_name="Proyecto",
        schema_version="1.3",
        health="HEALTHY",
        details={"source": "test"},
    )
    restored = HistoryEvent.from_dict(event.to_dict())
    assert restored == event
    assert restored.event_id
