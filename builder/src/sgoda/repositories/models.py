"""Modelos del registro de repositorios remotos."""

from __future__ import annotations

from dataclasses import asdict, dataclass, replace
from datetime import UTC, datetime
from typing import Any


def utc_now() -> str:
    return datetime.now(UTC).isoformat()


@dataclass(frozen=True, slots=True)
class Repository:
    name: str
    url: str
    enabled: bool = True
    priority: int = 100
    trusted: bool = False
    created_at: str = ""
    updated_at: str = ""

    def __post_init__(self) -> None:
        now = utc_now()
        if not self.created_at:
            object.__setattr__(self, "created_at", now)
        if not self.updated_at:
            object.__setattr__(self, "updated_at", now)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    def with_changes(self, **changes: Any) -> "Repository":
        return replace(self, updated_at=utc_now(), **changes)


@dataclass(frozen=True, slots=True)
class RepositoryRegistry:
    schema_version: str
    repositories: tuple[Repository, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "repositories": [item.to_dict() for item in self.repositories],
        }
