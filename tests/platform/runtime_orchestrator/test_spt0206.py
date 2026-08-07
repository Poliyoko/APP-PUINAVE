import pytest

from sgoda.platform.runtime_orchestrator import (
    DuplicateRuntimeUnitError,
    InstitutionalRuntimeOrchestrator,
    RuntimeDependencyCycleError,
    RuntimeDependencyError,
    RuntimeHealthMonitor,
    RuntimeStartError,
    RuntimeState,
    RuntimeTransitionError,
    RuntimeUnitDefinition,
)


def unit(unit_id, started, stopped, dependencies=(), fail=False):
    def start():
        if fail:
            raise RuntimeError("start failure")
        started.append(unit_id)

    def stop():
        stopped.append(unit_id)

    return RuntimeUnitDefinition(
        unit_id=unit_id,
        version="1.0.0",
        start=start,
        stop=stop,
        dependencies=dependencies,
    )


def test_runtime_unit_requires_identity():
    with pytest.raises(ValueError):
        RuntimeUnitDefinition("", "1.0.0", lambda: None, lambda: None)


def test_duplicate_runtime_unit_is_rejected():
    orchestrator = InstitutionalRuntimeOrchestrator()
    definition = unit("A", [], [])
    orchestrator.register(definition)

    with pytest.raises(DuplicateRuntimeUnitError):
        orchestrator.register(definition)


def test_startup_order_places_dependencies_first():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.register(unit("B", [], [], dependencies=("A",)))
    assert orchestrator.planner.startup_order() == ("A", "B")


def test_shutdown_order_is_reversed():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.register(unit("B", [], [], dependencies=("A",)))
    assert orchestrator.planner.shutdown_order() == ("B", "A")


def test_missing_dependency_is_detected():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("B", [], [], dependencies=("A",)))

    with pytest.raises(RuntimeDependencyError):
        orchestrator.planner.startup_order()


def test_dependency_cycle_is_detected():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], [], dependencies=("B",)))
    orchestrator.register(unit("B", [], [], dependencies=("A",)))

    with pytest.raises(RuntimeDependencyCycleError):
        orchestrator.planner.startup_order()


def test_start_all_follows_dependency_order():
    started = []
    stopped = []
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", started, stopped))
    orchestrator.register(
        unit("B", started, stopped, dependencies=("A",))
    )

    orchestrator.start_all()

    assert started == ["A", "B"]
    assert orchestrator.registry.get("B").state == RuntimeState.RUNNING


def test_stop_all_uses_reverse_order():
    started = []
    stopped = []
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", started, stopped))
    orchestrator.register(
        unit("B", started, stopped, dependencies=("A",))
    )

    orchestrator.start_all()
    orchestrator.stop_all()

    assert stopped == ["B", "A"]


def test_start_unit_requires_running_dependencies():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.register(unit("B", [], [], dependencies=("A",)))

    with pytest.raises(RuntimeTransitionError):
        orchestrator.start_unit("B")


def test_runtime_start_failure_sets_failed_state():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], [], fail=True))

    with pytest.raises(RuntimeStartError):
        orchestrator.start_unit("A")

    record = orchestrator.registry.get("A")
    assert record.state == RuntimeState.FAILED
    assert record.last_error == "start failure"


def test_start_all_rolls_back_started_units():
    started = []
    stopped = []
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", started, stopped))
    orchestrator.register(
        unit("B", started, stopped, dependencies=("A",), fail=True)
    )

    with pytest.raises(RuntimeStartError):
        orchestrator.start_all()

    assert stopped == ["A"]
    assert orchestrator.registry.get("A").state == RuntimeState.STOPPED


def test_hooks_receive_runtime_events():
    received = []
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.add_hook("STARTED", received.append)
    orchestrator.start_unit("A")
    assert received[0].unit_id == "A"


def test_history_preserves_state_transitions():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.start_unit("A")
    actions = [event.action for event in orchestrator.history]
    assert actions == ["STARTING", "STARTED"]


def test_running_unit_cannot_start_twice():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.start_unit("A")

    with pytest.raises(RuntimeTransitionError):
        orchestrator.start_unit("A")


def test_health_report_counts_running_units():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.start_unit("A")
    report = RuntimeHealthMonitor().evaluate(orchestrator.registry)
    assert report.healthy is True
    assert report.running_units == 1
    assert report.failed_units == 0


def test_health_report_detects_failed_units():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], [], fail=True))

    with pytest.raises(RuntimeStartError):
        orchestrator.start_unit("A")

    report = RuntimeHealthMonitor().evaluate(orchestrator.registry)
    assert report.healthy is False
    assert report.failed_units == 1