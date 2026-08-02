"""Pruebas de SGD-114D v1.0.1."""

from __future__ import annotations

from pathlib import Path

from sgoda.governance.adaptive_policy_resolver import (
    canonical_increment_code,
    increment_family,
    parent_increment_code,
    resolve_release_directory,
)


def _write(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("ok", encoding="utf-8")


def test_SGD_114D_v101_canonicalizes_corrective_code() -> None:
    assert canonical_increment_code(
        "SPT-011A-v1.0.2"
    ) == "SPT-011A"


def test_SGD_114D_v101_resolves_parent_code() -> None:
    assert parent_increment_code("SPT-011A") == "SPT-011"


def test_SGD_114D_v101_family_order_is_canonical_first() -> None:
    assert increment_family("SPT-011A") == (
        "SPT-011A",
        "SPT-011",
    )


def test_SGD_114D_v101_prefers_corrective_release(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path
        / "releases"
        / "SPT-011-v1.0.0"
        / "manifest.json"
    )
    _write(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.1"
        / "manifest.json"
    )

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert result.strategy == "canonical_versioned"
    assert result.path is not None
    assert result.path.name == "SPT-011A-v1.0.1"


def test_SGD_114D_v101_accepts_populated_parent_release(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path
        / "releases"
        / "SPT-011-v1.0.0"
        / "manifest.json"
    )

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert result.strategy == "parent_versioned"


def test_SGD_114D_v101_rejects_empty_parent_release(
    tmp_path: Path,
) -> None:
    (
        tmp_path
        / "releases"
        / "SPT-011-v1.0.0"
    ).mkdir(parents=True)

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is False


def test_SGD_114D_v101_uses_latest_version(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.1"
        / "manifest.json"
    )
    _write(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.path is not None
    assert result.path.name == "SPT-011A-v1.0.2"


def test_SGD_114D_v101_is_deterministic(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.1"
        / "manifest.json"
    )

    first = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )
    second = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert first == second