import pytest

from sgoda.platform.health_monitor import (
    DuplicateHealthCheckError,
    HealthCheckResult,
    HealthSeverity,
    HealthStatus,
    InstitutionalHealthMonitor,
    InstitutionalHealthReporter,
    boolean_health_adapter,
    metric_threshold_adapter,
)


def test_health_check_requires_identity():
    with pytest.raises(ValueError):
        HealthCheckResult("", "SPT-020.1", True)


def test_monitor_registers_and_runs_boolean_check():
    monitor = InstitutionalHealthMonitor()
    monitor.register("service-bus", "SPT-020.1", lambda: True)
    snapshot = monitor.run()
    assert snapshot.status == HealthStatus.HEALTHY
    assert snapshot.healthy_checks == 1


def test_duplicate_check_is_rejected():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "component", lambda: True)

    with pytest.raises(DuplicateHealthCheckError):
        monitor.register("check", "component", lambda: True)


def test_warning_failure_degrades_platform():
    monitor = InstitutionalHealthMonitor()
    monitor.register(
        "latency",
        "SPT-020.1",
        lambda: {
            "healthy": False,
            "severity": HealthSeverity.WARNING,
            "detail": "slow",
        },
    )
    snapshot = monitor.run()
    assert snapshot.status == HealthStatus.DEGRADED
    assert snapshot.degraded_checks == 1


def test_error_failure_marks_platform_unhealthy():
    monitor = InstitutionalHealthMonitor()
    monitor.register(
        "runtime",
        "SPT-020.6",
        lambda: {
            "healthy": False,
            "severity": HealthSeverity.ERROR,
            "detail": "failed",
        },
    )
    snapshot = monitor.run()
    assert snapshot.status == HealthStatus.UNHEALTHY
    assert snapshot.failed_checks == 1


def test_provider_exception_becomes_critical_alert():
    monitor = InstitutionalHealthMonitor()

    def failing():
        raise RuntimeError("provider failure")

    monitor.register("provider", "SPT-020.5", failing)
    snapshot = monitor.run()
    assert snapshot.status == HealthStatus.UNHEALTHY
    assert snapshot.alerts[0].severity == HealthSeverity.CRITICAL
    assert snapshot.alerts[0].detail == "provider failure"


def test_monitor_accepts_health_result():
    monitor = InstitutionalHealthMonitor()
    monitor.register(
        "custom",
        "SPT-020.4",
        lambda: HealthCheckResult(
            "custom",
            "SPT-020.4",
            True,
            metrics={"events": 10},
        ),
    )
    snapshot = monitor.run()
    assert snapshot.results[0].metrics["events"] == 10


def test_component_filter_runs_only_requested_checks():
    monitor = InstitutionalHealthMonitor()
    monitor.register("a", "SPT-A", lambda: True)
    monitor.register("b", "SPT-B", lambda: True)
    snapshot = monitor.run(component_id="SPT-B")
    assert len(snapshot.results) == 1
    assert snapshot.results[0].component_id == "SPT-B"


def test_empty_monitor_reports_unknown():
    snapshot = InstitutionalHealthMonitor().run()
    assert snapshot.status == HealthStatus.UNKNOWN


def test_latest_returns_last_snapshot():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "SPT-020.1", lambda: True)
    first = monitor.run()
    second = monitor.run()
    assert monitor.latest() is second
    assert monitor.latest() is not first


def test_latest_without_history_is_blocked():
    with pytest.raises(RuntimeError):
        InstitutionalHealthMonitor().latest()


def test_component_summary_reports_states():
    monitor = InstitutionalHealthMonitor()
    monitor.register("healthy", "SPT-A", lambda: True)
    monitor.register(
        "warning",
        "SPT-B",
        lambda: {
            "healthy": False,
            "severity": HealthSeverity.WARNING,
        },
    )
    monitor.run()
    summary = monitor.component_summary()
    assert summary["SPT-A"] == HealthStatus.HEALTHY
    assert summary["SPT-B"] == HealthStatus.DEGRADED


def test_boolean_adapter_creates_health_result():
    check = boolean_health_adapter(
        "bus",
        "SPT-020.1",
        lambda: True,
    )
    result = check()
    assert result.healthy is True
    assert result.check_id == "bus"


def test_metric_threshold_adapter_approves_value():
    check = metric_threshold_adapter(
        "latency",
        "SPT-020.4",
        lambda: 10,
        maximum=20,
        metric_name="latency_ms",
    )
    result = check()
    assert result.healthy is True
    assert result.metrics["latency_ms"] == 10.0


def test_metric_threshold_adapter_detects_excess():
    check = metric_threshold_adapter(
        "latency",
        "SPT-020.4",
        lambda: 30,
        maximum=20,
        metric_name="latency_ms",
    )
    result = check()
    assert result.healthy is False
    assert result.severity == HealthSeverity.WARNING


def test_reporter_serializes_snapshot():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "SPT-020.1", lambda: True)
    snapshot = monitor.run()
    report = InstitutionalHealthReporter().to_dict(snapshot)
    assert report["status"] == "HEALTHY"
    assert report["healthy_checks"] == 1


def test_history_preserves_snapshots():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "SPT-020.1", lambda: True)
    monitor.run()
    monitor.run()
    assert len(monitor.history) == 2


def test_unregister_removes_check():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "SPT-020.1", lambda: True)
    monitor.registry.unregister("check")
    assert monitor.run().status == HealthStatus.UNKNOWN