import json
from pathlib import Path

from sgoda.cli.main import main


def make_plugin(root: Path) -> Path:
    source = root / "catalog-plugin"
    source.mkdir()
    (source / "plugin.py").write_text("def register(): pass\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": "catalog-plugin",
            "version": "1.0.0",
            "builder_requires": ">=1.12.0,<2.0.0",
            "description": "Plugin del catálogo",
            "entry_point": "plugin:register",
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_catalog_cli(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path)
    assert main(["plugin", "install", str(source), "--workspace", str(workspace)]) == 0
    capsys.readouterr()

    assert main(["catalog", "rebuild", "--workspace", str(workspace)]) == 0
    assert "Elementos: 1" in capsys.readouterr().out

    assert main([
        "catalog", "search", "catalog", "--workspace", str(workspace),
        "--format", "json",
    ]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload[0]["name"] == "catalog-plugin"

    assert main([
        "catalog", "info", "catalog-plugin", "--workspace", str(workspace),
        "--type", "plugin",
    ]) == 0
