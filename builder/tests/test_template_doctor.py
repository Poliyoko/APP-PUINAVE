import json
from pathlib import Path

from sgoda.cli.main import main


def make_template(root: Path) -> Path:
    source = root / "doctor-template"
    render = source / "template"
    render.mkdir(parents=True)
    (render / "README.md").write_text("# Template\n", encoding="utf-8")
    (source / "sgoda.template.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "template",
            "name": "doctor-template",
            "version": "1.0.0",
            "builder_requires": ">=1.13.0,<2.0.0",
            "render_root": "template",
            "variables": {},
            "files": ["template/README.md"],
        }),
        encoding="utf-8",
    )
    return source


def test_template_doctor_text_and_json(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_template(tmp_path)
    assert main([
        "template", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main(["template", "doctor", str(workspace)]) == 0
    output = capsys.readouterr().out
    assert "Template Ecosystem Doctor" in output
    assert "Estado: HEALTHY" in output

    assert main([
        "template", "doctor", str(workspace),
        "--format", "json",
    ]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["installed"] == 1
    assert payload["enabled"] == 1
    assert payload["status"] == "HEALTHY"
