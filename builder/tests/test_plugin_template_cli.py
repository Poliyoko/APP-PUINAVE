import json
from pathlib import Path

from sgoda.cli.main import main


def create_plugin(tmp_path: Path) -> Path:
    source = tmp_path / "plugin-source"
    source.mkdir()
    (source / "plugin.py").write_text("def register(): pass\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": "plugin-ejemplo",
            "version": "1.12.0",
            "builder_requires": ">=1.2.0",
            "entry_point": "plugin:register",
        }),
        encoding="utf-8",
    )
    return source


def create_template(tmp_path: Path) -> Path:
    source = tmp_path / "template-source"
    source.mkdir()
    (source / "README.md").write_text(
        "# {{ project_name }}\nBuilder {{ builder_version }}\n",
        encoding="utf-8",
    )
    (source / "sgoda.template.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "template",
            "name": "plantilla-ejemplo",
            "version": "1.12.0",
            "builder_requires": ">=1.2.0",
            "files": ["README.md"],
        }),
        encoding="utf-8",
    )
    return source


def test_plugin_install_list_info_remove(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = create_plugin(tmp_path)

    assert main(["plugin", "install", str(source), "--workspace", str(workspace)]) == 0
    assert main(["plugin", "list", str(workspace)]) == 0
    assert "plugin:plugin-ejemplo" in capsys.readouterr().out

    assert main(["plugin", "info", "plugin-ejemplo", "--workspace", str(workspace)]) == 0
    assert main(["plugin", "remove", "plugin-ejemplo", "--workspace", str(workspace)]) == 0


def test_template_install_and_render(tmp_path) -> None:
    workspace = tmp_path / "project"
    source = create_template(tmp_path)
    destination = tmp_path / "rendered"

    assert main(["template", "install", str(source), "--workspace", str(workspace)]) == 0
    assert main([
        "template", "render", "plantilla-ejemplo", str(destination),
        "--workspace", str(workspace),
        "--var", "project_name=Mi Proyecto",
    ]) == 0

    content = (destination / "README.md").read_text(encoding="utf-8")
    assert "Mi Proyecto" in content
    assert "1.12.0" in content


def test_template_render_preserves_existing_file(tmp_path) -> None:
    workspace = tmp_path / "project"
    source = create_template(tmp_path)
    destination = tmp_path / "rendered"
    destination.mkdir()
    target = destination / "README.md"
    target.write_text("local", encoding="utf-8")

    main(["template", "install", str(source), "--workspace", str(workspace)])
    assert main([
        "template", "render", "plantilla-ejemplo", str(destination),
        "--workspace", str(workspace),
    ]) == 0
    assert target.read_text(encoding="utf-8") == "local"
