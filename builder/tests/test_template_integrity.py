import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.extensions import ExtensionManager


def make_template(root: Path) -> Path:
    source = root / "integrity-template"
    render = source / "template"
    render.mkdir(parents=True)
    (render / "README.md").write_text(
        "# Integridad\n",
        encoding="utf-8",
    )
    (render / "data.txt").write_text("original\n", encoding="utf-8")
    (source / "sgoda.template.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "template",
            "name": "integrity-template",
            "version": "1.0.0",
            "builder_requires": ">=1.7.0,<2.0.0",
            "render_root": "template",
            "variables": {},
            "files": [
                "template/README.md",
                "template/data.txt",
            ],
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_template_verify_healthy(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_template(tmp_path)

    assert main([
        "template", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "template", "verify", "integrity-template",
        "--workspace", str(workspace),
        "--format", "json",
    ]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == "HEALTHY"
    assert payload["tracked"] is True
    assert payload["modified_files"] == []
    assert payload["missing_files"] == []
    assert payload["added_files"] == []


def test_template_verify_detects_all_file_changes(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_template(tmp_path)

    assert main([
        "template", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    record = ExtensionManager(workspace).info(
        "template",
        "integrity-template",
    )
    installed = Path(record.installed_path)
    (installed / "template" / "README.md").write_text(
        "# Alterada\n",
        encoding="utf-8",
    )
    (installed / "template" / "data.txt").unlink()
    (installed / "template" / "extra.txt").write_text(
        "extra\n",
        encoding="utf-8",
    )

    assert main([
        "template", "verify", "integrity-template",
        "--workspace", str(workspace),
        "--format", "json",
    ]) == 1
    payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == "ERROR"
    assert payload["modified_files"] == ["template/README.md"]
    assert payload["missing_files"] == ["template/data.txt"]
    assert payload["added_files"] == ["template/extra.txt"]


def test_template_refresh_accepts_current_baseline(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_template(tmp_path)

    assert main([
        "template", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    record = ExtensionManager(workspace).info(
        "template",
        "integrity-template",
    )
    installed = Path(record.installed_path)
    (installed / "template" / "README.md").write_text(
        "# Cambio aprobado\n",
        encoding="utf-8",
    )

    assert main([
        "template", "verify", "integrity-template",
        "--workspace", str(workspace),
        "--refresh",
    ]) == 0
    capsys.readouterr()

    assert main([
        "template", "verify", "integrity-template",
        "--workspace", str(workspace),
    ]) == 0
    assert "Estado: HEALTHY" in capsys.readouterr().out
