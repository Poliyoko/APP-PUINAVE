from datetime import datetime, timedelta, timezone

import pytest

from sgoda.platform.service_discovery import (
    DuplicateServiceError,
    InstitutionalServiceDiscovery,
    InstitutionalServiceRegistry,
    InvalidServiceVersionError,
    NoServiceAvailableError,
    ServiceDefinition,
    ServiceEndpoint,
    ServiceRegistryHealthMonitor,
    ServiceStatus,
    is_compatible,
    parse_version,
)


def build_service(
    service_id="service-1",
    name="lexical",
    version="1.0.0",
    capabilities=("search",),
):
    return ServiceDefinition(
        service_id=service_id,
        name=name,
        version=version,
        capabilities=capabilities,
        endpoints=(ServiceEndpoint("inproc", "sgoda://lexical"),),
    )


def test_service_requires_endpoint():
    with pytest.raises(ValueError):
        ServiceDefinition("service", "name", "1.0.0", (), ())


def test_parse_semantic_version():
    assert parse_version("1.2.3") == (1, 2, 3)


def test_invalid_version_is_rejected():
    with pytest.raises(InvalidServiceVersionError):
        parse_version("1.2")


def test_version_compatibility():
    assert is_compatible("1.5.0", "1.0.0", "2.0.0") is True
    assert is_compatible("2.1.0", "1.0.0", "2.0.0") is False


def test_registry_registers_service():
    registry = InstitutionalServiceRegistry()
    record = registry.register(build_service())
    assert record.status == ServiceStatus.AVAILABLE


def test_registry_rejects_duplicate_service():
    registry = InstitutionalServiceRegistry()
    service = build_service()
    registry.register(service)

    with pytest.raises(DuplicateServiceError):
        registry.register(service)


def test_discover_by_capability():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    matches = registry.discover(capability="search")
    assert matches[0].definition.service_id == "service-1"


def test_discover_filters_unavailable_services():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    registry.set_status("service-1", ServiceStatus.UNAVAILABLE)
    assert registry.discover(capability="search") == ()


def test_discovery_resolves_highest_compatible_service():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service("service-1", version="1.0.0"))
    registry.register(build_service("service-2", version="1.5.0"))
    discovery = InstitutionalServiceDiscovery(registry)
    result = discovery.resolve("search", "1.0.0", "2.0.0")
    assert result.definition.service_id == "service-2"


def test_discovery_raises_when_service_is_missing():
    discovery = InstitutionalServiceDiscovery(
        InstitutionalServiceRegistry()
    )

    with pytest.raises(NoServiceAvailableError):
        discovery.resolve("missing")


def test_heartbeat_updates_status():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    registry.heartbeat("service-1", ServiceStatus.DEGRADED)
    assert registry.get("service-1").status == ServiceStatus.DEGRADED


def test_stale_service_is_expired():
    registry = InstitutionalServiceRegistry()
    record = registry.register(build_service())
    record.last_heartbeat_utc = (
        datetime.now(timezone.utc) - timedelta(minutes=10)
    ).isoformat()

    discovery = InstitutionalServiceDiscovery(registry)
    expired = discovery.expire_stale(
        max_age_seconds=60,
        now_utc=datetime.now(timezone.utc),
    )

    assert expired == ("service-1",)
    assert record.status == ServiceStatus.UNAVAILABLE


def test_registry_can_unregister_service():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    registry.unregister("service-1")
    assert tuple(registry.records()) == ()


def test_health_report_counts_services():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    report = ServiceRegistryHealthMonitor().evaluate(registry)
    assert report.healthy is True
    assert report.total_services == 1
    assert report.available_services == 1


def test_health_report_detects_no_available_services():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    registry.set_status("service-1", ServiceStatus.UNAVAILABLE)
    report = ServiceRegistryHealthMonitor().evaluate(registry)
    assert report.healthy is False