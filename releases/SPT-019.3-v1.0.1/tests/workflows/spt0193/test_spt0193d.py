import pytest

from sgoda.workflows.spt0193.events import InstitutionalEventBus
from sgoda.workflows.spt0193.orchestrator import InstitutionalWorkflowOrchestrator
from sgoda.workflows.spt0193.quality import InstitutionalQualityGate


class Registry:
    def validate(self, workflow_id):
        return True

    def get(self, workflow_id):
        return {"id": workflow_id}


class Engine:
    def execute(self, workflow, payload):
        return {"id": workflow["id"], "ok": True}


def test_quality_gate_approves_all_checks():
    report = InstitutionalQualityGate().require(
        {
            "SPT-019.3A": True,
            "SPT-019.3B": True,
            "SPT-019.3C": True,
        }
    )
    assert report.passed is True


def test_quality_gate_blocks_failed_check():
    with pytest.raises(RuntimeError):
        InstitutionalQualityGate().require(
            {"SPT-019.3A": True, "SPT-019.3B": False}
        )


def test_end_to_end_orchestration_publishes_events():
    bus = InstitutionalEventBus()
    orchestrator = InstitutionalWorkflowOrchestrator(
        Engine(),
        Registry(),
        event_bus=bus,
    )
    result = orchestrator.execute("WF-END-TO-END")
    assert result.status == "COMPLETED"
    assert [event.name for event in bus.history] == [
        "workflow.requested",
        "workflow.completed",
    ]