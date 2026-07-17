import json
from pathlib import Path

from sgoda.cli.main import main


def make_plugin(root: Path) -> Path:
    source = root / "cli-portable"
    source.mkdir()
    (source / "plugin.py").write_text("def register(): return None\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(json.dumps({
        "schema_version": "1.0", "type": "plugin", "name": "cli-portable",
        "version": "1.0.0", "builder_requires": ">=1.12.0,<2.0.0",
        "entry_point": "plugin:register", "dependencies": {},
    }), encoding="utf-8")
    return source


def test_export_import_and_report_cli(tmp_path, capsys) -> None:
    source_workspace = tmp_path / "source"
    assert main(["plugin", "install", str(make_plugin(tmp_path)), "--workspace", str(source_workspace)]) == 0
    capsys.readouterr()
    package = tmp_path / "cli.sgoda"
    assert main(["export", "create", str(package), "--workspace", str(source_workspace)]) == 0
    capsys.readouterr()
    assert main(["export", "verify", str(package), "--workspace", str(source_workspace), "--format", "json"]) == 0
    assert json.loads(capsys.readouterr().out)["valid"] is True

    target = tmp_path / "target"
    assert main(["import", "package", str(package), "--workspace", str(target)]) == 0
    capsys.readouterr()
    assert main(["ecosystem-report", str(target), "--format", "json"]) == 0
    report = json.loads(capsys.readouterr().out)
    assert report["statistics"]["plugins"] == 1
