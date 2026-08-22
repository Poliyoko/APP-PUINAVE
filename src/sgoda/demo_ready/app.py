from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from .pilot25 import Pilot25Repository


app = FastAPI(
    title="SGODA-PUINAVE Demo-Ready",
    version="1.0.0",
    description="Piloto funcional SGODA con 25 registros Puinave reales.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)


@lru_cache(maxsize=1)
def get_repository() -> Pilot25Repository:
    records = os.environ.get("SGODA_PILOT25_RECORDS")
    drive = os.environ.get("SGODA_PILOT25_DRIVE_ROOT")

    if not records:
        raise RuntimeError(
            "SGODA_PILOT25_RECORDS is not configured."
        )

    if not drive:
        raise RuntimeError(
            "SGODA_PILOT25_DRIVE_ROOT is not configured."
        )

    return Pilot25Repository(records, drive)


def repository_or_503() -> Pilot25Repository:
    try:
        return get_repository()
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=str(exc),
        ) from exc


@app.get("/health")
def health() -> dict:
    return {
        "service": "SGODA-PUINAVE Demo-Ready",
        "status": "UP",
    }


@app.get("/api/demo/pilot25")
def list_pilot25() -> dict:
    repository = repository_or_503()

    return {
        "summary": repository.summary(),
        "records": [
            repository.public_record(record)
            for record in repository.list()
        ],
    }


@app.get("/api/demo/pilot25/{lexical_id}")
def get_record(lexical_id: str) -> dict:
    repository = repository_or_503()
    record = repository.get(lexical_id)

    if record is None:
        raise HTTPException(
            status_code=404,
            detail="Registro léxico no encontrado.",
        )

    return repository.public_record(record)


@app.get("/api/demo/pilot25/{lexical_id}/audio")
def get_audio(lexical_id: str):
    repository = repository_or_503()
    audio = repository.audio_path(lexical_id)

    if audio is None:
        raise HTTPException(
            status_code=404,
            detail="Audio Puinave no encontrado.",
        )

    media_types = {
        ".mp3": "audio/mpeg",
        ".wav": "audio/wav",
        ".ogg": "audio/ogg",
        ".m4a": "audio/mp4",
        ".flac": "audio/flac",
    }

    return FileResponse(
        str(audio),
        media_type=media_types.get(
            audio.suffix.lower(),
            "application/octet-stream",
        ),
    )


@app.get("/")
def portal():
    web = Path(__file__).parent / "web" / "index.html"

    return FileResponse(
        str(web),
        media_type="text/html",
    )