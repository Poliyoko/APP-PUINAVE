import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.extensions import ExtensionManager


def make_plugin(root: Path) -> Path:
    source = root / "doctor-source"
    source.mkdir()
    (source / "plugin.py").write_text(
        "def register(): pass\n",
        encoding="utf-8",
    )
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": "doctor-integrity",
            "version": "1.0.0",
            "builder_requires": ">=1.6.0,<2.0.0",
            "entry_point": "plugin:register",
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_doctor_reports_integrity_failure(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path)
    assert main([
        "plugin", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    record = ExtensionManager(workspace).info(
        "plugin",
        "doctor-integrity",
    )
    Path(record.installed_path, "plugin.py").write_text(
        "# modified\n",
        encoding="utf-8",
    )

    assert main([
        "plugin", "doctor", str(workspace),
        "--format", "json",
    ]) == 1
    payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == "ERROR"
    assert payload["integrity_failures"] == 1
    assert payload["integrity"][0]["modified_files"] == ["plugin.py"]


def test_doctor_healthy_integrity(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path)
    assert main([
        "plugin", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "doctor", str(workspace),
    ]) == 0
    output = capsys.readouterr().out
    assert "Fallos de integridad: 0" in output
    assert "Estado: HEALTHY" in output
