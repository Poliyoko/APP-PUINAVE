"""Modelos y utilidades del formato portable .sgoda."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class PackageFile:
    path: str
    sha256: str
    size: int

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class PackageManifest:
    schema_version: str
    builder_version: str
    created_at: str
    source_workspace: str
    files: tuple[PackageFile, ...]
    statistics: dict[str, int]

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "builder_version": self.builder_version,
            "created_at": self.created_at,
            "source_workspace": self.source_workspace,
            "files": [item.to_dict() for item in self.files],
            "statistics": dict(self.statistics),
        }
