import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.operations import HistoryStore


def make_template(root: Path) -> Path:
    source = root / "history-template"
    render = source / "template"
    render.mkdir(parents=True)
    (render / "README.md").write_text("# Template\n", encoding="utf-8")
    (source / "sgoda.template.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "template",
            "name": "history-template",
            "version": "1.0.0",
            "builder_requires": ">=1.12.0,<2.0.0",
            "render_root": "template",
            "variables": {},
            "files": ["template/README.md"],
        }),
        encoding="utf-8",
    )
    return source


def test_template_state_and_doctor_events(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_template(tmp_path)
    assert main([
        "init", str(workspace), "--project-name", "Templates"
    ]) == 0
    capsys.readouterr()
    assert main([
        "template", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()
    assert main([
        "template", "disable", "history-template",
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()
    assert main([
        "template", "enable", "history-template",
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()
    assert main(["template", "doctor", str(workspace)]) == 0
    capsys.readouterr()

    types = [
        event.event_type
        for event in HistoryStore(workspace).read_all()
    ]
    assert "template_installed" in types
    assert "template_disabled" in types
    assert "template_enabled" in types
    assert "template_ecosystem_diagnosed" in types
