import json
from pathlib import Path

from sgoda.extensions import BundleService, CatalogService, ExtensionManager


def make_plugin(root: Path, name: str = "mass-plugin") -> Path:
    source = root / name
    source.mkdir()
    (source / "plugin.py").write_text("def register(): return None\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(json.dumps({
        "schema_version": "1.0",
        "type": "plugin",
        "name": name,
        "version": "1.0.0",
        "builder_requires": ">=1.13.0,<2.0.0",
        "entry_point": "plugin:register",
        "dependencies": {},
    }), encoding="utf-8")
    return source


def test_uninstall_and_restore_bundle(tmp_path) -> None:
    workspace = tmp_path / "project"
    manager = ExtensionManager(workspace)
    manager.install(make_plugin(tmp_path), expected_type="plugin")
    CatalogService(workspace).rebuild()
    service = BundleService(workspace)
    service.create("mass", ["plugin:mass-plugin"])

    removed = service.execute("mass", "uninstall")
    assert removed.status == "COMPLETED"
    assert manager.registry.get("plugin:mass-plugin") is None

    installed = service.execute("mass", "install")
    assert installed.status == "COMPLETED"
    assert manager.registry.get("plugin:mass-plugin") is not None


def test_bundle_dry_run_does_not_change_registry(tmp_path) -> None:
    workspace = tmp_path / "project"
    manager = ExtensionManager(workspace)
    manager.install(make_plugin(tmp_path), expected_type="plugin")
    CatalogService(workspace).rebuild()
    service = BundleService(workspace)
    service.create("plan", ["plugin:mass-plugin"])
    result = service.execute("plan", "uninstall", dry_run=True)
    assert result.status == "PLANNED"
    assert manager.registry.get("plugin:mass-plugin") is not None
