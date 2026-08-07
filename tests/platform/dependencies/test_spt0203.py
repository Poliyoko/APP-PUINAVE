import pytest

from sgoda.platform.dependencies import (
    ComponentDependencyRegistry,
    DependencyCompatibilityError,
    DependencyComponent,
    DependencyCycleError,
    DependencyHealthMonitor,
    DependencyRegistryError,
    DependencyRequirement,
    InstitutionalComponentDependencyManager,
    InvalidVersionError,
    MissingDependencyError,
    is_compatible,
    parse_version,
)


def test_parse_semantic_version():
    assert parse_version("1.2.3") == (1, 2, 3)


def test_invalid_version_is_rejected():
    with pytest.raises(InvalidVersionError):
        parse_version("1.2")


def test_version_compatibility_range():
    assert is_compatible("1.5.0", "1.0.0", "2.0.0") is True
    assert is_compatible("2.1.0", "1.0.0", "2.0.0") is False


def test_registry_rejects_duplicate():
    registry = ComponentDependencyRegistry()
    component = DependencyComponent("SPT-A", "1.0.0")
    registry.register(component)

    with pytest.raises(DependencyRegistryError):
        registry.register(component)


def test_missing_dependency_is_detected():
    manager = InstitutionalComponentDependencyManager()
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )

    with pytest.raises(MissingDependencyError):
        manager.validate_component("SPT-B")


def test_incompatible_dependency_is_detected():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(
                DependencyRequirement(
                    "SPT-A",
                    minimum_version="2.0.0",
                ),
            ),
        )
    )

    with pytest.raises(DependencyCompatibilityError):
        manager.validate_component("SPT-B")


def test_valid_dependency_is_approved():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.2.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(
                DependencyRequirement(
                    "SPT-A",
                    minimum_version="1.0.0",
                    maximum_version="2.0.0",
                ),
            ),
        )
    )
    manager.validate_component("SPT-B")


def test_installation_order_places_dependencies_first():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )
    assert manager.installation_order() == ("SPT-A", "SPT-B")


def test_cycle_is_detected():
    manager = InstitutionalComponentDependencyManager()
    manager.register(
        DependencyComponent(
            "SPT-A",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-B"),),
        )
    )
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )

    with pytest.raises(DependencyCycleError):
        manager.validate_all()


def test_dependents_are_reported():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )
    manager.register(
        DependencyComponent(
            "SPT-C",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )
    assert manager.dependents_of("SPT-A") == ("SPT-B", "SPT-C")


def test_validate_all_approves_valid_graph():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )
    manager.validate_all()


def test_health_monitor_reports_valid_graph():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    report = DependencyHealthMonitor().evaluate(manager)
    assert report.healthy is True
    assert report.components[0].component_id == "SPT-A"