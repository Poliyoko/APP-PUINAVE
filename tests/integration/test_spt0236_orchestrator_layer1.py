import json

import pytest

from sgoda.integration.spt0236.contracts import PIPELINE, validate_pipeline_contract
from sgoda.integration.spt0236.planner import build_orchestration_plan
from sgoda.integration.spt0236.service import Spt0236Layer1Service
from sgoda.integration.spt0236.state import OrchestrationStateStore


def handler_for(status):
    def _handler(payload):
        return {
            "status": status,
            "payload": payload,
        }
    return _handler


def handlers():
    return {
        step.component: handler_for(step.success_status)
        for step in PIPELINE
    }


def test_pipeline_contract_has_ten_steps():
    validate_pipeline_contract()
    assert len(PIPELINE) == 10


def test_pipeline_starts_with_spt0231():
    assert PIPELINE[0].component == "SPT-023.1"


def test_pipeline_includes_spt0235():
    assert any(step.component == "SPT-023.5" for step in PIPELINE)


def test_pipeline_includes_pmo_auditor_sgd002_n8n_fastapi():
    components = {step.component for step in PIPELINE}
    assert {
        "PMO_DIGITAL",
        "AUDITOR_INSTITUCIONAL",
        "SGD-002",
        "N8N",
        "FASTAPI",
    }.issubset(components)


def test_plan_requires_lexical_id():
    with pytest.raises(ValueError):
        build_orchestration_plan(lexical_id="")


def test_orchestration_id_is_deterministic():
    one = build_orchestration_plan(lexical_id="LEX-001")
    two = build_orchestration_plan(lexical_id="LEX-001")
    assert one.orchestration_id == two.orchestration_id


def test_plan_points_to_layer2():
    plan = build_orchestration_plan(lexical_id="LEX-001")
    assert plan.next_component == "SPT-023.6-CAPA-2"


def test_state_store_roundtrip(tmp_path):
    store = OrchestrationStateStore(tmp_path / "state.json")
    run = {"orchestration_id": "ORCH-1", "status": "NEW"}
    store.save_run(run)
    assert store.get("ORCH-1")["status"] == "NEW"


def test_state_file_is_valid_json(tmp_path):
    path = tmp_path / "state.json"
    store = OrchestrationStateStore(path)
    store.save_run({"orchestration_id": "ORCH-1", "status": "NEW"})
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["component"] == "SPT-023.6"


def test_service_creates_run(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    assert run["lexical_id"] == "LEX-001"
    assert run["completed_steps"] == []


def test_service_executes_full_pipeline(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    result = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=handlers(),
    )
    assert result["orchestration_complete"] is True
    assert len(result["completed_steps"]) == 10


def test_service_rejects_missing_critical_handler(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    mapping = handlers()
    mapping.pop("SPT-023.2")
    with pytest.raises(ValueError):
        service.execute_with_handlers(
            orchestration_id=run["orchestration_id"],
            handlers=mapping,
        )


def test_optional_n8n_can_be_skipped(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    mapping = handlers()
    mapping.pop("N8N")
    result = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=mapping,
    )
    assert result["orchestration_complete"] is True


def test_optional_fastapi_can_be_skipped(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    mapping = handlers()
    mapping.pop("FASTAPI")
    result = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=mapping,
    )
    assert result["orchestration_complete"] is True


def test_failure_is_recorded(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    mapping = handlers()

    def broken(_payload):
        raise RuntimeError("boom")

    mapping["SPT-023.3"] = broken

    with pytest.raises(RuntimeError):
        service.execute_with_handlers(
            orchestration_id=run["orchestration_id"],
            handlers=mapping,
        )

    stored = service.state_store.get(run["orchestration_id"])
    assert "STEP-03" in stored["failed_steps"]


def test_completed_steps_are_idempotent(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    first = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=handlers(),
    )
    second = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=handlers(),
    )
    assert first["completed_steps"] == second["completed_steps"]


def test_paid_api_is_disabled(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    assert run["runtime"]["paid_api_used"] is False


def test_n8n_runtime_is_not_mandatory(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    assert run["runtime"]["n8n_required"] is False


def test_fastapi_runtime_is_not_mandatory(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    assert run["runtime"]["fastapi_required"] is False


def test_final_status_is_orchestration_exposed(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    run = service.create_run(lexical_id="LEX-001")
    result = service.execute_with_handlers(
        orchestration_id=run["orchestration_id"],
        handlers=handlers(),
    )
    assert result["status"] == "ORCHESTRATION_EXPOSED"
