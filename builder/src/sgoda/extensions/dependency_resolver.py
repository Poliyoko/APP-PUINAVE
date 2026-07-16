"""Resolución de dependencias entre plugins instalados."""

from __future__ import annotations

from dataclasses import dataclass

from .compatibility import CompatibilityError, requirement_satisfied
from .models import ExtensionRecord


@dataclass(frozen=True, slots=True)
class DependencyIssue:
    plugin: str
    dependency: str
    requirement: str
    installed_version: str | None
    kind: str

    def to_dict(self) -> dict[str, str | None]:
        return {
            "plugin": self.plugin,
            "dependency": self.dependency,
            "requirement": self.requirement,
            "installed_version": self.installed_version,
            "kind": self.kind,
        }


class PluginDependencyResolver:
    def __init__(self, records: list[ExtensionRecord]) -> None:
        self.records = {
            record.name: record
            for record in records
            if record.type == "plugin"
        }

    def issues_for(self, plugin_name: str) -> list[DependencyIssue]:
        record = self.records.get(plugin_name)
        if record is None:
            return []
        issues: list[DependencyIssue] = []
        for dependency, requirement in record.dependencies.items():
            installed = self.records.get(dependency)
            if installed is None:
                issues.append(
                    DependencyIssue(
                        plugin=plugin_name,
                        dependency=dependency,
                        requirement=requirement,
                        installed_version=None,
                        kind="missing",
                    )
                )
                continue
            try:
                compatible = requirement_satisfied(
                    requirement,
                    installed.version,
                )
            except CompatibilityError:
                compatible = False
            if not compatible:
                issues.append(
                    DependencyIssue(
                        plugin=plugin_name,
                        dependency=dependency,
                        requirement=requirement,
                        installed_version=installed.version,
                        kind="incompatible",
                    )
                )
            elif not installed.enabled:
                issues.append(
                    DependencyIssue(
                        plugin=plugin_name,
                        dependency=dependency,
                        requirement=requirement,
                        installed_version=installed.version,
                        kind="disabled",
                    )
                )
        return issues

    def detect_cycles(self) -> list[tuple[str, ...]]:
        graph = {
            name: tuple(
                dependency
                for dependency in record.dependencies
                if dependency in self.records
            )
            for name, record in self.records.items()
        }
        cycles: set[tuple[str, ...]] = set()

        def visit(
            node: str,
            stack: list[str],
            active: set[str],
            visited: set[str],
        ) -> None:
            if node in active:
                index = stack.index(node)
                cycle = tuple(stack[index:] + [node])
                canonical = min(
                    tuple(cycle[i:-1] + cycle[:i] + (cycle[i],))
                    for i in range(len(cycle) - 1)
                )
                cycles.add(canonical)
                return
            if node in visited:
                return
            active.add(node)
            stack.append(node)
            for child in graph.get(node, ()):
                visit(child, stack, active, visited)
            stack.pop()
            active.remove(node)
            visited.add(node)

        visited: set[str] = set()
        for node in graph:
            visit(node, [], set(), visited)
        return sorted(cycles)
