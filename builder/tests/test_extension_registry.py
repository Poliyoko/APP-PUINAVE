from pathlib import Path

import pytest

from sgoda.extensions import (
    ExtensionManifest,
    ExtensionRecord,
    ExtensionRegistry,
    ExtensionRegistryError,
)


def record(root: Path, version: str = "1.10.0") -> ExtensionRecord:
    manifest = ExtensionManifest(
        schema_version="1.0",
        type="plugin",
        name="ejemplo",
        version=version,
        builder_requires=">=1.2.0",
        entry_point="plugin:register",
    )
    return ExtensionRecord.create(manifest, root / "plugins/ejemplo")


def test_registry_persists_records(tmp_path) -> None:
    registry = ExtensionRegistry(tmp_path)
    assert registry.register(record(tmp_path)) == "REGISTERED"

    reloaded = ExtensionRegistry(tmp_path)
    assert reloaded.get("plugin:ejemplo").version == "1.10.0"


def test_same_version_is_idempotent(tmp_path) -> None:
    registry = ExtensionRegistry(tmp_path)
    registry.register(record(tmp_path))
    assert registry.register(record(tmp_path)) == "ALREADY_REGISTERED"


def test_conflicting_version_requires_force(tmp_path) -> None:
    registry = ExtensionRegistry(tmp_path)
    registry.register(record(tmp_path))
    with pytest.raises(ExtensionRegistryError):
        registry.register(record(tmp_path, "2.0.0"))
    assert registry.register(record(tmp_path, "2.0.0"), force=True) == "UPDATED"
