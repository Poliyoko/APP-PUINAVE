import pytest

from sgoda.integration.spt0236.compensation import CompensationRegistry
from sgoda.integration.spt0236.events import OrchestrationEventLedger
from sgoda.integration.spt0236.governance import (
    HealthGateResult,
    RetryPolicy,
    evaluate_health_gates,
)
from sgoda.integration.spt0236.layer3 import Spt0236Layer3GovernanceService
from sgoda.integration.spt0236.runtime import GovernedExecutionRuntime


def healthy(component):
    return lambda: HealthGateResult(
        component=component,
        healthy=True,
        detail="ok",
    )


def all_probes():
    return {
        component: healthy(component)
        for component in Spt0236Layer3GovernanceService.REQUIRED_HEALTH
    }


def test_retry_policy_requires_positive_attempts():
    with pytest.raises(ValueError):
        RetryPolicy(max_attempts=0).validate()


def test_default_retry_policy_is_valid():
    RetryPolicy().validate()


def test_health_gate_passes_when_all_required_are_healthy():
    results = [
        HealthGateResult(component="A", healthy=True, detail="ok"),
        HealthGateResult(component="B", healthy=True, detail="ok"),
    ]
    gate = evaluate_health_gates(results, required_components=("A", "B"))
    assert gate["passed"] is True


def test_health_gate_fails_when_component_missing():
    results = [HealthGateResult(component="A", healthy=True, detail="ok")]
    gate = evaluate_health_gates(results, required_components=("A", "B"))
    assert gate["passed"] is False
    assert gate["missing"] == ["B"]


def test_health_gate_fails_when_component_unhealthy():
    results = [
        HealthGateResult(component="A", healthy=False, detail="bad")
    ]
    gate = evaluate_health_gates(results, required_components=("A",))
    assert gate["passed"] is False
    assert gate["unhealthy"] == ["A"]


def test_event_ledger_appends_and_verifies(tmp_path):
    ledger = OrchestrationEventLedger(tmp_path / "events.json")
    ledger.append(
        orchestration_id="ORCH-1",
        event_type="X",
        payload={"a": 1},
    )
    assert OrchestrationEventLedger.verify(ledger.all()) is True


def test_event_ledger_hash_chain_changes(tmp_path):
    ledger = OrchestrationEventLedger(tmp_path / "events.json")
    one = ledger.append(
        orchestration_id="ORCH-1",
        event_type="X",
        payload={},
    )
    two = ledger.append(
        orchestration_id="ORCH-1",
        event_type="Y",
        payload={},
    )
    assert two["previous_hash"] == one["event_sha256"]


def test_event_ledger_detects_tampering(tmp_path):
    ledger = OrchestrationEventLedger(tmp_path / "events.json")
    event = ledger.append(
        orchestration_id="ORCH-1",
        event_type="X",
        payload={},
    )
    event["event_sha256"] = "BAD"
    with pytest.raises(ValueError):
        OrchestrationEventLedger.verify([event])


def test_compensation_registry_returns_no_handler_status():
    registry = CompensationRegistry()
    result = registry.compensate("X", {})
    assert result.status == "NO_COMPENSATION_REGISTERED"


def test_compensation_registry_executes_handler():
    registry = CompensationRegistry()
    registry.register("X", lambda payload: {"status": "COMPENSATED"})
    result = registry.compensate("X", {})
    assert result.status == "COMPENSATED"


def test_runtime_executes_successfully(tmp_path):
    runtime = GovernedExecutionRuntime(
        ledger=OrchestrationEventLedger(tmp_path / "events.json"),
        compensation=CompensationRegistry(),
    )
    result = runtime.execute(
        orchestration_id="ORCH-1",
        component="X",
        expected_status="OK",
        handler=lambda payload: {"status": "OK"},
        payload={},
    )
    assert result["status"] == "OK"


def test_runtime_retries_runtime_error(tmp_path):
    attempts = {"count": 0}

    def flaky(payload):
        attempts["count"] += 1
        if attempts["count"] < 2:
            raise RuntimeError("temporary")
        return {"status": "OK"}

    runtime = GovernedExecutionRuntime(
        ledger=OrchestrationEventLedger(tmp_path / "events.json"),
        compensation=CompensationRegistry(),
        retry_policy=RetryPolicy(max_attempts=3),
    )
    result = runtime.execute(
        orchestration_id="ORCH-1",
        component="X",
        expected_status="OK",
        handler=flaky,
        payload={},
    )
    assert result["status"] == "OK"
    assert attempts["count"] == 2


