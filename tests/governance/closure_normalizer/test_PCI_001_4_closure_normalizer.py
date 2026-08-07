
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.closure_normalizer import (
    normalize_all,
    normalize_descriptor,
)


def repository(tmp_path: Path) -> Path:
    for value in ("config/governance", "src/example", "tests/example", "docs/example"):
        (tmp_path / value).mkdir(parents=True, exist_ok=True)

    descriptor = {
        "increment_code": "PCI-001.3",
        "name": "Registry Determinizer",
        "version": "1.0.0",
        "status": "implemented_tested_and_candidate_for_closure",
        "source": ["src/example"],
        "tests": ["tests/example"],
        "documentation": ["docs/example"],
        "dependencies": ["PCI-001.2"],
    }
    (
        tmp_path / "config/governance/PCI-001.3-component.json"
    ).write_text(json.dumps(descriptor), encoding="utf-8")
    return tmp_path


def test_creates_release_and_manifest(tmp_path: Path) -> None:
    root = repository(tmp_path)
    result = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    assert result.approved
    assert (root / result.release).is_dir()
    assert (root / result.manifest).is_file()


def test_descriptor_is_closed(tmp_path: Path) -> None:
    root = repository(tmp_path)
    normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    payload = json.loads(
        (
            root / "config/governance/PCI-001.3-component.json"
        ).read_text(encoding="utf-8")
    )
    assert payload["status"] == "institutionally_closed"
    assert payload["completion_percent"] == 100.0
    assert payload["institutionally_closed"] is True


def test_manifest_is_canonical(tmp_path: Path) -> None:
    root = repository(tmp_path)
    result = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    manifest = json.loads(
        (root / result.manifest).read_text(encoding="utf-8")
    )
    assert manifest["increment_code"] == "PCI-001.3"
    assert manifest["version"] == "1.0.0"
    assert manifest["status"] == "institutionally_closed"


def test_second_run_is_idempotent(tmp_path: Path) -> None:
    root = repository(tmp_path)
    first = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    second = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    assert first.changed is True
    assert second.changed is False


def test_normalize_all_generates_evidence(tmp_path: Path) -> None:
    root = repository(tmp_path)
    evidence = tmp_path / "artifacts/evidence.json"
    result = normalize_all(
        root,
        backup_dir=tmp_path / "backup",
        evidence_json=evidence,
        include_codes=["PCI-001.3"],
    )
    assert result["approved"]
    assert result["components_processed"] == 1
    assert evidence.is_file()


def test_backup_is_created(tmp_path: Path) -> None:
    root = repository(tmp_path)
    backup = tmp_path / "backup"
    normalize_all(
        root,
        backup_dir=backup,
        evidence_json=tmp_path / "evidence.json",
        include_codes=["PCI-001.3"],
    )
    assert (
        backup / "config/governance/PCI-001.3-component.json"
    ).is_file()


def test_only_selected_codes_are_processed(tmp_path: Path) -> None:
    root = repository(tmp_path)
    result = normalize_all(
        root,
        backup_dir=tmp_path / "backup",
        evidence_json=tmp_path / "evidence.json",
        include_codes=["PCI-001.3"],
    )
    assert [item["code"] for item in result["results"]] == ["PCI-001.3"]


def test_existing_release_is_reused(tmp_path: Path) -> None:
    root = repository(tmp_path)
    existing = root / "releases/PCI-001.3-v1.0.0"
    existing.mkdir(parents=True)
    result = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    assert root / result.release == existing


def test_invalid_descriptor_without_code_fails(tmp_path: Path) -> None:
    root = repository(tmp_path)
    path = root / "config/governance/BAD-component.json"
    path.write_text('{"version":"1.0.0"}', encoding="utf-8")
    try:
        normalize_descriptor(root, path)
    except ValueError:
        pass
    else:
        raise AssertionError("Se esperaba ValueError")
