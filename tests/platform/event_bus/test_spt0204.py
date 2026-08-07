import pytest

from sgoda.platform.event_bus import (
    EventBusHealthMonitor,
    EventPriority,
    EventSubscriptionRegistry,
    InstitutionalEvent,
    InstitutionalEventBus,
    NoSubscriberError,
    SubscriptionError,
)


def test_event_requires_type():
    with pytest.raises(ValueError):
        InstitutionalEvent("", {}, "test")


def test_event_copies_payload():
    payload = {"value": 1}
    event = InstitutionalEvent("component.active", payload, "SPT-020.2")
    payload["value"] = 2
    assert event.payload["value"] == 1


def test_priority_values_are_ordered():
    assert EventPriority.CRITICAL > EventPriority.HIGH
    assert EventPriority.HIGH > EventPriority.NORMAL


def test_registry_rejects_duplicate_subscriber():
    registry = EventSubscriptionRegistry()
    registry.subscribe("audit", lambda event: None)

    with pytest.raises(SubscriptionError):
        registry.subscribe("audit", lambda event: None)


def test_publish_delivers_to_matching_subscriber():
    bus = InstitutionalEventBus()
    received = []
    bus.subscribe("audit", received.append, ("component.active",))

    event = InstitutionalEvent(
        "component.active",
        {"component": "SPT-020.3"},
        "SPT-020.2",
    )
    deliveries = bus.publish(event)

    assert deliveries[0].delivered is True
    assert received[0].payload["component"] == "SPT-020.3"


def test_publish_delivers_to_multiple_subscribers():
    bus = InstitutionalEventBus()
    first = []
    second = []
    bus.subscribe("first", first.append, ("event",))
    bus.subscribe("second", second.append, ("event",))
    deliveries = bus.publish(InstitutionalEvent("event", {}, "test"))
    assert len(deliveries) == 2
    assert len(first) == 1
    assert len(second) == 1


def test_event_type_filter_is_respected():
    bus = InstitutionalEventBus()
    received = []
    bus.subscribe("audit", received.append, ("allowed",))

    with pytest.raises(NoSubscriberError):
        bus.publish(InstitutionalEvent("other", {}, "test"))


def test_handler_is_retried_until_success():
    bus = InstitutionalEventBus(max_attempts=3)
    calls = {"count": 0}

    def handler(event):
        calls["count"] += 1
        if calls["count"] < 2:
            raise RuntimeError("temporary")

    bus.subscribe("retry", handler, ("event",))
    delivery = bus.publish(InstitutionalEvent("event", {}, "test"))[0]

    assert delivery.delivered is True
    assert delivery.attempts == 2
    assert len(bus.dead_letters) == 0


def test_failed_handler_goes_to_dead_letter_queue():
    bus = InstitutionalEventBus(max_attempts=2)

    def handler(event):
        raise RuntimeError("permanent")

    bus.subscribe("failed", handler, ("event",))
    delivery = bus.publish(InstitutionalEvent("event", {}, "test"))[0]

    assert delivery.delivered is False
    assert delivery.attempts == 2
    assert len(bus.dead_letters) == 1


def test_dead_letter_can_be_replayed():
    bus = InstitutionalEventBus(max_attempts=1)
    state = {"working": False}

    def handler(event):
        if not state["working"]:
            raise RuntimeError("not ready")

    bus.subscribe("recoverable", handler, ("event",))
    bus.publish(InstitutionalEvent("event", {}, "test"))
    assert len(bus.dead_letters) == 1

    state["working"] = True
    replayed = bus.replay_dead_letters()

    assert replayed[0].delivered is True
    assert len(bus.dead_letters) == 0


def test_history_preserves_deliveries():
    bus = InstitutionalEventBus()
    bus.subscribe("audit", lambda event: None, ("event",))
    bus.publish(InstitutionalEvent("event", {}, "test"))
    assert len(bus.history) == 1


def test_health_report_is_healthy_without_dead_letters():
    bus = InstitutionalEventBus()
    bus.subscribe("audit", lambda event: None, ("event",))
    bus.publish(InstitutionalEvent("event", {}, "test"))
    report = EventBusHealthMonitor().evaluate(bus)
    assert report.healthy is True
    assert report.subscribers == 1
    assert report.dead_letters == 0


def test_health_report_detects_dead_letters():
    bus = InstitutionalEventBus(max_attempts=1)

    def handler(event):
        raise RuntimeError("failure")

    bus.subscribe("failed", handler, ("event",))
    bus.publish(InstitutionalEvent("event", {}, "test"))
    report = EventBusHealthMonitor().evaluate(bus)
    assert report.healthy is False
    assert report.dead_letters == 1