"""Planificación determinista de operaciones masivas."""

from __future__ import annotations

from pathlib import Path

from .bundle_models import BundleOperation, ExtensionBundle
from .registry import ExtensionRegistry


class BundlePlanner:
    ACTIONS = {"install", "update", "uninstall", "enable", "disable"}

    def __init__(self, workspace: str | Path) -> None:
        root = Path(workspace).expanduser().resolve() / ".sgoda" / "extensions"
        self.registry = ExtensionRegistry(root)

    def plan(self, bundle: ExtensionBundle, action: str) -> tuple[BundleOperation, ...]:
        if action not in self.ACTIONS:
            raise ValueError(f"Acción de bundle no soportada: {action}.")
        operations: list[BundleOperation] = []
        for item in sorted(bundle.items, key=lambda value: (value.type, value.name)):
            installed = self.registry.get(item.key)
            status = "planned"
            message = ""
            if action == "install" and installed is not None:
                status, message = "skipped", "ya instalado"
            elif action in {"update", "uninstall", "enable", "disable"} and installed is None:
                status, message = "skipped", "no instalado"
            elif action == "enable" and installed and installed.enabled:
                status, message = "skipped", "ya habilitado"
            elif action == "disable" and installed and not installed.enabled:
                status, message = "skipped", "ya deshabilitado"
            operations.append(BundleOperation(action, item, status, message))
        return tuple(operations)
