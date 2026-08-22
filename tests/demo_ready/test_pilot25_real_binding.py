import json
from pathlib import Path

from sgoda.demo_ready.pilot25 import EXPECTED_IDS, Pilot25Repository


def test_expected_ids():
    assert len(EXPECTED_IDS) == 25
    assert EXPECTED_IDS[0] == "PU-000001"
    assert EXPECTED_IDS[-1] == "PU-000025"


def test_real25_binding():
    root = Path(__file__).resolve().parents[2]

    records = (
        root
        / "tools"
        / "sgoda_audio_manager"
        / "v0.3.0"
        / "evidence"
        / "real-5"
        / "20260817T055528Z"
        / "validator-real-25"
        / "records.json"
    )

    summary = json.loads(
        (records.parent / "summary.json").read_text(
            encoding="utf-8-sig"
        )
    )

    assert summary["status"] == "READY"
    assert summary["summary"]["total_records"] == 25
    assert summary["summary"]["ready"] == 25

    drive = Path(summary["drive_root"])
    assert drive.is_dir()

    repository = Pilot25Repository(records, drive)

    assert len(repository.list()) == 25

    first = repository.get("PU-000001")

    assert first is not None
    assert first["puinave"] == "AMDA"
    assert first["spanish"] == "Huérfana"

    result = repository.summary()

    assert result["records"] == 25
    assert result["lexical_complete"] == 25
    assert result["audio_complete"] == 25
    assert result["ready"] is True