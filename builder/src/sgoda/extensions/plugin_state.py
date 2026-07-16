"""Habilitación y deshabilitación segura de plugins."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .dependency_resolver import PluginDependencyResolver
from .manager import ExtensionManagerError
from .models import ExtensionRecord
from .registry import ExtensionRegistry


@dataclass(frozen=True, slots=True)
class PluginStateResult:
    name: str
    enabled: bool
    status: str
    changed: bool


class PluginStateService:
    def __init__(self, workspace: str | Path) -> None:
        root = Path(workspace).expanduser().resolve() / ".sgoda" / "extensions"
        self.registry = ExtensionRegistry(root)

    def set_enabled(self, name: str, enabled: bool) -> PluginStateResult:
        key = f"plugin:{name}"
        record = self.registry.get(key)
        if record is None:
            raise ExtensionManagerError(f"No existe plugin:{name}.")

        if record.enabled == enabled:
            return PluginStateResult(
                name=name,
                enabled=enabled,
                status=record.status,
                changed=False,
            )

        if enabled:
            records = self.registry.list("plugin")
            candidate = record.with_state(
                enabled=True,
                status="compatible",
            )
            records = [
                candidate if item.name == name else item
                for item in records
            ]
            issues = PluginDependencyResolver(records).issues_for(name)
            if issues:
                summary = ", ".join(
                    f"{issue.dependency}:{issue.kind}"
                    for issue in issues
                )
                raise ExtensionManagerError(
                    f"No se puede habilitar {name}; dependencias: {summary}."
                )
            updated = candidate
        else:
            dependents = [
                item.name
                for item in self.registry.list("plugin")
                if item.enabled and name in item.dependencies
            ]
            if dependents:
                raise ExtensionManagerError(
                    "No se puede deshabilitar; plugins dependientes activos: "
                    + ", ".join(sorted(dependents))
                )
            updated = record.with_state(
                enabled=False,
                status="disabled",
            )

        self.registry.update_record(updated)
        return PluginStateResult(
            name=name,
            enabled=updated.enabled,
            status=updated.status,
            changed=True,
        )
