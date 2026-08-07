from dataclasses import dataclass
from typing import Any, Dict, Optional, Sequence, Tuple


class OrchestrationError(RuntimeError):
    pass


@dataclass(frozen=True)
class OrchestrationResult:
    workflow_id: str
    status: str
    output: Any
    metadata: Dict[str, Any]


def _call_first(
    target: Any,
    names: Sequence[str],
    *args: Any,
    required: bool = True,
    **kwargs: Any
) -> Any:
    for name in names:
        method = getattr(target, name, None)
        if callable(method):
            return method(*args, **kwargs)

    if required:
        raise OrchestrationError(
            "no compatible method found: {0}".format(", ".join(names))
        )
    return None


class InstitutionalWorkflowOrchestrator:
    def __init__(
        self,
        engine: Any,
        registry: Any,
        ipsm: Optional[Any] = None,
        event_bus: Optional[Any] = None,
        integration: Optional[Any] = None,
        evidence: Optional[Any] = None,
    ) -> None:
        if engine is None:
            raise ValueError("engine is required")
        if registry is None:
            raise ValueError("registry is required")

        self.engine = engine
        self.registry = registry
        self.ipsm = ipsm
        self.event_bus = event_bus
        self.integration = integration
        self.evidence = evidence

    def execute(
        self,
        workflow_id: str,
        payload: Optional[Dict[str, Any]] = None,
    ) -> OrchestrationResult:
        if not workflow_id or not workflow_id.strip():
            raise ValueError("workflow_id is required")

        workflow_id = workflow_id.strip()
        payload = dict(payload or {})

        self._publish("workflow.requested", {"workflow_id": workflow_id})

        validation = _call_first(
            self.registry,
            ("validate", "validate_workflow"),
            workflow_id,
            required=False,
        )
        if validation is False:
            raise OrchestrationError("registry rejected workflow: {0}".format(workflow_id))

        workflow = _call_first(
            self.registry,
            ("get", "find", "resolve", "get_workflow"),
            workflow_id,
        )

        output = _call_first(
            self.engine,
            ("execute", "run", "dispatch", "execute_workflow"),
            workflow,
            payload,
        )

        result = OrchestrationResult(
            workflow_id=workflow_id,
            status="COMPLETED",
            output=output,
            metadata={"registered": True},
        )

        if self.integration is not None:
            method = getattr(self.integration, "record_execution", None)
            if callable(method):
                method(result)

        if self.evidence is not None:
            method = getattr(self.evidence, "record", None)
            if callable(method):
                method("workflow.completed", result.__dict__)

        if self.ipsm is not None:
            _call_first(
                self.ipsm,
                ("refresh", "consolidate", "update_project_state"),
                required=False,
            )

        self._publish(
            "workflow.completed",
            {"workflow_id": workflow_id, "status": result.status},
        )
        return result

    def _publish(self, name: str, payload: Dict[str, Any]) -> None:
        if self.event_bus is None:
            return
        method = getattr(self.event_bus, "publish", None)
        if callable(method):
            method(name, payload)