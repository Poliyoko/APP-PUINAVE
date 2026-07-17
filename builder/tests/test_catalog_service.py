import json
from pathlib import Path

from sgoda.extensions import CatalogService, ExtensionManager


def make_extension(root: Path, kind: str, name: str) -> Path:
    source = root / name
    source.mkdir()
    manifest = {
        "schema_version": "1.0",
        "type": kind,
        "name": name,
        "version": "1.0.0",
        "builder_requires": ">=1.12.0,<2.0.0",
        "description": f"{kind} {name}",
        "dependencies": {},
    }
    if kind == "plugin":
        (source / "plugin.py").write_text("def register(): pass\n", encoding="utf-8")
        manifest["entry_point"] = "plugin:register"
        manifest_name = "sgoda.plugin.json"
    else:
        render = source / "template"
        render.mkdir()
        (render / "README.md").write_text("# Template\n", encoding="utf-8")
        manifest.update({
            "render_root": "template",
            "variables": {},
            "files": ["template/README.md"],
        })
        manifest_name = "sgoda.template.json"
    (source / manifest_name).write_text(json.dumps(manifest), encoding="utf-8")
    return source


def test_rebuild_list_search_info(tmp_path) -> None:
    workspace = tmp_path / "project"
    manager = ExtensionManager(workspace)
    manager.install(make_extension(tmp_path, "plugin", "plugin-alpha"), expected_type="plugin")
    manager.install(make_extension(tmp_path, "template", "template-beta"), expected_type="template")

    service = CatalogService(workspace)
    snapshot = service.rebuild()
    assert snapshot.statistics()["total"] == 2
    assert len(service.list("plugin")) == 1
    assert service.search("beta")[0].type == "template"
    assert service.info("plugin-alpha").name == "plugin-alpha"
