"""Habilitación y deshabilitación de plantillas instaladas."""

from __future__ import annotations

from pathlib import Path

from .manager import ExtensionManagerError
from .registry import ExtensionRegistry
from .template_models import TemplateStateResult


class TemplateStateService:
    def __init__(self, workspace: str | Path) -> None:
        root = Path(workspace).expanduser().resolve() / ".sgoda" / "extensions"
        self.registry = ExtensionRegistry(root)

    def set_enabled(
        self,
        name: str,
        enabled: bool,
    ) -> TemplateStateResult:
        record = self.registry.get(f"template:{name}")
        if record is None:
            raise ExtensionManagerError(f"No existe template:{name}.")

        if record.enabled == enabled:
            return TemplateStateResult(
                name=name,
                enabled=enabled,
                status=record.status,
                changed=False,
            )

        updated = record.with_state(
            enabled=enabled,
            status="compatible" if enabled else "disabled",
        )
        self.registry.update_record(updated)
        return TemplateStateResult(
            name=name,
            enabled=updated.enabled,
            status=updated.status,
            changed=True,
        )
