from sgoda.workflows.spt0193.institutional_integration import (
    InstitutionalAuditorGateway,
    InstitutionalIntegrationService,
    PMODigitalGateway,
)
from sgoda.workflows.spt0193.orchestrator import OrchestrationResult


class PMO:
    def __init__(self):
        self.events = []

    def record_execution(self, payload):
        self.events.append(payload)
        return "PMO_OK"


class Auditor:
    def __init__(self):
        self.events = []

    def audit_execution(self, payload):
        self.events.append(payload)
        return "AUDIT_OK"


def test_pmo_gateway_records_execution():
    pmo = PMO()
    gateway = PMODigitalGateway(pmo)
    assert gateway.record({"workflow_id": "WF-1"}) == "PMO_OK"
    assert pmo.events[0]["workflow_id"] == "WF-1"


def test_auditor_gateway_records_audit():
    auditor = Auditor()
    gateway = InstitutionalAuditorGateway(auditor)
    assert gateway.audit({"workflow_id": "WF-2"}) == "AUDIT_OK"


def test_integration_service_coordinates_both_components():
    pmo = PMO()
    auditor = Auditor()
    service = InstitutionalIntegrationService(
        PMODigitalGateway(pmo),
        InstitutionalAuditorGateway(auditor),
    )
    result = OrchestrationResult("WF-3", "COMPLETED", {"ok": True}, {})
    integration = service.record_execution(result)
    assert integration["pmo"] == "PMO_OK"
    assert integration["audit"] == "AUDIT_OK"
    assert len(pmo.events) == 1
    assert len(auditor.events) == 1