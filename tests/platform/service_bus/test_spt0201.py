import pytest

from sgoda.platform.service_bus import (
    InstitutionalBusHealthMonitor,
    InstitutionalMessage,
    InstitutionalServiceBus,
    InstitutionalServiceRegistry,
    RoutingError,
    ServiceRegistrationError,
)


class Service:
    def __init__(self):
        self.received = []

    def handle(self, message):
        self.received.append(message)
        return message.payload.get("value", "OK")

    def health(self):
        return True


def test_message_requires_topic():
    with pytest.raises(ValueError):
        InstitutionalMessage("", {}, "test")


def test_message_copies_payload():
    payload = {"value": 1}
    message = InstitutionalMessage("topic", payload, "test")
    payload["value"] = 2
    assert message.payload["value"] == 1


def test_registry_requires_handle_contract():
    registry = InstitutionalServiceRegistry()
    with pytest.raises(ServiceRegistrationError):
        registry.register("invalid", object())


def test_registry_registers_and_gets_service():
    registry = InstitutionalServiceRegistry()
    service = Service()
    registry.register("service", service, ("topic",))
    assert registry.get("service") is service


def test_bus_routes_message():
    bus = InstitutionalServiceBus()
    service = Service()
    bus.register_service("service", service, ("topic",))
    receipt = bus.publish("topic", {"value": 7}, "test")
    assert receipt.deliveries[0].output == 7
    assert len(bus.history) == 1


def test_bus_rejects_unknown_topic():
    bus = InstitutionalServiceBus()
    with pytest.raises(RoutingError):
        bus.publish("missing", {}, "test")


def test_bus_applies_middleware():
    bus = InstitutionalServiceBus()
    service = Service()
    bus.register_service("service", service, ("topic",))

    def enrich(message):
        message.payload["validated"] = True
        return message

    bus.add_middleware(enrich)
    bus.publish("topic", {}, "test")
    assert service.received[0].payload["validated"] is True


def test_health_monitor_reports_healthy_service():
    registry = InstitutionalServiceRegistry()
    registry.register("service", Service(), ("topic",))
    report = InstitutionalBusHealthMonitor().evaluate(registry)
    assert report.healthy is True
    assert report.services[0].name == "service"