
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.release_management.resolver import (
    canonical_release_name,
    collapse_duplicate_revision,
    parse_release_name,
)
from sgoda.governance.release_management.service import (
    InstitutionalReleaseManager,
)


def test_canonical_release_name() -> None:
    assert (
        canonical_release_name(
            "SGD-114E",
            "2.0.0-R2.1",
        )
        == "SGD-114E-v2.0.0-R2.1"
    )


def test_parse_release_name() -> None:
    result = parse_release_name(
        "SGD-114E-v2.0.0-R2.1"
    )

    assert result.increment_code == "SGD-114E"
    assert result.version == "2.0.0-R2.1"


def test_collapse_duplicate_revision() -> None:
    assert (
        collapse_duplicate_revision(
            "SGD-114E-v2.0.0-R2.1.1"
        )
        == "SGD-114E-v2.0.0-R2.1"
    )


def test_normalize_release_transaction(
    tmp_path: Path,
) -> None:
    source = (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1.1"
    )
    source.mkdir(parents=True)
    (source / "manifest.json").write_text(
        json.dumps(
            {
                "release_name": (
                    "SGD-114E-v2.0.0-R2.1.1"
                )
            }
        ),
        encoding="utf-8",
    )

    result = InstitutionalReleaseManager(
        tmp_path
    ).normalize(
        "SGD-114E-v2.0.0-R2.1.1"
    )

    assert result.approved is True
    assert (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1"
    ).exists()
    assert not source.exists()


def test_reference_update_skips_empty_files(
    tmp_path: Path,
) -> None:
    source = (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1.1"
    )
    source.mkdir(parents=True)
    (source / "manifest.json").write_text(
        "{}",
        encoding="utf-8",
    )

    docs = tmp_path / "docs"
    docs.mkdir()
    (docs / "empty.md").write_text(
        "",
        encoding="utf-8",
    )
    (docs / "reference.md").write_text(
        "SGD-114E-v2.0.0-R2.1.1",
        encoding="utf-8",
    )

    result = InstitutionalReleaseManager(
        tmp_path
    ).normalize(
        "SGD-114E-v2.0.0-R2.1.1"
    )

    assert result.approved is True
    assert (
        docs / "reference.md"
    ).read_text(encoding="utf-8") == (
        "SGD-114E-v2.0.0-R2.1"
    )


def test_validate_detects_manifest_mismatch(
    tmp_path: Path,
) -> None:
    release = (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1"
    )
    release.mkdir(parents=True)
    (release / "manifest.json").write_text(
        json.dumps(
            {
                "release_name": (
                    "SGD-114E-v2.0.0-R2.1.1"
                )
            }
        ),
        encoding="utf-8",
    )

    result = InstitutionalReleaseManager(
        tmp_path
    ).validate()

    assert result["approved"] is False
    assert result["exit_code"] == 2


def test_validate_approved_repository(
    tmp_path: Path,
) -> None:
    release = (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1"
    )
    release.mkdir(parents=True)
    (release / "manifest.json").write_text(
        json.dumps(
            {
                "release_name": (
                    "SGD-114E-v2.0.0-R2.1"
                )
            }
        ),
        encoding="utf-8",
    )

    result = InstitutionalReleaseManager(
        tmp_path
    ).validate()

    assert result["approved"] is True
    assert result["exit_code"] == 0
