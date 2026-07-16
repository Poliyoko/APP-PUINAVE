"""Servicio de verificación y recalculo de integridad de plugins."""

from __future__ import annotations

from dataclasses import replace
from datetime import UTC, datetime
from pathlib import Path

from .integrity import (
    PluginIntegrityResult,
    create_integrity_snapshot,
    verify_integrity,
)
from .manager import ExtensionManagerError
from .registry import ExtensionRegistry, ExtensionRegistryError


class PluginIntegrityService:
    def __init__(self, workspace: str | Path) -> None:
        root = Path(workspace).expanduser().resolve() / ".sgoda" / "extensions"
        self.registry = ExtensionRegistry(root)

    def verify(self, name: str) -> PluginIntegrityResult:
        record = self.registry.get(f"plugin:{name}")
        if record is None:
            raise ExtensionManagerError(f"No existe plugin:{name}.")
        return verify_integrity(
            name=name,
            root=record.installed_path,
            expected_checksum=record.checksum,
            expected_manifest_hash=record.manifest_hash,
            expected_file_hashes=record.file_hashes,
        )

    def refresh(self, name: str) -> PluginIntegrityResult:
        record = self.registry.get(f"plugin:{name}")
        if record is None:
            raise ExtensionManagerError(f"No existe plugin:{name}.")
        installed = Path(record.installed_path)
        if not installed.is_dir():
            raise ExtensionManagerError(
                f"No existe la ruta instalada: {installed}"
            )
        snapshot = create_integrity_snapshot(installed)
        updated = replace(
            record,
            checksum=snapshot.checksum,
            manifest_hash=snapshot.manifest_hash,
            file_hashes=snapshot.file_hashes,
            integrity_checked_at=datetime.now(UTC).isoformat(),
        )
        try:
            self.registry.update_record(updated)
        except ExtensionRegistryError as exc:
            raise ExtensionManagerError(str(exc)) from exc
        return self.verify(name)
