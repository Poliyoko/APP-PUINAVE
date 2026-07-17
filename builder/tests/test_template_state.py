import json
from pathlib import Path

from sgoda.cli.main import main


def make_template(root: Path) -> Path:
    source = root / "state-template"
    render = source / "template"
    render.mkdir(parents=True)
    (render / "README.md").write_text("# {{ name }}\n", encoding="utf-8")
    (source / "sgoda.template.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "template",
            "name": "state-template",
            "version": "1.0.0",
            "builder_requires": ">=1.12.0,<2.0.0",
            "render_root": "template",
            "variables": {"name": {"required": True}},
            "files": ["template/README.md"],
        }),
        encoding="utf-8",
    )
    return source


def test_disable_blocks_render_and_enable_restores_it(
    tmp_path,
    capsys,
) -> None:
    workspace = tmp_path / "project"
    source = make_template(tmp_path)
    output = tmp_path / "output"

    assert main([
        "template", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "template", "disable", "state-template",
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "template", "render", "state-template", str(output),
        "--workspace", str(workspace),
        "--var", "name=Disabled",
    ]) == 1
    assert "deshabilitada" in capsys.readouterr().out

    assert main([
        "template", "enable", "state-template",
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "template", "render", "state-template", str(output),
        "--workspace", str(workspace),
        "--var", "name=Enabled",
    ]) == 0
    assert (output / "template" / "README.md").is_file()
