from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path

from fastapi.testclient import TestClient


HERE = Path(__file__).resolve()
VISIBLE = HERE.parents[1]
CONFIG = VISIBLE / "config" / "instance.puinave.real25.json"

sys.path.insert(0, str(VISIBLE))

from engine import VisibleEngine


SPANISH_KEY = "primary_translation"

EXPECTED_NEW = {
    "PU-000021": {
        "native_word": "YÜG",
        "native_pronunciation": "(llïc)",
        "spanish": "yucal recién sembrado",
        "audio_file": "PU-000021_pu.mp3",
    },
    "PU-000022": {
        "native_word": "YÜI",
        "native_pronunciation": "(llöì)",
        "spanish": "diarrea",
        "audio_file": "PU-000022_pu.mp3",
    },
    "PU-000023": {
        "native_word": "YÖIPIG",
        "native_pronunciation": "(yöipik)",
        "spanish": "escama de pescado",
        "audio_file": "PU-000023_pu.mp3",
    },
    "PU-000024": {
        "native_word": "YÖI",
        "native_pronunciation": "(llöì)",
        "spanish": "pez, pescado",
        "audio_file": "PU-000024_pu.mp3",
    },
    "PU-000025": {
        "native_word": "YÖ",
        "native_pronunciation": "(yö-)",
        "spanish": "cuello",
        "audio_file": "PU-000025_pu.mp3",
    },
}


def create_engine():
    return VisibleEngine(CONFIG)


def create_client():
    os.environ["SGODA_INSTANCE_CONFIG"] = str(CONFIG)

    spec = importlib.util.spec_from_file_location(
        "sgoda_visible_real25_app",
        VISIBLE / "app.py",
    )

    module = importlib.util.module_from_spec(spec)

    assert spec.loader is not None
    spec.loader.exec_module(module)

    module.get_engine.cache_clear()

    return TestClient(module.app)


def assert_record(row, expected):
    assert row["native_word"] == expected["native_word"]

    assert (
        row["native_pronunciation"]
        == expected["native_pronunciation"]
    )

    assert row[SPANISH_KEY] == expected["spanish"]

    assert row["audio_file"] == expected["audio_file"]


def test_real25_count_and_ids():
    engine = create_engine()

    assert engine.count() == 25

    records = list(engine.iter_records())

    assert len(records) == 25

    ids = [row["lexical_id"] for row in records]

    assert len(set(ids)) == 25
    assert ids[0] == "PU-000001"
    assert ids[-1] == "PU-000025"


def test_real25_new_linguistic_records():
    engine = create_engine()

    for lexical_id, expected in EXPECTED_NEW.items():

        row = engine.get(lexical_id)

        assert row is not None

        assert_record(row, expected)


def test_real25_all_audio_files_exist():
    engine = create_engine()

    for row in engine.iter_records():

        path = engine.audio_path(row["audio_file"])

        assert path.is_file()
        assert path.stat().st_size > 0


def test_real25_http_api_and_audio():
    client = create_client()

    health = client.get("/health")

    assert health.status_code == 200
    assert health.json()["records"] == 25

    response = client.get(
        "/api/lexicon",
        params={"limit": 100},
    )

    assert response.status_code == 200

    payload = response.json()

    assert payload["total"] == 25
    assert len(payload["items"]) == 25

    by_id = {
        row["lexical_id"]: row
        for row in payload["items"]
    }

    for lexical_id, expected in EXPECTED_NEW.items():

        assert lexical_id in by_id

        row = by_id[lexical_id]

        assert_record(row, expected)

        detail = client.get(
            f"/api/lexicon/{lexical_id}"
        )

        assert detail.status_code == 200

        assert_record(
            detail.json(),
            expected,
        )

        audio = client.get(
            "/api/audio/"
            + expected["audio_file"]
        )

        assert audio.status_code == 200
        assert len(audio.content) > 0


def test_real25_search():
    client = create_client()

    for lexical_id, expected in EXPECTED_NEW.items():

        response = client.get(
            "/api/lexicon",
            params={
                "q": expected["native_word"],
                "limit": 50,
            },
        )

        assert response.status_code == 200

        payload = response.json()

        ids = {
            item["lexical_id"]
            for item in payload["items"]
        }

        assert lexical_id in ids


def test_real25_visible_index_and_meta():
    client = create_client()

    # El HTML es una shell dinámica. No se exige que
    # contenga literalmente "Puinave".
    index = client.get("/")

    assert index.status_code == 200
    assert len(index.content) > 0
    assert "SGODA" in index.text

    # La identidad/configuración se valida mediante el
    # contrato HTTP real de la aplicación.
    health = client.get("/health")

    assert health.status_code == 200
    assert health.json()["records"] == 25