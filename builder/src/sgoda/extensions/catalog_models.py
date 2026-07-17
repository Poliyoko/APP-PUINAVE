"""Modelos del catálogo local unificado de extensiones."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class CatalogEntry:
    type: str
    name: str
    version: str
    description: str
    builder_requires: str
    enabled: bool
    status: str
    dependencies: dict[str, str] = field(default_factory=dict)
    checksum: str = ""
    manifest_hash: str = ""
    location: str = ""
    source: str = "workspace"
    indexed_at: str = ""

    @property
    def key(self) -> str:
        return f"{self.type}:{self.name}"

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["dependencies"] = dict(self.dependencies)
        return payload


@dataclass(frozen=True, slots=True)
class CatalogSnapshot:
    schema_version: str
    indexed_at: str
    entries: tuple[CatalogEntry, ...]
    duplicates: tuple[str, ...] = ()
    errors: tuple[str, ...] = ()

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "indexed_at": self.indexed_at,
            "entries": [entry.to_dict() for entry in self.entries],
            "duplicates": list(self.duplicates),
            "errors": list(self.errors),
            "statistics": self.statistics(),
        }

    def statistics(self) -> dict[str, int | str]:
        return {
            "total": len(self.entries),
            "plugins": sum(entry.type == "plugin" for entry in self.entries),
            "templates": sum(entry.type == "template" for entry in self.entries),
            "enabled": sum(entry.enabled for entry in self.entries),
            "disabled": sum(not entry.enabled for entry in self.entries),
            "duplicates": len(self.duplicates),
            "errors": len(self.errors),
            "indexed_at": self.indexed_at,
        }
