"""API operativa FastAPI de SPT-011."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .database import OperationalRepository
from .models import OperationalRequest
from .service import OperationalPlatformService
from .settings import OperationalSettings
from sgoda.operational_platform.real508_media import router as real508_media_router


def create_app(
    settings_path: str | Path,
    rlb_path: str | Path,
    media_path: str | Path | None = None,
    repository: OperationalRepository | None = None,
):
    try:
        from fastapi import FastAPI, HTTPException
        from fastapi.middleware.cors import CORSMiddleware
        from pydantic import BaseModel, Field
    except ImportError as error:
        raise RuntimeError(
            "FastAPI y Pydantic son requeridos para iniciar la API."
        ) from error

    settings = OperationalSettings.from_json(settings_path)
    service = OperationalPlatformService(settings, repository=repository)

    if repository is None:
        service.load_sources(rlb_path, media_path)

    app = FastAPI(
        title="SGODA-PUINAVE Plataforma Operativa",
        version="1.0.0",
    )

    # SGODA Flutter Web local -> FastAPI REAL508 local.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "http://127.0.0.1:8080",
            "http://localhost:8080",
        ],
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["*"],
    )

    class ExecuteBody(BaseModel):
        operation: str
        payload: dict[str, Any] = Field(default_factory=dict)
        session_id: str = "anonymous"
        language: str = "es"
        entry_id: str | None = None

    @app.get("/health")
    def health() -> dict:
        response = service.execute(
            OperationalRequest(operation="health")
        )

        return {
            "status": response.status,
            "data": response.data,
            "no_invention": response.no_invention,
        }

    @app.get("/lexical/{entry_id}")
    def lexical(entry_id: str) -> dict:
        response = service.execute(
            OperationalRequest(
                operation="get_lexical_card",
                entry_id=entry_id,
            )
        )

        if response.status == "not_found":
            raise HTTPException(
                status_code=404,
                detail="Entrada léxica no encontrada.",
            )

        return {
            "status": response.status,
            "data": response.data,
            "sources": list(response.sources),
            "no_invention": response.no_invention,
        }

    @app.post("/execute")
    def execute(body: ExecuteBody) -> dict:
        response = service.execute(
            OperationalRequest(
                operation=body.operation,
                payload=body.payload,
                session_id=body.session_id,
                language=body.language,
                entry_id=body.entry_id,
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

    # REAL508-INTEGRATION-30
    app.include_router(real508_media_router)

    return app
