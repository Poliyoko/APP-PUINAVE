"""Modelos de bundles de extensiones."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class BundleItem:
    type: str
    name: str
    version: str
    source: str
    enabled: bool = True

    @property
    def key(self) -> str:
        return f"{self.type}:{self.name}"

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class ExtensionBundle:
    schema_version: str
    name: str
    description: str
    created_at: str
    updated_at: str
    items: tuple[BundleItem, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "name": self.name,
            "description": self.description,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "items": [item.to_dict() for item in self.items],
        }


@dataclass(frozen=True, slots=True)
class BundleOperation:
    action: str
    item: BundleItem
    status: str = "planned"
    message: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "action": self.action,
            "item": self.item.to_dict(),
            "status": self.status,
            "message": self.message,
        }


@dataclass(frozen=True, slots=True)
class BundleExecutionResult:
    bundle: str
    action: str
    status: str
    operations: tuple[BundleOperation, ...]
    rolled_back: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "bundle": self.bundle,
            "action": self.action,
            "status": self.status,
            "rolled_back": self.rolled_back,
            "operations": [operation.to_dict() for operation in self.operations],
        }
