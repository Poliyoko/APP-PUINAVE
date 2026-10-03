import json
from pathlib import Path

import pytest

from sgoda.integration.real508_adapter import (
    REAL508_COUNT,
    Real508StorageConfig,
    build_media_manifest,
    canonical_real508_id,
    mp3_reference,
    multimedia_resources,
)


def test_real508_count():
    assert REAL508_COUNT == 508


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (1, "000001"),
        ("1", "000001"),
        ("000001", "000001"),
        (508, "000508"),
        ("000508", "000508"),
    ],
)
def test_canonical_id(raw, expected):
    assert canonical_real508_id(raw) == expected


@pytest.mark.parametrize("raw", [0, 509, "", "ABC"])
def test_invalid_id(raw):
    with pytest.raises(ValueError):
        canonical_real508_id(raw)


def test_mp3_reference_local():
    config = Real508StorageConfig(
        wav_root=Path("WAV"),
        mp3_root=Path("MP3"),
    )

    assert mp3_reference("000047", config).endswith("MP3/000047.mp3")


def test_mp3_reference_public():
    config = Real508StorageConfig(
        wav_root=Path("WAV"),
        mp3_root=Path("MP3"),
        public_mp3_base_url="https://media.example/puinave",
    )

    assert (
        mp3_reference(47, config)
        == "https://media.example/puinave/000047.mp3"
    )


def test_multimedia_resource_uses_existing_contract():
    config = Real508StorageConfig(
        wav_root=Path("WAV"),
        mp3_root=Path("MP3"),
    )

    resources = multimedia_resources("000047", config)

    assert len(resources) == 1
    assert resources[0].resource_type == "audio"
    assert resources[0].language == "pu"
    assert resources[0].path.endswith("000047.mp3")


def test_manifest_preserves_ids():
    config = Real508StorageConfig(
        wav_root=Path("WAV"),
        mp3_root=Path("MP3"),
    )

    manifest = build_media_manifest([1, 47, 508], config)

    assert [item["entry_id"] for item in manifest] == [
        "000001",
        "000047",
        "000508",
    ]

    assert all(item["media_type"] == "audio_puinave" for item in manifest)
    assert all(item["language"] == "pu" for item in manifest)


def test_repository_configuration_exists():
    repo = Path(__file__).resolve().parents[2]
    target = repo / "config" / "real508" / "media-storage.json"

    payload = json.loads(target.read_text(encoding="utf-8"))

    assert payload["dataset"] == "REAL-508"
    assert payload["native_language"] == "pu"
    assert payload["git_store_mass_media"] is False