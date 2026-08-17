from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve()

VISIBLE_ROOT = HERE.parents[1]

sys.path.insert(
    0,
    str(VISIBLE_ROOT),
)

from engine import VisibleEngine


REAL_CONFIG = (
    VISIBLE_ROOT
    / "config"
    / "instance.puinave.pilot20.json"
)


def create_scale_instance(
    tmp_path: Path,
    count: int,
) -> Path:

    csv_path = (
        tmp_path
        / f"scale-{count}.csv"
    )

    fieldnames = [
        "ID",
        "NATIVE",
        "PRON",
        "AUX",
    ]

    with csv_path.open(
        "w",
        encoding="utf-8",
        newline="",
    ) as stream:

        writer = csv.DictWriter(
            stream,
            fieldnames=fieldnames,
        )

        writer.writeheader()

        for number in range(
            1,
            count + 1,
        ):

            writer.writerow(
                {
                    "ID": str(number),

                    "NATIVE":
                        f"WORD-{number:06d}",

                    "PRON":
                        f"(pron-{number:06d})",

                    "AUX":
                        f"Meaning {number}",
                }
            )

    config = {
        "schema_version": "2.0.0",

        "instance": {
            "instance_id":
                f"TEST-{count}",

            "lexical_prefix": "XX",

            "id_width": 6,

            "native_language": {
                "name": "Test Native",
                "code": "xx",
            },

            "auxiliary_languages": [
                {
                    "name": "Test Auxiliary",
                    "code": "zz",
                    "role": "translation",
                }
            ],
        },

        "input": {
            "format": "csv",

            "path": str(csv_path),

            "columns": {
                "id": "ID",
                "native_word": "NATIVE",
                "native_pronunciation":
                    "PRON",
                "primary_translation":
                    "AUX",
            },
        },

        "storage": {
            "type": "local",

            "root": str(tmp_path),

            "folders": {
                "mp3": "MP3",
            },
        },

        "naming": {
            "audio_pattern":
                "{prefix}-{id}_{language}.mp3",
        },

        "visible": {
            "default_page_size": 50,
            "max_page_size": 200,
        },
    }

    config_path = (
        tmp_path
        / f"instance-{count}.json"
    )

    config_path.write_text(
        json.dumps(
            config,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    return config_path


def test_real_pilot20_regression():

    engine = VisibleEngine(
        REAL_CONFIG
    )

    assert engine.count() == 20

    page = engine.page(
        offset=0,
        limit=50,
    )

    assert page.total == 20
    assert len(page.items) == 20

    amda = engine.get(
        "PU-000001"
    )

    assert amda is not None
    assert amda["native_word"] == "AMDA"
    assert (
        amda["primary_translation"]
        == "Huérfana"
    )

    au16 = engine.get(
        "PU-000016"
    )

    au17 = engine.get(
        "PU-000017"
    )

    assert au16 is not None
    assert au17 is not None

    assert au16["native_word"] == "AU"
    assert au17["native_word"] == "AU"

    assert (
        au16["primary_translation"]
        == "Bachaco"
    )

    assert (
        au17["primary_translation"]
        == "Cantar"
    )

    assert (
        au16["native_pronunciation"]
        != au17["native_pronunciation"]
    )


@pytest.mark.parametrize(
    "count",
    [
        1003,
        1501,
        5000,
    ],
)
def test_scale_counts(
    tmp_path: Path,
    count: int,
):

    config = create_scale_instance(
        tmp_path,
        count,
    )

    engine = VisibleEngine(
        config
    )

    assert engine.count() == count

    first_page = engine.page(
        offset=0,
        limit=50,
    )

    assert first_page.total == count
    assert len(first_page.items) == 50

    assert (
        first_page.items[0][
            "lexical_id"
        ]
        == "XX-000001"
    )


def test_1003_tail(
    tmp_path: Path,
):

    config = create_scale_instance(
        tmp_path,
        1003,
    )

    engine = VisibleEngine(
        config
    )

    page = engine.page(
        offset=1000,
        limit=50,
    )

    assert page.total == 1003
    assert len(page.items) == 3

    assert (
        page.items[-1][
            "lexical_id"
        ]
        == "XX-001003"
    )


def test_1500_plus(
    tmp_path: Path,
):

    config = create_scale_instance(
        tmp_path,
        1501,
    )

    engine = VisibleEngine(
        config
    )

    record = engine.get(
        "XX-001501"
    )

    assert record is not None

    assert (
        record["native_word"]
        == "WORD-001501"
    )


def test_5000_stress_pagination(
    tmp_path: Path,
):

    config = create_scale_instance(
        tmp_path,
        5000,
    )

    engine = VisibleEngine(
        config
    )

    page = engine.page(
        offset=0,
        limit=5000,
    )

    assert page.total == 5000

    # El motor conoce 5000 registros,
    # pero nunca entrega una pagina
    # superior al limite configurado.
    assert page.limit == 200
    assert len(page.items) == 200

    tail = engine.page(
        offset=4990,
        limit=50,
    )

    assert tail.total == 5000
    assert len(tail.items) == 10

    assert (
        tail.items[-1][
            "lexical_id"
        ]
        == "XX-005000"
    )


def test_search_at_scale(
    tmp_path: Path,
):

    config = create_scale_instance(
        tmp_path,
        5000,
    )

    engine = VisibleEngine(
        config
    )

    page = engine.page(
        query="WORD-004999",
        offset=0,
        limit=50,
    )

    assert page.total == 1
    assert len(page.items) == 1

    assert (
        page.items[0][
            "lexical_id"
        ]
        == "XX-004999"
    )


def test_engine_is_not_puinave_coded():

    source = (
        VISIBLE_ROOT
        / "engine.py"
    ).read_text(
        encoding="utf-8"
    )

    assert "Puinave" not in source
    assert "SGODA-PUINAVE" not in source
    assert "PU-000001" not in source


def test_zero_auxiliary_languages(
    tmp_path: Path,
):

    config_path = create_scale_instance(
        tmp_path,
        20,
    )

    config = json.loads(
        config_path.read_text(
            encoding="utf-8"
        )
    )

    config["instance"][
        "auxiliary_languages"
    ] = []

    config_path.write_text(
        json.dumps(
            config,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    engine = VisibleEngine(
        config_path
    )

    assert engine.auxiliary_languages == []
    assert (
        engine.metadata()[
            "auxiliary_language_count"
        ]
        == 0
    )


def test_multiple_auxiliary_languages(
    tmp_path: Path,
):

    config_path = create_scale_instance(
        tmp_path,
        20,
    )

    config = json.loads(
        config_path.read_text(
            encoding="utf-8"
        )
    )

    config["instance"][
        "auxiliary_languages"
    ] = [
        {
            "name": "Aux One",
            "code": "a1",
        },
        {
            "name": "Aux Two",
            "code": "a2",
        },
        {
            "name": "Aux Three",
            "code": "a3",
        },
        {
            "name": "Aux Four",
            "code": "a4",
        },
    ]

    config_path.write_text(
        json.dumps(
            config,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    engine = VisibleEngine(
        config_path
    )

    assert len(
        engine.auxiliary_languages
    ) == 4

    assert (
        engine.metadata()[
            "auxiliary_language_count"
        ]
        == 4
    )


def test_no_fixed_record_cardinality_in_engine():

    source = (
        VISIBLE_ROOT
        / "engine.py"
    ).read_text(
        encoding="utf-8"
    )

    forbidden = [
        "1003",
        "1500",
        "1501",
        "5000",
        "Pilot-20",
        "pilot20",
    ]

    for token in forbidden:
        assert token not in source
