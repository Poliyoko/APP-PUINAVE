import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.extensions import ExtensionManager


def make_plugin(root: Path, name: str = "integrity-plugin") -> Path:
    source = root / "source"
    source.mkdir()
    (source / "plugin.py").write_text(
        "def register(): return 'ok'\n",
        encoding="utf-8",
    )
    (source / "data.txt").write_text("original\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": name,
            "version": "1.0.0",
            "builder_requires": ">=1.6.0,<2.0.0",
            "entry_point": "plugin:register",
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_install_records_integrity_baseline(tmp_path) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path)
    result = ExtensionManager(workspace).install(
        source,
        expected_type="plugin",
    )
    record = ExtensionManager(workspace).info(
        "plugin",
        "integrity-plugin",
    )

    assert result.status == "INSTALLED"
    assert record.checksum
    assert record.manifest_hash
    assert "plugin.py" in record.file_hashes
    assert "sgoda.plugin.json" in record.file_hashes
    assert record.integrity_checked_at


def test_verify_detects_modified_missing_and_added_files(
    tmp_path,
    capsys,
) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path)
    assert main([
        "init", str(workspace), "--project-name", "Integridad"
    ]) == 0
    capsys.readouterr()
    assert main([
        "plugin", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    record = ExtensionManager(workspace).info(
        "plugin",
        "integrity-plugin",
    )
    installed = Path(record.installed_path)
    (installed / "plugin.py").write_text(
        "def register(): return 'altered'\n",
        encoding="utf-8",
    )
    (installed / "data.txt").unlink()
    (installed / "extra.txt").write_text("extra\n", encoding="utf-8")

    assert main([
        "plugin", "verify", "integrity-plugin",
        "--workspace", str(workspace),
        "--format", "json",
    ]) == 1
    payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == "ERROR"
    assert payload["modified_files"] == ["plugin.py"]
    assert payload["missing_files"] == ["data.txt"]
    assert payload["added_files"] == ["extra.txt"]


def test_refresh_accepts_current_baseline(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path)
    assert main([
        "plugin", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    record = ExtensionManager(workspace).info(
        "plugin",
        "integrity-plugin",
    )
    installed = Path(record.installed_path)
    (installed / "plugin.py").write_text(
        "def register(): return 'approved'\n",
        encoding="utf-8",
    )

    assert main([
        "plugin", "verify", "integrity-plugin",
        "--workspace", str(workspace),
        "--refresh",
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "verify", "integrity-plugin",
        "--workspace", str(workspace),
    ]) == 0
    assert "Estado: HEALTHY" in capsys.readouterr().out
