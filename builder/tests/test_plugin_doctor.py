import json
from pathlib import Path

from sgoda.cli.main import main


def make_plugin(root: Path, name: str) -> Path:
    source = root / name
    source.mkdir()
    (source / "plugin.py").write_text("def register(): pass\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": name,
            "version": "1.0.0",
            "builder_requires": ">=1.11.0,<2.0.0",
            "entry_point": "plugin:register",
        }),
        encoding="utf-8",
    )
    return source


def test_plugin_doctor_text_and_json(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path, "healthy-plugin")
    assert main([
        "plugin", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main(["plugin", "doctor", str(workspace)]) == 0
    output = capsys.readouterr().out
    assert "Plugin Ecosystem Doctor" in output
    assert "Estado: HEALTHY" in output

    assert main([
        "plugin", "doctor", str(workspace),
        "--format", "json",
    ]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["installed"] == 1
    assert payload["status"] == "HEALTHY"
