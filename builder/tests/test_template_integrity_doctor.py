import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.extensions import ExtensionManager


def make_template(root: Path) -> Path:
    source = root / "doctor-template-integrity"
    render = source / "template"
    render.mkdir(parents=True)
    (render / "README.md").write_text("# Doctor\n", encoding="utf-8")
    (source / "sgoda.template.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "template",
            "name": "doctor-template-integrity",
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


def test_template_doctor_lists_modified_file(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_template(tmp_path)

    assert main([
        "template", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    record = ExtensionManager(workspace).info(
        "template",
        "doctor-template-integrity",
    )
    Path(
        record.installed_path,
        "template",
        "README.md",
    ).write_text("# Modificada\n", encoding="utf-8")

    assert main([
        "template", "doctor", str(workspace),
        "--format", "json",
    ]) == 1
    payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == "ERROR"
    assert payload["integrity_failures"] == 1
    diagnostic = payload["diagnostics"][0]
    assert diagnostic["integrity"] == "ERROR"
    assert diagnostic["modified_files"] == ["template/README.md"]
