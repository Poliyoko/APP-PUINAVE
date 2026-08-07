import json

from sgoda.workflows.spt0193.events import InstitutionalEventBus
from sgoda.workflows.spt0193.evidence import InstitutionalEvidenceWriter
from sgoda.workflows.spt0193.traceability import TraceabilityLedger


def test_event_bus_delivers_and_preserves_history():
    bus = InstitutionalEventBus()
    received = []
    bus.subscribe("workflow.completed", received.append)
    event = bus.publish("workflow.completed", {"workflow_id": "WF-1"})
    assert event.name == "workflow.completed"
    assert received[0].payload["workflow_id"] == "WF-1"
    assert len(bus.history) == 1


def test_traceability_ledger_builds_hash_chain():
    ledger = TraceabilityLedger()
    first = ledger.append("workflow.requested", {"id": "WF-1"})
    second = ledger.append("workflow.completed", {"id": "WF-1"})
    assert first.previous_hash == "GENESIS"
    assert second.previous_hash == first.record_hash
    assert ledger.verify() is True


def test_evidence_writer_persists_atomic_json(tmp_path):
    path = tmp_path / "evidence.json"
    writer = InstitutionalEvidenceWriter(path)
    writer.record("workflow.completed", {"workflow_id": "WF-2"})
    payload = json.loads(path.read_text(encoding="utf-8"))
    assert payload["schema"] == "sgoda.spt0193.evidence.v1"
    assert payload["entries"][0]["payload"]["workflow_id"] == "WF-2"