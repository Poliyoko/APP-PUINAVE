from __future__ import annotations

import csv
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse


HERE = Path(__file__).resolve().parent

def find_repo_root() -> Path:
    current = HERE

    for candidate in [current, *current.parents]:
        if (candidate / "tools" / "sgoda_audio_manager").is_dir():
            return candidate

    raise RuntimeError("SGODA repository root not found")


REPO_ROOT = find_repo_root()

INPUT_CSV = (
    REPO_ROOT
    / "tools"
    / "sgoda_audio_manager"
    / "v0.1.0"
    / "input"
    / "entrada_minima_puinave_20.csv"
)
AUDIO_ROOT = Path(r"G:/Mi unidad/SGODA-PUINAVE/AUDIOS/PRUEBA_20_PALABRAS/MP3")
INDEX_HTML = Path(__file__).resolve().parent / "index.html"

ID_COLUMN = "ID"
WORD_COLUMN = "PALABRA EN PUINAVE"
PRON_COLUMN = "PRONUNCIACION EN PUINAVE"
ES_COLUMN = "PALABRA EN ESPA\u00d1OL"

app = FastAPI(
    title="SGODA Visible Pilot-20",
    version="0.1.0",
)


def load_records():
    records = []

    with INPUT_CSV.open(
        "r",
        encoding="utf-8-sig",
        newline="",
    ) as stream:

        reader = csv.DictReader(stream)

        for row in reader:

            source_id = str(
                row[ID_COLUMN]
            ).zfill(6)

            records.append(
                {
                    "lexical_id": f"PU-{source_id}",
                    "source_id": source_id,
                    "native_word": row[WORD_COLUMN].strip(),
                    "native_pronunciation": (
                        row[PRON_COLUMN].strip()
                    ),
                    "translation_es": (
                        row[ES_COLUMN].strip()
                    ),
                    "audio_file": (
                        f"PU-{source_id}_pu.mp3"
                    ),
                }
            )

    return records


@app.get("/health")
def health():

    return {
        "status": "ok",
        "records": len(load_records()),
    }


@app.get("/api/lexicon")
def lexicon(q: str = ""):

    records = load_records()
    query = q.strip().casefold()

    if not query:
        return records

    return [
        row
        for row in records
        if (
            query
            in row["native_word"].casefold()
            or query
            in row["translation_es"].casefold()
            or query
            in row["lexical_id"].casefold()
        )
    ]


@app.get("/api/lexicon/{lexical_id}")
def lexical_record(lexical_id: str):

    for row in load_records():

        if row["lexical_id"] == lexical_id:
            return row

    raise HTTPException(
        status_code=404,
        detail="Lexical record not found",
    )


@app.get("/api/audio/{filename}")
def audio_file(filename: str):

    if Path(filename).name != filename:

        raise HTTPException(
            status_code=400,
            detail="Invalid filename",
        )

    candidate = AUDIO_ROOT / filename

    if not candidate.is_file():

        raise HTTPException(
            status_code=404,
            detail="Audio not found",
        )

    return FileResponse(
        candidate,
        media_type="audio/mpeg",
    )


@app.get("/")
def index():

    return FileResponse(
        INDEX_HTML,
        media_type="text/html",
    )
