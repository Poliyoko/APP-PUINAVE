from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.adaptive_policy import (
    canonical_increment_code,
    evaluate_adaptive_policy,
    increment_family,
    resolve_evidence_directory,
    resolve_release_directory,
)


def _file(path: Path, text: str = "ok") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def test_SGD_114D_canonicalizes_version_suffix() -> None:
    assert canonical_increment_code(
        "SPT-011A-v1.0.2"
    ) == "SPT-011A"


def test_SGD_114D_builds_increment_family() -> None:
    assert increment_family("SPT-011A") == (
        "SPT-011A",
        "SPT-011",
    )


def test_SGD_114D_resolves_canonical_evidence(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011A"
        / "evidence"
        / "result.json"
    )

    result = resolve_evidence_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert result.strategy == "canonical"


def test_SGD_114D_resolves_parent_evidence(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011"
        / "evidence"
        / "result.json"
    )

    result = resolve_evidence_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert "SPT-011" in str(result.path)


def test_SGD_114D_rejects_empty_evidence_directory(
    tmp_path: Path,
) -> None:
    (
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011A"
        / "evidence"
    ).mkdir(parents=True)

    result = resolve_evidence_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is False


def test_SGD_114D_resolves_versioned_release(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert "SPT-011A-v1.0.2" in str(result.path)


def test_SGD_114D_resolves_parent_release(
    tmp_path: Path,
) -> None:
    _file(
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
    assert "SPT-011-v1.0.0" in str(result.path)


def test_SGD_114D_rejects_empty_release(
    tmp_path: Path,
) -> None:
    (
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
    ).mkdir(parents=True)

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is False


def test_SGD_114D_approves_complete_increment(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011"
        / "evidence"
        / "evidence.json"
    )
    _file(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    result = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )

    assert result.approved is True
    assert result.exit_code == 0


def test_SGD_114D_blocks_missing_release(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011"
        / "evidence"
        / "evidence.json"
    )

    result = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )

    assert result.approved is False
    assert result.exit_code == 2


def test_SGD_114D_blocks_missing_evidence(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    result = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )

    assert result.approved is False


def test_SGD_114D_is_deterministic(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011A"
        / "evidence"
        / "evidence.json"
    )
    _file(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    first = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )
    second = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )

    assert first == second