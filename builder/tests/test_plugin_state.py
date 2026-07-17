import json
from pathlib import Path

from sgoda.cli.main import main


def make_plugin(
    root: Path,
    name: str,
    dependencies: dict[str, str] | None = None,
) -> Path:
    source = root / name
    source.mkdir()
    (source / "plugin.py").write_text(
        "def register(): return None\n",
        encoding="utf-8",
    )
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": name,
            "version": "1.0.0",
            "builder_requires": ">=1.12.0,<2.0.0",
            "entry_point": "plugin:register",
            "dependencies": dependencies or {},
        }),
        encoding="utf-8",
    )
    return source


def test_disable_and_enable_plugin(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    source = make_plugin(tmp_path, "base-plugin")
    assert main([
        "plugin", "install", str(source),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "disable", "base-plugin",
        "--workspace", str(workspace),
    ]) == 0
    assert "deshabilitado" in capsys.readouterr().out

    assert main([
        "plugin", "enable", "base-plugin",
        "--workspace", str(workspace),
    ]) == 0
    assert "habilitado" in capsys.readouterr().out


def test_enable_rejects_missing_dependency(tmp_path, capsys) -> None:
    workspace = tmp_path / "project"
    child = make_plugin(
        tmp_path,
        "child-plugin",
        {"base-plugin": ">=1.0.0"},
    )
    assert main([
        "plugin", "install", str(child),
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "disable", "child-plugin",
        "--workspace", str(workspace),
    ]) == 0
    capsys.readouterr()

    assert main([
        "plugin", "enable", "child-plugin",
        "--workspace", str(workspace),
    ]) == 1
    assert "dependencias" in capsys.readouterr().out
