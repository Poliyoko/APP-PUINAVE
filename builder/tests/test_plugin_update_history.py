import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.operations import HistoryStore


def make_plugin(root: Path, version: str) -> Path:
    source = root / f"history-{version}"
    source.mkdir()
    (source / "plugin.py").write_text("def register(): pass\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": "history-plugin",
            "version": version,
            "builder_requires": ">=1.6.0,<2.0.0",
            "entry_point": "plugin:register",
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_success_and_failure_events(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    assert main([
        "init",
        str(workspace),
        "--project-name",
        "Historial Plugin",
    ]) == 0
    capsys.readouterr()

    v1 = make_plugin(tmp_path, "1.0.0")
    v2 = make_plugin(tmp_path, "1.1.0")

    assert main([
        "plugin", "install", str(v1),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "update", "history-plugin", str(v2),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "update", "history-plugin", str(v1),
        "--workspace", str(workspace),
    ]) == 1
    capsys.readouterr()

    types = [
        event.event_type
        for event in HistoryStore(workspace).read_all()
    ]
    assert "plugin_updated" in types
    assert "plugin_update_failed" in types
