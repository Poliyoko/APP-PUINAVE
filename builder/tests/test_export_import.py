import json
from pathlib import Path

from sgoda.extensions import CatalogService, ExportService, ExtensionManager, ImportService


def make_plugin(root: Path, name: str = "portable") -> Path:
    source = root / name
    source.mkdir()
    (source / "plugin.py").write_text("def register(): return None\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(json.dumps({
        "schema_version": "1.0", "type": "plugin", "name": name,
        "version": "1.0.0", "builder_requires": ">=1.13.0,<2.0.0",
        "entry_point": "plugin:register", "dependencies": {},
    }), encoding="utf-8")
    return source


def test_export_verify_and_import_roundtrip(tmp_path) -> None:
    source_workspace = tmp_path / "source-workspace"
    ExtensionManager(source_workspace).install(make_plugin(tmp_path), expected_type="plugin")
    CatalogService(source_workspace).rebuild()

    package = ExportService(source_workspace).create(tmp_path / "ecosystem")
    assert package.suffix == ".sgoda"
    assert ExportService(source_workspace).verify(package)["valid"] is True

    target = tmp_path / "target-workspace"
    result = ImportService(target).import_package(package)
    assert result["status"] == "IMPORTED"
    record = ExtensionManager(target).registry.get("plugin:portable")
    assert record is not None
    assert Path(record.installed_path).name == "portable"


def test_import_dry_run_does_not_write(tmp_path) -> None:
    source_workspace = tmp_path / "source"
    ExtensionManager(source_workspace).install(make_plugin(tmp_path), expected_type="plugin")
    package = ExportService(source_workspace).create(tmp_path / "dry")
    target = tmp_path / "target"
    result = ImportService(target).import_package(package, dry_run=True)
    assert result["status"] == "PLANNED"
    assert not (target / ".sgoda" / "extensions").exists()
