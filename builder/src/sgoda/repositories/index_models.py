"""Modelos de índices remotos SGODA."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class IndexPackage:
    name: str
    type: str
    version: str
    download_url: str
    sha256: str
    description: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class RepositoryIndex:
    schema_version: str
    repository: str
    generated_at: str
    packages: tuple[IndexPackage, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "repository": self.repository,
            "generated_at": self.generated_at,
            "packages": [package.to_dict() for package in self.packages],
        }


@dataclass(frozen=True, slots=True)
class SyncMetadata:
    repository: str
    source_url: str
    synchronized_at: str
    status: str
    sha256: str
    package_count: int
    etag: str | None = None
    last_modified: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class SyncResult:
    repository: str
    status: str
    changed: bool
    package_count: int
    sha256: str
    source_url: str
    message: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
