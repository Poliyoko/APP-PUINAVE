import json
from pathlib import Path

from sgoda.cli.main import main


def make_plugin(root: Path) -> Path:
    source = root / "cli-bundle-plugin"
    source.mkdir()
    (source / "plugin.py").write_text("def register(): return None\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(json.dumps({
        "schema_version": "1.0",
        "type": "plugin",
        "name": "cli-bundle-plugin",
        "version": "1.0.0",
        "builder_requires": ">=1.10.0,<2.0.0",
        "entry_point": "plugin:register",
        "dependencies": {},
    }), encoding="utf-8")
    return source


def test_bundle_cli_flow(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path)
    assert main(["plugin", "install", str(source), "--workspace", str(workspace)]) == 0
    capsys.readouterr()
    assert main(["catalog", "rebuild", "--workspace", str(workspace)]) == 0
    capsys.readouterr()
    assert main([
        "bundle", "create", "cli-core", "plugin:cli-bundle-plugin",
        "--workspace", str(workspace),
    ]) == 0
    assert "Bundle creado" in capsys.readouterr().out
    assert main([
        "bundle", "info", "cli-core", "--workspace", str(workspace),
        "--format", "json",
    ]) == 0
    assert json.loads(capsys.readouterr().out)["name"] == "cli-core"
    assert main([
        "bundle", "uninstall", "cli-core", "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()
    assert main([
        "bundle", "install", "cli-core", "--workspace", str(workspace),
    ]) == 0
