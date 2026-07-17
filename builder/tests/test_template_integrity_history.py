import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.extensions import ExtensionManager
from sgoda.operations import HistoryStore


def make_template(root: Path) -> Path:
    source = root / "history-template-integrity"
    render = source / "template"
    render.mkdir(parents=True)
    (render / "README.md").write_text("# History\n", encoding="utf-8")
    (source / "sgoda.template.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "template",
            "name": "history-template-integrity",
            "version": "1.0.0",
            "builder_requires": ">=1.11.0,<2.0.0",
            "render_root": "template",
            "variables": {},
            "files": ["template/README.md"],
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_template_integrity_events(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_template(tmp_path)

    assert main([
        "init", str(workspace), "--project-name", "Template Integrity"
    ]) == 0
    capsys.readouterr()

    assert main([
        "template", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "template", "verify", "history-template-integrity",
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    record = ExtensionManager(workspace).info(
        "template",
        "history-template-integrity",
    )
    Path(
        record.installed_path,
        "template",
        "README.md",
    ).write_text("# Altered\n", encoding="utf-8")

    assert main([
        "template", "verify", "history-template-integrity",
        "--workspace", str(workspace),
    ]) == 1
    capsys.readouterr()

    types = [
        event.event_type
        for event in HistoryStore(workspace).read_all()
    ]
    assert "template_integrity_checked" in types
    assert "template_integrity_failed" in types
