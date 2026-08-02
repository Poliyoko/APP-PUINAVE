"""Pruebas SGD-115A."""

from __future__ import annotations

from sgoda.documentation.canonical_component_resolver import (
    canonical_code,
    consolidate_components,
    record_version,
    version_tuple,
)


def test_SGD_115A_reads_explicit_canonical_code() -> None:
    record = {
        "increment_code": "SGD-114D-v1.0.1",
        "canonical_code": "SGD-114D",
        "version": "1.0.1",
    }

    assert canonical_code(record) == "SGD-114D"


def test_SGD_115A_derives_canonical_code() -> None:
    record = {
        "increment_code": "SGD-114D-v1.0.1",
    }

    assert canonical_code(record) == "SGD-114D"


def test_SGD_115A_preserves_normal_code() -> None:
    assert canonical_code(
        {"increment_code": "SPT-011A"}
    ) == "SPT-011A"


def test_SGD_115A_reads_explicit_version() -> None:
    assert record_version(
        {
            "increment_code": "SGD-114D-v1.0.1",
            "version": "1.0.1",
        }
    ) == "1.0.1"


def test_SGD_115A_derives_version_from_code() -> None:
    assert record_version(
        {"increment_code": "SGD-114D-v1.0.1"}
    ) == "1.0.1"


def test_SGD_115A_orders_semantic_versions() -> None:
    assert version_tuple("1.10.0") > version_tuple("1.2.9")


def test_SGD_115A_consolidates_versions() -> None:
    records = [
        {
            "increment_code": "SGD-114D",
            "version": "1.0.0",
        },
        {
            "increment_code": "SGD-114D-v1.0.1",
            "canonical_code": "SGD-114D",
            "version": "1.0.1",
        },
    ]

    consolidated = consolidate_components(records)

    assert len(consolidated) == 1
    assert consolidated[0].canonical_code == "SGD-114D"
    assert (
        consolidated[0].active_record["active_version"]
        == "1.0.1"
    )
    assert len(consolidated[0].history) == 1


def test_SGD_115A_keeps_different_components() -> None:
    records = [
        {
            "increment_code": "SGD-114D",
            "version": "1.0.1",
        },
        {
            "increment_code": "SGD-115",
            "version": "1.0.0",
        },
    ]

    assert len(consolidate_components(records)) == 2


def test_SGD_115A_is_deterministic() -> None:
    records = [
        {
            "increment_code": "SGD-114D-v1.0.1",
            "canonical_code": "SGD-114D",
            "version": "1.0.1",
        },
        {
            "increment_code": "SGD-114D",
            "version": "1.0.0",
        },
    ]

    assert (
        consolidate_components(records)
        == consolidate_components(records)
    )


def test_SGD_115A_history_preserves_version() -> None:
    records = [
        {
            "increment_code": "SGD-114D",
            "version": "1.0.0",
        },
        {
            "increment_code": "SGD-114D-v1.0.1",
            "canonical_code": "SGD-114D",
            "version": "1.0.1",
        },
    ]

    consolidated = consolidate_components(records)

    assert (
        consolidated[0].history[0]["historical_version"]
        == "1.0.0"
    )