import pytest

from sgoda.platform.lifecycle import (
    ComponentDefinition,
    ComponentLifecycleManager,
    ComponentLifecycleRegistry,
    ComponentRegistryError,
    ComponentState,
    DependencyValidationError,
    LifecycleHealthMonitor,
    LifecycleTransitionError,
)


def test_definition_requires_identity():
    with pytest.raises(ValueError):
        ComponentDefinition("", "1.0.0")


def test_registry_rejects_duplicate_component():
    registry = ComponentLifecycleRegistry()
    definition = ComponentDefinition("SPT-TEST", "1.0.0")
    registry.register(definition)

    with pytest.raises(ComponentRegistryError):
        registry.register(definition)


def test_manager_registers_component():
    manager = ComponentLifecycleManager()
    record = manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    assert record.state == ComponentState.REGISTERED


def test_install_and_activate_component():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.install("SPT-TEST")
    manager.activate("SPT-TEST")
    assert manager.registry.get("SPT-TEST").state == ComponentState.ACTIVE


def test_suspend_and_reactivate_component():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.install("SPT-TEST")
    manager.activate("SPT-TEST")
    manager.suspend("SPT-TEST")
    manager.activate("SPT-TEST")
    assert manager.registry.get("SPT-TEST").state == ComponentState.ACTIVE


def test_invalid_transition_is_blocked():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))

    with pytest.raises(LifecycleTransitionError):
        manager.activate("SPT-TEST")


def test_missing_dependency_is_blocked():
    manager = ComponentLifecycleManager()
    manager.register(
        ComponentDefinition(
            "SPT-CHILD",
            "1.0.0",
            dependencies=("SPT-PARENT",),
        )
    )

    with pytest.raises(DependencyValidationError):
        manager.install("SPT-CHILD")


def test_dependency_allows_installation():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-PARENT", "1.0.0"))
    manager.register(
        ComponentDefinition(
            "SPT-CHILD",
            "1.0.0",
            dependencies=("SPT-PARENT",),
        )
    )
    event = manager.install("SPT-CHILD")
    assert event.current_state == ComponentState.INSTALLED


def test_hook_receives_transition_event():
    manager = ComponentLifecycleManager()
    received = []
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.add_hook(ComponentState.INSTALLED, received.append)
    manager.install("SPT-TEST", "installation")
    assert received[0].reason == "installation"


def test_history_preserves_transition_order():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.install("SPT-TEST")
    manager.activate("SPT-TEST")
    assert [event.current_state for event in manager.history] == [
        ComponentState.INSTALLED,
        ComponentState.ACTIVE,
    ]


def test_retired_component_cannot_reactivate():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.install("SPT-TEST")
    manager.retire("SPT-TEST")

    with pytest.raises(LifecycleTransitionError):
        manager.activate("SPT-TEST")


def test_health_snapshot_contains_registered_components():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    snapshot = LifecycleHealthMonitor().snapshot(manager.registry)
    assert snapshot.healthy is True
    assert snapshot.components[0].component_id == "SPT-TEST"