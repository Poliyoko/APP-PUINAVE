import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.extensions import ExtensionManager
from sgoda.operations import HistoryStore


def make_plugin(root: Path) -> Path:
    source = root / "history-integrity"
    source.mkdir()
    (source / "plugin.py").write_text("VALUE = 1\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": "history-integrity",
            "version": "1.0.0",
            "builder_requires": ">=1.13.0,<2.0.0",
            "entry_point": "plugin:register",
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_integrity_events(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path)
    assert main([
        "init", str(workspace), "--project-name", "Eventos integridad"
    ]) == 0
    capsys.readouterr()
    assert main([
        "plugin", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "verify", "history-integrity",
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    record = ExtensionManager(workspace).info(
        "plugin",
        "history-integrity",
    )
    Path(record.installed_path, "plugin.py").write_text(
        "VALUE = 2\n",
        encoding="utf-8",
    )
    assert main([
        "plugin", "verify", "history-integrity",
        "--workspace", str(workspace),
    ]) == 1
    capsys.readouterr()

    types = [
        event.event_type
        for event in HistoryStore(workspace).read_all()
    ]
    assert "plugin_integrity_checked" in types
    assert "plugin_integrity_failed" in types
