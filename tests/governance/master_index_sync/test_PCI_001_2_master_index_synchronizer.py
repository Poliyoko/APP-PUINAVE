
from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.governance.master_index_sync import (
    END_MARKER,
    START_MARKER,
    build_managed_block,
    replace_managed_block,
    scan_components,
    synchronize,
)


def repository(tmp_path: Path) -> Path:
    for path in (
        "config/example",
        "docs",
        "src/example",
        "tests/example",
        "releases/SPT-999-v1.0.0",
    ):
        (tmp_path / path).mkdir(
            parents=True,
            exist_ok=True,
        )

    (tmp_path / "src/example/__init__.py").write_text(
        "",
        encoding="utf-8",
    )
    (tmp_path / "tests/example/test_example.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )
    (tmp_path / "docs/example.md").write_text(
        "# SPT-999\n",
        encoding="utf-8",
    )
    (tmp_path / "docs/00_INDICE_MAESTRO.md").write_text(
        "# Índice Maestro\n\nContenido manual.\n",
        encoding="utf-8",
    )
    descriptor = {
        "increment_code": "SPT-999",
        "name": "Componente ejemplo",
        "version": "1.0.0",
        "status": "closed",
        "source": ["src/example"],
        "tests": ["tests/example"],
        "documentation": ["docs/example.md"],
    }
    (tmp_path / "config/example/SPT-999-component.json").write_text(
        json.dumps(descriptor),
        encoding="utf-8",
    )
    (tmp_path / "config/example/SPT-999-policy.json").write_text(
        '{"component":"SPT-999"}',
        encoding="utf-8",
    )
    (tmp_path / "releases/SPT-999-v1.0.0/manifest.json").write_text(
        '{"increment_code":"SPT-999"}',
        encoding="utf-8",
    )
    return tmp_path


def test_scan_uses_only_component_descriptors(
    tmp_path: Path,
) -> None:
    components = scan_components(repository(tmp_path))

    assert len(components) == 1
    assert components[0].code == "SPT-999"


def test_block_contains_structural_code(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    block = build_managed_block(
        root,
        scan_components(root),
    )

    assert "`SPT-999`" in block
    assert START_MARKER in block
    assert END_MARKER in block


def test_manual_content_is_preserved(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    index = root / "docs/00_INDICE_MAESTRO.md"
    original = index.read_text(encoding="utf-8")

    result = synchronize(
        root,
        apply=True,
        backup_dir=tmp_path / "backup",
        report_path=tmp_path / "report.json",
        preview_path=tmp_path / "preview.md",
    )

    updated = index.read_text(encoding="utf-8")

    assert result["approved"] is True
    assert original.strip() in updated
    assert "`SPT-999`" in updated


def test_backup_is_created(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    backup = tmp_path / "backup"

    synchronize(
        root,
        apply=True,
        backup_dir=backup,
        report_path=tmp_path / "report.json",
        preview_path=tmp_path / "preview.md",
    )

    assert (backup / "00_INDICE_MAESTRO.md.bak").is_file()


def test_preview_does_not_modify_index(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    index = root / "docs/00_INDICE_MAESTRO.md"
    before = index.read_text(encoding="utf-8")

    synchronize(
        root,
        apply=False,
        backup_dir=tmp_path / "backup",
        report_path=tmp_path / "report.json",
        preview_path=tmp_path / "preview.md",
    )

    assert index.read_text(encoding="utf-8") == before


def test_second_apply_is_idempotent(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    kwargs = {
        "root_value": root,
        "apply": True,
        "backup_dir": tmp_path / "backup",
        "report_path": tmp_path / "report.json",
        "preview_path": tmp_path / "preview.md",
    }

    synchronize(**kwargs)
    first = (
        root / "docs/00_INDICE_MAESTRO.md"
    ).read_text(encoding="utf-8")
    synchronize(**kwargs)
    second = (
        root / "docs/00_INDICE_MAESTRO.md"
    ).read_text(encoding="utf-8")

    # Generated timestamp changes; managed structure and codes remain unique.
    assert second.count(START_MARKER) == 1
    assert second.count(END_MARKER) == 1
    assert second.count("`SPT-999`") == 1
    assert "# Índice Maestro" in first
    assert "# Índice Maestro" in second


def test_unbalanced_markers_are_rejected() -> None:
    with pytest.raises(ValueError):
        replace_managed_block(
            "Header\n" + START_MARKER,
            "block",
        )


def test_multiple_managed_blocks_are_rejected() -> None:
    text = (
        START_MARKER
        + "\n"
        + END_MARKER
        + "\n"
        + START_MARKER
        + "\n"
        + END_MARKER
    )
    with pytest.raises(ValueError):
        replace_managed_block(text, "block")


def test_historical_increment_is_separated(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    descriptor = {
        "increment_code": "SGD-114E-v1.0.7",
        "name": "Historical",
        "version": "1.0.7",
        "status": "historical",
    }
    (
        root
        / "config/example/SGD-114E-v1.0.7-component.json"
    ).write_text(
        json.dumps(descriptor),
        encoding="utf-8",
    )

    block = build_managed_block(
        root,
        scan_components(root),
    )

    assert "### Incrementos históricos" in block
    assert "`SGD-114E-V1.0.7`" in block


def test_report_is_json_serializable(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    report = tmp_path / "report.json"

    result = synchronize(
        root,
        apply=False,
        backup_dir=tmp_path / "backup",
        report_path=report,
        preview_path=tmp_path / "preview.md",
    )

    json.dumps(result)
    assert report.is_file()


def test_all_components_are_indexed(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)

    result = synchronize(
        root,
        apply=True,
        backup_dir=tmp_path / "backup",
        report_path=tmp_path / "report.json",
        preview_path=tmp_path / "preview.md",
    )

    assert result["index_coverage_percent"] == 100
    assert result["indexed_components"] == 1


def test_missing_index_is_rejected(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    (
        root / "docs/00_INDICE_MAESTRO.md"
    ).unlink()

    with pytest.raises(FileNotFoundError):
        synchronize(
            root,
            apply=True,
            backup_dir=tmp_path / "backup",
            report_path=tmp_path / "report.json",
            preview_path=tmp_path / "preview.md",
        )
