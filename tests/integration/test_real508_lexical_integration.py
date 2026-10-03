from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.integration.real508_adapter import Real508StorageConfig
from sgoda.integration.real508_lexical_integration import (
    build_real508_lexical_entry,
    load_real508_into_operational_repository,
    operational_record_from_entry,
    real508_api_contract,
)
from sgoda.operational_platform.database import OperationalRepository


ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = ROOT / "config" / "real508" / "media-storage.json"


def load_config() -> Real508StorageConfig:
    payload = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    return Real508StorageConfig.from_dict(payload)


@pytest.mark.parametrize(
    "value,expected",
    [
        (1, "000001"),
        (254, "000254"),
        (508, "000508"),
    ],
)
def test_real508_builds_canonical_entry(value, expected):
    config = load_config()

    entry = build_real508_lexical_entry(
        lexical_id=value,
        config=config,
        puinave="PRUEBA",
        spanish="PRUEBA",
    )

    record = operational_record_from_entry(entry)

    assert record["entry_id"] == expected
    assert len(record["multimedia"]) >= 1

    pu_audio = [
        item
        for item in record["multimedia"]
        if item.get("resource_type") == "audio"
        and item.get("language") == "pu"
    ]

    assert len(pu_audio) == 1
    assert "mp3" in str(pu_audio[0]).lower()


def test_real508_operational_repository_roundtrip():
    config = load_config()
    repository = OperationalRepository()

    entries = [
        build_real508_lexical_entry(
            lexical_id=value,
            config=config,
            puinave=f"PU-{value}",
            spanish=f"ES-{value}",
        )
        for value in (1, 254, 508)
    ]

    total = load_real508_into_operational_repository(
        repository=repository,
        entries=entries,
    )

    assert total == 3
    assert repository.count() == 3

    for value in ("000001", "000254", "000508"):
        response = real508_api_contract(
            repository=repository,
            entry_id=value,
        )

        assert response["status"] == "ok"
        assert response["entry_id"] == value
        assert len(response["multimedia"]) >= 1


def test_real508_api_contract_not_found():
    repository = OperationalRepository()

    response = real508_api_contract(
        repository=repository,
        entry_id="000508",
    )

    assert response == {
        "status": "not_found",
        "entry_id": "000508",
    }


def test_real508_does_not_require_postgresql_for_contract_qg():
    repository = OperationalRepository()
    assert repository.count() == 0