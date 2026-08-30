from sgoda.demo_ready.postgres_pilot25 import (
    EXPECTED_IDS,
    PostgresPilot25Repository,
)


def test_postgres_expected_ids():
    assert len(EXPECTED_IDS) == 25
    assert EXPECTED_IDS[0] == "PU-000001"
    assert EXPECTED_IDS[-1] == "PU-000025"


def test_postgres_normalize():
    row = (
        "PU-000001",
        "AMDA",
        "Huérfana",
        "PU-000001_pu.mp3",
        {
            "real25": {
                "position": 1,
                "batch_id": "REAL25",
                "native_pronunciation": "(´amda)",
                "wav_exists": True,
                "mp3_exists": True,
            }
        },
    )

    record = PostgresPilot25Repository._normalize(row)

    assert record["lexical_id"] == "PU-000001"
    assert record["puinave"] == "AMDA"
    assert record["spanish"] == "Huérfana"
    assert record["audio_filename"] == "PU-000001_pu.mp3"
    assert record["wav_exists_certified"] is True
    assert record["mp3_exists_certified"] is True
