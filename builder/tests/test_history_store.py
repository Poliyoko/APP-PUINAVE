from pathlib import Path

import pytest

from sgoda.operations import (
    HistoryEvent,
    HistoryStore,
    HistoryStoreError,
)


def event(index: int, kind: str = "status_collected") -> HistoryEvent:
    return HistoryEvent.create(
        event_type=kind,
        occurred_at=f"2026-07-15T00:00:0{index}+00:00",
        actor="SGODA Project Builder",
        builder_version="1.6.0",
        project_name="Proyecto",
        schema_version="1.3",
        health="HEALTHY",
    )


def test_store_persists_and_orders_events(tmp_path: Path) -> None:
    store = HistoryStore(tmp_path)
    store.append(event(2))
    store.append(event(1))
    events = store.read_all()
    assert [item.occurred_at for item in events] == sorted(
        item.occurred_at for item in events
    )


def test_store_filters_and_limits(tmp_path: Path) -> None:
    store = HistoryStore(tmp_path)
    store.append(event(1, "audit_executed"))
    store.append(event(2, "status_collected"))
    store.append(event(3, "status_collected"))

    filtered = store.query(
        event_type="status_collected",
        limit=1,
    )
    assert len(filtered) == 1
    assert filtered[0].occurred_at.endswith("03+00:00")


def test_missing_history_is_empty(tmp_path: Path) -> None:
    assert HistoryStore(tmp_path).read_all() == []


def test_corrupt_history_is_rejected(tmp_path: Path) -> None:
    store = HistoryStore(tmp_path)
    store.history_dir.mkdir(parents=True)
    store.events_path.write_text("{not-json}\n", encoding="utf-8")
    with pytest.raises(HistoryStoreError):
        store.read_all()
