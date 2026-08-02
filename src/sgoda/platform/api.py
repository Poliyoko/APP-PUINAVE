"""API institucional FastAPI con importación controlada."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .models import PlatformRequest
from .runtime import build_runtime


def create_app(graph_path: str | Path):
    try:
        from fastapi import FastAPI
        from pydantic import BaseModel, Field
    except ImportError as error:
        raise RuntimeError(
            "FastAPI y Pydantic son requeridos para iniciar la API."
        ) from error

    runtime = build_runtime(graph_path)
    app = FastAPI(
        title="SGODA Plataforma Digital Integrada",
        version="1.0.0",
    )

    class RequestBody(BaseModel):
        operation: str
        payload: dict[str, Any] = Field(default_factory=dict)
        session_id: str = "anonymous"
        language: str = "es"
        context_node_id: str | None = None

    @app.get("/health")
    def health() -> dict:
        return {
            "status": "ok",
            "component": "SPT-010",
            "version": "1.0.0",
        }

    @app.get("/capabilities")
    def capabilities() -> dict:
        return {
            "operations": list(
                runtime.registry.operations()
            ),
            "components": [
                {
                    "code": item.code,
                    "name": item.name,
                    "version": item.version,
                    "enabled": item.enabled,
                    "operations": list(item.operations),
                }
                for item in runtime.registry.all()
            ],
        }

    @app.post("/execute")
    def execute(body: RequestBody) -> dict:
        response = runtime.execute(
            PlatformRequest(
                operation=body.operation,
                payload=body.payload,
                session_id=body.session_id,
                language=body.language,
                context_node_id=body.context_node_id,
            )
        )

        return {
            "operation": response.operation,
            "status": response.status,
            "data": response.data,
            "sources": list(response.sources),
            "warnings": list(response.warnings),
            "no_invention": response.no_invention,
        }

    return app