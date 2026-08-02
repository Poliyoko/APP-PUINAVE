"""API FastAPI de SPT-012."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .digital_dictionary import DigitalDictionary
from .media_library import MediaLibrary
from .models import LearningRequest
from .service import LearningPlatformService


def create_app(
    dictionary_path: str | Path,
    media_path: str | Path,
):
    try:
        from fastapi import FastAPI
        from pydantic import BaseModel, Field
    except ImportError as error:
        raise RuntimeError(
            "FastAPI y Pydantic son requeridos para iniciar la API."
        ) from error

    dictionary = DigitalDictionary()
    dictionary.load(dictionary_path)

    media = MediaLibrary()
    media.load(media_path)

    service = LearningPlatformService(
        dictionary,
        media,
    )

    app = FastAPI(
        title="Plataforma de Aprendizaje SGODA-PUINAVE",
        version="1.0.0",
    )

    class ExecuteBody(BaseModel):
        operation: str
        learner_id: str
        language: str = "es"
        entry_id: str | None = None
        payload: dict[str, Any] = Field(default_factory=dict)

    @app.post("/learning/execute")
    def execute(body: ExecuteBody) -> dict:
        response = service.execute(
            LearningRequest(
                operation=body.operation,
                learner_id=body.learner_id,
                language=body.language,
                entry_id=body.entry_id,
                payload=body.payload,
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