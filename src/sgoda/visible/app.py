from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse

from engine import VisibleEngine


HERE = Path(__file__).resolve().parent

DEFAULT_CONFIG = (
    HERE
    / "config"
    / "instance.puinave.pilot20.json"
)

INDEX_HTML = (
    HERE
    / "static"
    / "index-v0.2.0.html"
)


@lru_cache(maxsize=1)
def get_engine() -> VisibleEngine:

    config_path = os.getenv(
        "SGODA_INSTANCE_CONFIG",
        str(DEFAULT_CONFIG),
    )

    return VisibleEngine(
        config_path
    )


app = FastAPI(
    title="SGODA Visible N",
    version="0.2.0",
)


@app.get("/health")
def health():

    engine = get_engine()

    return {
        "status": "ok",
        "version": "0.2.0",
        "records": engine.count(),
        "instance_id":
            engine.instance[
                "instance_id"
            ],
    }


@app.get("/api/meta")
def metadata():

    return get_engine().metadata()


@app.get("/api/lexicon")
def lexicon(
    q: str = "",
    offset: int = Query(
        default=0,
        ge=0,
    ),
    limit: int | None = Query(
        default=None,
        ge=1,
    ),
):

    engine = get_engine()

    page = engine.page(
        query=q,
        offset=offset,
        limit=limit,
    )

    return {
        "total": page.total,
        "offset": page.offset,
        "limit": page.limit,
        "items": page.items,
    }


@app.get(
    "/api/lexicon/{lexical_id}"
)
def lexical_record(
    lexical_id: str,
):

    record = get_engine().get(
        lexical_id
    )

    if record is None:

        raise HTTPException(
            status_code=404,
            detail="Lexical record not found",
        )

    return record


@app.get(
    "/api/audio/{filename}"
)
def audio(
    filename: str,
):

    engine = get_engine()

    try:
        path = engine.audio_path(
            filename
        )

    except ValueError as exc:

        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    if not path.is_file():

        raise HTTPException(
            status_code=404,
            detail="Audio not found",
        )

    return FileResponse(
        path,
        media_type="audio/mpeg",
    )


@app.get("/")
def index():

    return FileResponse(
        INDEX_HTML,
        media_type="text/html",
    )
