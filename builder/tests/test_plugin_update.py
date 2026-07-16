import json
from pathlib import Path

from sgoda.cli.main import main
from sgoda.extensions import ExtensionManager


def make_plugin(root: Path, name: str, version: str, marker: str) -> Path:
    source = root / f"{name}-{version}"
    source.mkdir()
    (source / "plugin.py").write_text(
        f"MARKER = {marker!r}\n\ndef register(): return MARKER\n",
        encoding="utf-8",
    )
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": name,
            "version": version,
            "builder_requires": ">=1.6.0,<2.0.0",
            "entry_point": "plugin:register",
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_atomic_update_creates_backup(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    v1 = make_plugin(tmp_path, "atomic-plugin", "1.0.0", "old")
    v2 = make_plugin(tmp_path, "atomic-plugin", "1.1.0", "new")

    assert main([
        "plugin", "install", str(v1),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "update", "atomic-plugin", str(v2),
        "--workspace", str(workspace),
    ]) == 0
    output = capsys.readouterr().out
    assert "1.0.0 -> 1.1.0" in output
    assert "Respaldo:" in output

    record = ExtensionManager(workspace).info("plugin", "atomic-plugin")
    assert record.version == "1.1.0"
    installed = Path(record.installed_path)
    assert "new" in (installed / "plugin.py").read_text(encoding="utf-8")

    backups = list(
        (
            workspace
            / ".sgoda"
            / "extensions"
            / "backups"
            / "plugins"
            / "atomic-plugin"
        ).iterdir()
    )
    assert len(backups) == 1
    assert "old" in (backups[0] / "plugin.py").read_text(encoding="utf-8")


def test_downgrade_is_blocked_by_default(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    v2 = make_plugin(tmp_path, "versioned-plugin", "2.0.0", "new")
    v1 = make_plugin(tmp_path, "versioned-plugin", "1.0.0", "old")

    assert main([
        "plugin", "install", str(v2),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "update", "versioned-plugin", str(v1),
        "--workspace", str(workspace),
    ]) == 1
    assert "Downgrade bloqueado" in capsys.readouterr().out

    record = ExtensionManager(workspace).info("plugin", "versioned-plugin")
    assert record.version == "2.0.0"


def test_explicit_downgrade_is_allowed(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    v2 = make_plugin(tmp_path, "downgrade-plugin", "2.0.0", "new")
    v1 = make_plugin(tmp_path, "downgrade-plugin", "1.0.0", "old")

    assert main([
        "plugin", "install", str(v2),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "update", "downgrade-plugin", str(v1),
        "--workspace", str(workspace),
        "--allow-downgrade",
        "--no-backup",
    ]) == 0
    capsys.readouterr()

    record = ExtensionManager(workspace).info("plugin", "downgrade-plugin")
    assert record.version == "1.0.0"
