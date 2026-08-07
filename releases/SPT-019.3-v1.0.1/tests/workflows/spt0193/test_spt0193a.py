import pytest

from sgoda.workflows.spt0193.components import (
    ComponentLoadError,
    InstitutionalComponentLoader,
)
from sgoda.workflows.spt0193.orchestrator import (
    InstitutionalWorkflowOrchestrator,
    OrchestrationError,
)


class Registry:
    def validate(self, workflow_id):
        return workflow_id != "blocked"

    def get(self, workflow_id):
        return {"id": workflow_id}


class Engine:
    def execute(self, workflow, payload):
        return {"workflow": workflow["id"], "payload": payload}


def test_loader_registers_and_gets_component():
    loader = InstitutionalComponentLoader()
    engine = Engine()
    loader.register("engine", engine, ("execute",))
    assert loader.get("engine") is engine


def test_loader_rejects_missing_contract():
    loader = InstitutionalComponentLoader()
    with pytest.raises(ComponentLoadError):
        loader.register("invalid", object(), ("execute",))


def test_orchestrator_executes_registered_workflow():
    orchestrator = InstitutionalWorkflowOrchestrator(Engine(), Registry())
    result = orchestrator.execute("WF-001", {"value": 7})
    assert result.status == "COMPLETED"
    assert result.output["workflow"] == "WF-001"
    assert result.output["payload"]["value"] == 7


def test_orchestrator_rejects_registry_block():
    orchestrator = InstitutionalWorkflowOrchestrator(Engine(), Registry())
    with pytest.raises(OrchestrationError):
        orchestrator.execute("blocked")