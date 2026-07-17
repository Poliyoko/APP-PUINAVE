"""Construcción reproducible del catálogo desde el registro de extensiones."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

from .catalog_models import CatalogEntry, CatalogSnapshot
from .catalog_store import CatalogStore
from .registry import ExtensionRegistry


class CatalogBuilder:
    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        root = self.workspace / ".sgoda" / "extensions"
        self.registry = ExtensionRegistry(root)
        self.store = CatalogStore(self.workspace)

    def build(self) -> CatalogSnapshot:
        indexed_at = datetime.now(UTC).isoformat()
        entries: list[CatalogEntry] = []
        seen: set[str] = set()
        duplicates: list[str] = []
        errors: list[str] = []

        for record in self.registry.list():
            key = record.key
            if key in seen:
                duplicates.append(key)
                continue
            seen.add(key)
            location = Path(record.installed_path)
            if not location.exists():
                errors.append(f"{key}: ruta instalada inexistente")
                status = "missing"
            else:
                status = record.status
            entries.append(
                CatalogEntry(
                    type=record.type,
                    name=record.name,
                    version=record.version,
                    description=record.description,
                    builder_requires=record.builder_requires,
                    enabled=record.enabled,
                    status=status,
                    dependencies=dict(record.dependencies),
                    checksum=record.checksum,
                    manifest_hash=record.manifest_hash,
                    location=str(location),
                    indexed_at=indexed_at,
                )
            )

        entries.sort(key=lambda item: (item.type, item.name, item.version))
        return CatalogSnapshot(
            schema_version=CatalogStore.SCHEMA_VERSION,
            indexed_at=indexed_at,
            entries=tuple(entries),
            duplicates=tuple(sorted(duplicates)),
            errors=tuple(sorted(errors)),
        )

    def rebuild(self) -> CatalogSnapshot:
        snapshot = self.build()
        self.store.save(snapshot)
        return snapshot