def test_runtime_does_not_retry_value_error(tmp_path):
    attempts = {"count": 0}

    def broken(payload):
        attempts["count"] += 1
        raise ValueError("permanent")

    runtime = GovernedExecutionRuntime(
        ledger=OrchestrationEventLedger(tmp_path / "events.json"),
        compensation=CompensationRegistry(),
        retry_policy=RetryPolicy(max_attempts=3),
    )
    with pytest.raises(ValueError):
        runtime.execute(
            orchestration_id="ORCH-1",
            component="X",
            expected_status="OK",
            handler=broken,
            payload={},
        )
    assert attempts["count"] == 1


def test_runtime_compensates_after_terminal_failure(tmp_path):
    compensated = {"value": False}
    registry = CompensationRegistry()

    def compensate(payload):
        compensated["value"] = True
        return {"status": "COMPENSATED"}

    registry.register("X", compensate)
    runtime = GovernedExecutionRuntime(
        ledger=OrchestrationEventLedger(tmp_path / "events.json"),
        compensation=registry,
        retry_policy=RetryPolicy(max_attempts=1),
    )
    with pytest.raises(RuntimeError):
        runtime.execute(
            orchestration_id="ORCH-1",
            component="X",
            expected_status="OK",
            handler=lambda payload: (_ for _ in ()).throw(RuntimeError("x")),
            payload={},
        )
    assert compensated["value"] is True


def test_runtime_records_compensation_event(tmp_path):
    registry = CompensationRegistry()
    registry.register("X", lambda payload: {"status": "COMPENSATED"})
    ledger = OrchestrationEventLedger(tmp_path / "events.json")
    runtime = GovernedExecutionRuntime(
        ledger=ledger,
        compensation=registry,
        retry_policy=RetryPolicy(max_attempts=1),
    )
    with pytest.raises(RuntimeError):
        runtime.execute(
            orchestration_id="ORCH-1",
            component="X",
            expected_status="OK",
            handler=lambda payload: (_ for _ in ()).throw(RuntimeError("x")),
            payload={},
        )
    assert ledger.all()[-1]["event_type"] == "COMPENSATION_EXECUTED"


def test_layer3_health_gate_passes(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    assert service.health_gate(all_probes())["passed"] is True


def test_layer3_health_gate_fails_missing_probe(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    probes = all_probes()
    probes.pop("PMO_DIGITAL")
    assert service.health_gate(probes)["passed"] is False


def test_layer3_rejects_closure_without_health(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    with pytest.raises(ValueError):
        service.certify_closure(
            orchestration_id="ORCH-1",
            health_gate={"passed": False},
            orchestration_complete=True,
            adapters_effective=True,
        )


def test_layer3_rejects_closure_without_complete_orchestration(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    with pytest.raises(ValueError):
        service.certify_closure(
            orchestration_id="ORCH-1",
            health_gate={"passed": True},
            orchestration_complete=False,
            adapters_effective=True,
        )


def test_layer3_rejects_closure_without_effective_adapters(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    with pytest.raises(ValueError):
        service.certify_closure(
            orchestration_id="ORCH-1",
            health_gate={"passed": True},
            orchestration_complete=True,
            adapters_effective=False,
        )


def test_layer3_certifies_full_closure(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    gate = service.health_gate(all_probes())
    result = service.certify_closure(
        orchestration_id="ORCH-1",
        health_gate=gate,
        orchestration_complete=True,
        adapters_effective=True,
    )
    assert result["status"] == "SPT0236_INSTITUTIONALLY_CLOSED"


def test_layer3_closure_verifies_event_ledger(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    result = service.certify_closure(
        orchestration_id="ORCH-1",
        health_gate=service.health_gate(all_probes()),
        orchestration_complete=True,
        adapters_effective=True,
    )
    assert result["event_ledger_verified"] is True


def test_layer3_closure_disables_paid_api(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    result = service.certify_closure(
        orchestration_id="ORCH-1",
        health_gate=service.health_gate(all_probes()),
        orchestration_complete=True,
        adapters_effective=True,
    )
    assert result["paid_api_used"] is False


def test_layer3_points_to_spt0237(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    result = service.certify_closure(
        orchestration_id="ORCH-1",
        health_gate=service.health_gate(all_probes()),
        orchestration_complete=True,
        adapters_effective=True,
    )
    assert result["next_component"] == "SPT-023.7"
