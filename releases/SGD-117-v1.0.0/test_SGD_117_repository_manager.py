
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.repository_manager.manager import (
    InstitutionalRepositoryManager,
)


def _repository(root: Path) -> Path:
    for directory in (
        "src",
        "tests",
        "docs",
        "config/governance",
        "artifacts",
        "releases",
        "scripts",
        "dashboard",
    ):
        (root / directory).mkdir(parents=True, exist_ok=True)

    (root / "pytest.ini").write_text("[pytest]\n", encoding="utf-8")
    (root / "docs/00_INDICE_MAESTRO.md").write_text(
        "# Índice Maestro\n",
        encoding="utf-8",
    )
    (root / "docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text(
        "# Registro Maestro\n",
        encoding="utf-8",
    )
    (root / "docs/00_ARQUITECTURA_MAESTRA.md").write_text(
        "# Arquitectura Maestra\n",
        encoding="utf-8",
    )
    return root


def test_audit_detects_absent_component(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    result = InstitutionalRepositoryManager(
        root
    ).audit_master_documents()

    assert result.index_exists is True
    assert result.registry_exists is True
    assert result.component_preexisted is False


def test_audit_detects_registered_component(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    descriptor = root / "config/governance/SGD-117-component.json"
    descriptor.write_text(
        json.dumps({"increment_code": "SGD-117"}),
        encoding="utf-8",
    )

    result = InstitutionalRepositoryManager(
        root
    ).audit_master_documents()

    assert result.config_declares_component is True
    assert result.component_preexisted is True


def test_inventory_hashes_assets(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    source = root / "src/example.py"
    source.write_text("x = 1\n", encoding="utf-8")

    assets = InstitutionalRepositoryManager(root).inventory()

    assert any(item.path == "src/example.py" for item in assets)
    assert all(len(item.sha256) == 64 for item in assets)


def test_validation_accepts_complete_repository(
    tmp_path: Path,
) -> None:
    result = InstitutionalRepositoryManager(
        _repository(tmp_path)
    ).validate_structure()

    assert result["approved"] is True
    assert result["exit_code"] == 0


def test_validation_blocks_missing_master_document(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    (root / "docs/00_INDICE_MAESTRO.md").unlink()

    result = InstitutionalRepositoryManager(
        root
    ).validate_structure()

    assert result["approved"] is False
    assert "docs/00_INDICE_MAESTRO.md" in result["missing_files"]


def test_validation_detects_invalid_json(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    (root / "config/governance/bad.json").write_text(
        "{bad",
        encoding="utf-8",
    )

    result = InstitutionalRepositoryManager(
        root
    ).validate_structure()

    assert result["approved"] is False
    assert result["invalid_json"]


def test_report_contains_category_counts(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    (root / "tests/test_a.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )

    report = InstitutionalRepositoryManager(root).build_report()

    assert report["category_counts"]["tests"] == 1
    assert report["approved"] is True
