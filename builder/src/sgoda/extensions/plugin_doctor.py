"""Diagnóstico del ecosistema de plugins."""

from __future__ import annotations

from dataclasses import asdict, dataclass
import json
from pathlib import Path
from typing import Any

from sgoda import __version__

from .compatibility import CompatibilityError, requirement_satisfied
from .dependency_resolver import PluginDependencyResolver
from .registry import ExtensionRegistry


@dataclass(frozen=True, slots=True)
class PluginDoctorReport:
    installed: int
    enabled: int
    disabled: int
    incompatible: int
    dependency_issues: tuple[dict[str, Any], ...]
    cycles: tuple[tuple[str, ...], ...]
    status: str
    builder_version: str

    def to_dict(self) -> dict[str, Any]:
        return {
            **asdict(self),
            "dependency_issues": list(self.dependency_issues),
            "cycles": [list(cycle) for cycle in self.cycles],
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=2)

    def to_text(self) -> str:
        return "\n".join([
            "Plugin Ecosystem Doctor",
            "-" * 60,
            f"Plugins instalados: {self.installed}",
            f"Habilitados: {self.enabled}",
            f"Deshabilitados: {self.disabled}",
            f"Incompatibles: {self.incompatible}",
            f"Problemas de dependencias: {len(self.dependency_issues)}",
            f"Ciclos: {len(self.cycles)}",
            "-" * 60,
            f"Estado: {self.status}",
        ])


class PluginDoctor:
    def __init__(self, workspace: str | Path) -> None:
        root = Path(workspace).expanduser().resolve() / ".sgoda" / "extensions"
        self.registry = ExtensionRegistry(root)

    def run(self) -> PluginDoctorReport:
        records = self.registry.list("plugin")
        resolver = PluginDependencyResolver(records)
        issues = tuple(
            issue.to_dict()
            for record in records
            for issue in resolver.issues_for(record.name)
        )
        cycles = tuple(resolver.detect_cycles())
        incompatible = 0
        for record in records:
            if not record.builder_requires:
                continue
            try:
                compatible = requirement_satisfied(
                    record.builder_requires,
                    __version__,
                )
            except CompatibilityError:
                compatible = False
            if not compatible:
                incompatible += 1

        status = (
            "ERROR"
            if incompatible or issues or cycles
            else "HEALTHY"
        )
        return PluginDoctorReport(
            installed=len(records),
            enabled=sum(record.enabled for record in records),
            disabled=sum(not record.enabled for record in records),
            incompatible=incompatible,
            dependency_issues=issues,
            cycles=cycles,
            status=status,
            builder_version=__version__,
        )
