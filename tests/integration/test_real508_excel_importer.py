from __future__ import annotations

import json
from pathlib import Path
from sgoda.integration.real508_adapter import Real508StorageConfig
from sgoda.integration.real508_excel_importer import (
    iter_certified_real508_entries,
    load_certified_real508_excel,
)


REPO = Path(__file__).resolve().parents[2]

EXCEL = (
    REPO
    / "Audacity"
    / "audacity 523 palabras"
    / "Repositorio lexico base 508.xlsx"
)

CONFIG = (
    REPO
    / "config"
    / "real508"
    / "media-storage.json"
)


def storage_config() -> Real508StorageConfig:
    payload = json.loads(
        CONFIG.read_text(encoding="utf-8")
    )
    return Real508StorageConfig.from_dict(payload)


def test_certified_excel_contains_exactly_508_entries():
    entries = tuple(
        iter_certified_real508_entries(
            EXCEL,
            storage_config(),
        )
    )

    assert len(entries) == 508
    assert entries[0].entry_id == "000001"
    assert entries[-1].entry_id == "000508"


def test_first_certified_record_preserves_exact_text():
    entries = tuple(
        iter_certified_real508_entries(
            EXCEL,
            storage_config(),
        )
    )

    first = entries[0]

    assert first.entry_id == "000001"
    assert first.puinave == "A"
    assert first.spanish == "Mí"

    assert first.metadata["escritura_puinave"] == "(a)"
    assert first.metadata["lote_audio_puinave"] == "1"


def test_second_record_preserves_leading_space_exactly():
    entries = tuple(
        iter_certified_real508_entries(
            EXCEL,
            storage_config(),
        )
    )

    second = entries[1]

    assert second.entry_id == "000002"
    assert second.puinave == " AYOT"
    assert second.spanish == "Mi  perro"
    assert second.metadata["escritura_puinave"] == "ayot"


def test_last_certified_record_preserves_exact_text():
    entries = tuple(
        iter_certified_real508_entries(
            EXCEL,
            storage_config(),
        )
    )

    last = entries[-1]

    assert last.entry_id == "000508"
    assert last.puinave == "IWINSOGPÖNJIN"
    assert last.spanish == "Mezquinoso-a"
    assert last.metadata["escritura_puinave"] == " (ibìsokpöngìn) "
    assert last.metadata["lote_audio_puinave"] == "23"


def test_all_ids_are_unique_and_sequential():
    entries = tuple(
        iter_certified_real508_entries(
            EXCEL,
            storage_config(),
        )
    )

    ids = [entry.entry_id for entry in entries]

    assert len(ids) == 508
    assert len(set(ids)) == 508

    assert ids == [
        f"{number:06d}"
        for number in range(1, 509)
    ]


def test_metadata_preserves_source_policy():
    entries = tuple(
        iter_certified_real508_entries(
            EXCEL,
            storage_config(),
        )
    )

    for entry in entries:
        metadata = entry.metadata

        assert metadata["fuente_lexica"] == "EXCEL_CERTIFICADO"
        assert metadata["hoja_fuente"] == "hoja1"
        assert metadata["grafia_puinave_autoritativa"] is True
        assert metadata["preservar_texto_exacto"] is True
        assert metadata["normalizar_puinave"] is False
        assert metadata["corregir_automaticamente_puinave"] is False
        assert metadata["reinterpretar_puinave"] is False


def test_operational_repository_loads_508_real_entries():
    repository = load_certified_real508_excel(
        EXCEL,
        storage_config(),
    )

    assert repository.count() == 508

    first = repository.get_entry("000001")
    last = repository.get_entry("000508")

    assert first is not None
    assert last is not None

    assert first["puinave"] == "A"
    assert first["spanish"] == "Mí"

    assert last["puinave"] == "IWINSOGPÖNJIN"
    assert last["spanish"] == "Mezquinoso-a"


def test_real508_multimedia_is_attached_without_copying_audio():
    repository = load_certified_real508_excel(
        EXCEL,
        storage_config(),
    )

    first_media = repository.media_for("000001")
    last_media = repository.media_for("000508")

    assert len(first_media) >= 1
    assert len(last_media) >= 1

    assert first_media[0]["resource_type"] == "audio"
    assert first_media[0]["language"] == "pu"

    assert last_media[0]["resource_type"] == "audio"
    assert last_media[0]["language"] == "pu"

    assert "000001.mp3" in first_media[0]["path"]
    assert "000508.mp3" in last_media[0]["path"]
