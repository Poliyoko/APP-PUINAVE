"""Consultas sobre el catálogo local unificado."""

from __future__ import annotations

from pathlib import Path

from .catalog_builder import CatalogBuilder
from .catalog_models import CatalogEntry, CatalogSnapshot
from .catalog_store import CatalogStore


class CatalogServiceError(RuntimeError):
    """Consulta de catálogo inválida."""


class CatalogService:
    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()
        self.store = CatalogStore(self.workspace)
        self.builder = CatalogBuilder(self.workspace)

    def rebuild(self) -> CatalogSnapshot:
        return self.builder.rebuild()

    def snapshot(self, *, rebuild_if_missing: bool = True) -> CatalogSnapshot:
        snapshot = self.store.load()
        if rebuild_if_missing and not snapshot.indexed_at:
            snapshot = self.rebuild()
        return snapshot

    def list(self, extension_type: str | None = None) -> list[CatalogEntry]:
        entries = list(self.snapshot().entries)
        if extension_type:
            entries = [entry for entry in entries if entry.type == extension_type]
        return entries

    def search(
        self,
        query: str,
        *,
        extension_type: str | None = None,
    ) -> list[CatalogEntry]:
        needle = query.casefold().strip()
        entries = self.list(extension_type)
        if not needle:
            return entries
        return [
            entry
            for entry in entries
            if needle in entry.name.casefold()
            or needle in entry.description.casefold()
            or needle in entry.type.casefold()
        ]

    def info(
        self,
        name: str,
        *,
        extension_type: str | None = None,
    ) -> CatalogEntry:
        matches = [
            entry for entry in self.list(extension_type)
            if entry.name == name
        ]
        if not matches:
            raise CatalogServiceError(f"No existe en catálogo: {name}.")
        if len(matches) > 1:
            raise CatalogServiceError(
                f"Nombre ambiguo: {name}; especifique --type."
            )
        return matches[0]

    def statistics(self) -> dict[str, int | str]:
        return self.snapshot().statistics()
