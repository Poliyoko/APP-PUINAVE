import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.operations import HistoryStore


def make_plugin(root: Path) -> Path:
    source = root / "history-catalog"
    source.mkdir()
    (source / "plugin.py").write_text("def register(): pass\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": "history-catalog",
            "version": "1.0.0",
            "builder_requires": ">=1.11.0,<2.0.0",
            "entry_point": "plugin:register",
        }),
        encoding="utf-8",
    )
    return source


def test_catalog_events(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    assert main(["init", str(workspace), "--project-name", "Catalog"]) == 0
    capsys.readouterr()
    source = make_plugin(tmp_path)
    assert main(["plugin", "install", str(source), "--workspace", str(workspace)]) == 0
    capsys.readouterr()
    assert main(["catalog", "rebuild", "--workspace", str(workspace)]) == 0
    capsys.readouterr()
    assert main(["catalog", "search", "history", "--workspace", str(workspace)]) == 0
    capsys.readouterr()
    assert main(["catalog", "info", "history-catalog", "--workspace", str(workspace)]) == 0
    capsys.readouterr()

    types = [event.event_type for event in HistoryStore(workspace).read_all()]
    assert "catalog_rebuilt" in types
    assert "catalog_searched" in types
    assert "catalog_info" in types
