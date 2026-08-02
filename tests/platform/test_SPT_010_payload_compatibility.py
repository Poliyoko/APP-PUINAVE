"""Pruebas del correctivo SPT-010 v1.0.2."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.platform.cli import _load_payload


def test_SPT_010_loads_standard_json_payload() -> None:
    assert _load_payload(
        '{"message":"Quiero aprender"}'
    ) == {
        "message": "Quiero aprender",
    }


def test_SPT_010_repairs_single_quoted_payload() -> None:
    assert _load_payload(
        "{'message':'Quiero aprender'}"
    ) == {
        "message": "Quiero aprender",
    }


def test_SPT_010_repairs_escaped_quotes() -> None:
    assert _load_payload(
        '{\\"message\\":\\"AMDA\\"}'
    ) == {
        "message": "AMDA",
    }


def test_SPT_010_loads_payload_file(
    tmp_path: Path,
) -> None:
    path = tmp_path / "payload.json"
    path.write_text(
        '{"message":"AMDA"}',
        encoding="utf-8",
    )

    assert _load_payload(
        "{}",
        str(path),
    ) == {
        "message": "AMDA",
    }


def test_SPT_010_reads_utf8_bom_payload_file(
    tmp_path: Path,
) -> None:
    path = tmp_path / "payload-bom.json"
    path.write_text(
        '{"message":"Puinave"}',
        encoding="utf-8-sig",
    )

    assert _load_payload(
        "{}",
        str(path),
    ) == {
        "message": "Puinave",
    }


def test_SPT_010_payload_file_has_priority(
    tmp_path: Path,
) -> None:
    path = tmp_path / "payload.json"
    path.write_text(
        '{"message":"Archivo"}',
        encoding="utf-8",
    )

    assert _load_payload(
        '{"message":"Texto"}',
        str(path),
    ) == {
        "message": "Archivo",
    }


def test_SPT_010_rejects_non_object_payload() -> None:
    with pytest.raises(
        ValueError,
        match="objeto JSON",
    ):
        _load_payload("[1, 2, 3]")


def test_SPT_010_rejects_invalid_payload() -> None:
    with pytest.raises(
        ValueError,
        match="JSON válido",
    ):
        _load_payload("{invalid}")


def test_SPT_010_rejects_missing_payload_file(
    tmp_path: Path,
) -> None:
    with pytest.raises(
        ValueError,
        match="No se encontró",
    ):
        _load_payload(
            "{}",
            str(tmp_path / "missing.json"),
        )


def test_SPT_010_empty_payload_defaults_to_object() -> None:
    assert _load_payload("") == {}


def test_SPT_010_payload_is_deterministic() -> None:
    raw = '{"message":"AMDA","language":"pu"}'

    assert _load_payload(raw) == _load_payload(raw)


def test_SPT_010_payload_preserves_unicode() -> None:
    payload = {
        "message": "Quiero aprender Puinave",
        "language": "pu",
    }
    raw = json.dumps(
        payload,
        ensure_ascii=False,
    )

    assert _load_payload(raw) == payload