import json
from pathlib import Path

from sgoda.extensions import BundleService, CatalogService, ExtensionManager


def make_plugin(root: Path, name: str = "alpha") -> Path:
    source = root / name
    source.mkdir()
    (source / "plugin.py").write_text("def register(): return None\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(json.dumps({
        "schema_version": "1.0",
        "type": "plugin",
        "name": name,
        "version": "1.0.0",
        "builder_requires": ">=1.13.0,<2.0.0",
        "description": "Plugin bundle",
        "entry_point": "plugin:register",
        "dependencies": {},
    }), encoding="utf-8")
    return source


def test_create_bundle_copies_assets(tmp_path) -> None:
    workspace = tmp_path / "project"
    ExtensionManager(workspace).install(
        make_plugin(tmp_path),
        expected_type="plugin",
    )
    CatalogService(workspace).rebuild()
    bundle = BundleService(workspace).create("core", ["plugin:alpha"])
    assert bundle.items[0].name == "alpha"
    assert Path(bundle.items[0].source).is_dir()
    assert BundleService(workspace).info("core").name == "core"
