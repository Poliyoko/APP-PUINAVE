import json
from pathlib import Path

import pytest

from sgoda.extensions import (
    ExtensionManager,
    ExtensionRegistryError,
    PluginUpdateError,
    PluginUpdater,
)


def make_plugin(root: Path, name: str, version: str, marker: str) -> Path:
    source = root / f"{name}-{version}"
    source.mkdir()
    (source / "plugin.py").write_text(
        f"MARKER = {marker!r}\n",
        encoding="utf-8",
    )
    (source / "sgoda.plugin.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "plugin",
            "name": name,
            "version": version,
            "builder_requires": ">=1.8.0,<2.0.0",
            "entry_point": "plugin:register",
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_registry_failure_rolls_back_files(
    tmp_path,
    monkeypatch,
) -> None:
    workspace = tmp_path / "project"
    v1 = make_plugin(tmp_path, "rollback-plugin", "1.0.0", "old")
    v2 = make_plugin(tmp_path, "rollback-plugin", "1.1.0", "new")
    manager = ExtensionManager(workspace)
    manager.install(v1, expected_type="plugin")

    updater = PluginUpdater(workspace)

    def fail_update(record):
        raise ExtensionRegistryError("fallo simulado")

    monkeypatch.setattr(updater.registry, "update_record", fail_update)

    with pytest.raises(PluginUpdateError):
        updater.update("rollback-plugin", v2)

    record = ExtensionManager(workspace).info("plugin", "rollback-plugin")
    assert record.version == "1.0.0"
    installed = Path(record.installed_path)
    assert "old" in (installed / "plugin.py").read_text(encoding="utf-8")
    assert not list(installed.parent.glob(".rollback-plugin.*"))
