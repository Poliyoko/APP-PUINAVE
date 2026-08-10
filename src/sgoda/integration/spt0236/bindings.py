from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .adapters import JsonHttpAdapter, LocalJsonFileAdapter


@dataclass(frozen=True)
class IntegrationBinding:
    component: str
    mode: str
    target: str
    enabled: bool


class EffectiveAdapterRegistry:
    """Registro de adaptadores efectivos para SPT-023.6 Capa 2."""

    def __init__(
        self,
        *,
        fastapi_endpoint: str | None = None,
        n8n_endpoint: str | None = None,
        pmo_state_path: str | None = None,
        auditor_state_path: str | None = None,
        sgd002_state_path: str | None = None,
    ) -> None:
        self.fastapi_endpoint = (fastapi_endpoint or "").strip() or None
        self.n8n_endpoint = (n8n_endpoint or "").strip() or None
        self.pmo_state_path = (pmo_state_path or "").strip() or None
        self.auditor_state_path = (auditor_state_path or "").strip() or None
        self.sgd002_state_path = (sgd002_state_path or "").strip() or None

    def bindings(self) -> list[IntegrationBinding]:
        return [
            IntegrationBinding(
                component="FASTAPI",
                mode="HTTP_JSON",
                target=self.fastapi_endpoint or "",
                enabled=self.fastapi_endpoint is not None,
            ),
            IntegrationBinding(
                component="N8N",
                mode="HTTP_JSON",
                target=self.n8n_endpoint or "",
                enabled=self.n8n_endpoint is not None,
            ),
            IntegrationBinding(
                component="PMO_DIGITAL",
                mode="LOCAL_JSON_FILE",
                target=self.pmo_state_path or "",
                enabled=self.pmo_state_path is not None,
            ),
            IntegrationBinding(
                component="AUDITOR_INSTITUCIONAL",
                mode="LOCAL_JSON_FILE",
                target=self.auditor_state_path or "",
                enabled=self.auditor_state_path is not None,
            ),
            IntegrationBinding(
                component="SGD-002",
                mode="LOCAL_JSON_FILE",
                target=self.sgd002_state_path or "",
                enabled=self.sgd002_state_path is not None,
            ),
        ]

    def build_handlers(self) -> dict[str, Any]:
        handlers: dict[str, Any] = {}

        if self.fastapi_endpoint:
            adapter = JsonHttpAdapter(
                component="FASTAPI",
                endpoint=self.fastapi_endpoint,
            )
            handlers["FASTAPI"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="ORCHESTRATION_EXPOSED",
            ).to_dict()

        if self.n8n_endpoint:
            adapter = JsonHttpAdapter(
                component="N8N",
                endpoint=self.n8n_endpoint,
            )
            handlers["N8N"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="WORKFLOW_COORDINATED",
            ).to_dict()

        if self.pmo_state_path:
            adapter = LocalJsonFileAdapter(
                component="PMO_DIGITAL",
                path=self.pmo_state_path,
            )
            handlers["PMO_DIGITAL"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="PMO_REGISTERED",
            ).to_dict()

        if self.auditor_state_path:
            adapter = LocalJsonFileAdapter(
                component="AUDITOR_INSTITUCIONAL",
                path=self.auditor_state_path,
            )
            handlers["AUDITOR_INSTITUCIONAL"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="AUDIT_APPROVED",
            ).to_dict()

        if self.sgd002_state_path:
            adapter = LocalJsonFileAdapter(
                component="SGD-002",
                path=self.sgd002_state_path,
            )
            handlers["SGD-002"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="MASTER_BOOK_UPDATED",
            ).to_dict()

        return handlers
