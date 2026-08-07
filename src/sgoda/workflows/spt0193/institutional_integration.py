from dataclasses import asdict
from typing import Any, Dict


class IntegrationError(RuntimeError):
    pass


def _invoke(target: Any, names, *args, required=True, **kwargs):
    for name in names:
        method = getattr(target, name, None)
        if callable(method):
            return method(*args, **kwargs)
    if required:
        raise IntegrationError("compatible integration method not found")
    return None


class PMODigitalGateway:
    def __init__(self, pmo: Any) -> None:
        if pmo is None:
            raise ValueError("pmo is required")
        self.pmo = pmo

    def record(self, payload: Dict[str, Any]) -> Any:
        return _invoke(
            self.pmo,
            ("record_execution", "register_event", "record_metric", "update"),
            payload,
        )


class InstitutionalAuditorGateway:
    def __init__(self, auditor: Any) -> None:
        if auditor is None:
            raise ValueError("auditor is required")
        self.auditor = auditor

    def audit(self, payload: Dict[str, Any]) -> Any:
        return _invoke(
            self.auditor,
            ("audit_execution", "audit", "verify", "record"),
            payload,
        )


class InstitutionalIntegrationService:
    def __init__(
        self,
        pmo_gateway: PMODigitalGateway,
        auditor_gateway: InstitutionalAuditorGateway,
    ) -> None:
        self.pmo_gateway = pmo_gateway
        self.auditor_gateway = auditor_gateway

    def record_execution(self, result: Any) -> Dict[str, Any]:
        payload = asdict(result) if hasattr(result, "__dataclass_fields__") else dict(result)
        pmo_result = self.pmo_gateway.record(payload)
        audit_result = self.auditor_gateway.audit(payload)
        return {
            "pmo": pmo_result,
            "audit": audit_result,
            "workflow_id": payload.get("workflow_id"),
        }