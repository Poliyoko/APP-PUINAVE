
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.release_management.service import (
    InstitutionalReleaseManager,
)


def test_migrate_missing_manifest(tmp_path: Path) -> None:
    release = tmp_path / "releases" / "SPT-001-v1.0.0"
    release.mkdir(parents=True)
    (release / "file.txt").write_text("x", encoding="utf-8")

    migrated = InstitutionalReleaseManager(
        tmp_path
    ).migrate_missing_manifests()

    assert len(migrated) == 1
    manifest = release / "manifest.json"
    assert manifest.exists()

    payload = json.loads(manifest.read_text(encoding="utf-8"))
    assert payload["legacy"] is True
    assert payload["release_name"] == "SPT-001-v1.0.0"


def test_migration_preserves_existing_manifest(
    tmp_path: Path,
) -> None:
    release = tmp_path / "releases" / "SPT-001-v1.0.0"
    release.mkdir(parents=True)
    manifest = release / "manifest.json"
    manifest.write_text(
        json.dumps({"release_name": "SPT-001-v1.0.0"}),
        encoding="utf-8",
    )

    migrated = InstitutionalReleaseManager(
        tmp_path
    ).migrate_missing_manifests()

    assert migrated == ()
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    assert payload == {"release_name": "SPT-001-v1.0.0"}


def test_close_migrates_and_validates(tmp_path: Path) -> None:
    release = tmp_path / "releases" / "SPT-001-v1.0.0"
    release.mkdir(parents=True)

    manager = InstitutionalReleaseManager(tmp_path)
    manager.migrate_missing_manifests()
    result = manager.validate()

    assert result["approved"] is True
    assert result["findings"] == []


def test_unknown_legacy_release_gets_manifest(
    tmp_path: Path,
) -> None:
    release = tmp_path / "releases" / "legacy-folder"
    release.mkdir(parents=True)

    InstitutionalReleaseManager(
        tmp_path
    ).migrate_missing_manifests()

    payload = json.loads(
        (release / "manifest.json").read_text(encoding="utf-8")
    )

    assert payload["version"] == "legacy"
    assert payload["release_name"] == "legacy-folder"
