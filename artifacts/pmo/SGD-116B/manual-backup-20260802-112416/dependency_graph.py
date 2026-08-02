"""Grafo institucional estricto para SGD-116B."""

from __future__ import annotations

from .aliases import resolve_alias
from .models import ComponentRecord, DependencyGraph


def build_dependency_graph(
    components: list[ComponentRecord],
) -> DependencyGraph:
    nodes = sorted({component.code for component in components})
    node_set = set(nodes)
    by_code = {
        component.code: component
        for component in components
    }

    edges: dict[tuple[str, str], dict[str, str]] = {}
    aliases: dict[tuple[str, str], dict[str, str]] = {}
    historical: dict[tuple[str, str], dict[str, str]] = {}
    missing: dict[tuple[str, str], dict[str, str]] = {}

    for component in components:
        for raw_dependency in component.dependencies:
            resolution = resolve_alias(raw_dependency)
            target = resolution.canonical

            if not resolution.valid_format or not target:
                target = str(raw_dependency).strip().upper()

            if not target or target == component.code:
                continue

            edge = {
                "source": component.code,
                "target": target,
                "status": "FOUND",
            }
            key = (component.code, target)

            if resolution.changed:
                aliases[key] = {
                    "source": component.code,
                    "raw_target": resolution.raw,
                    "target": target,
                    "status": "ALIASED",
                }

            if target not in node_set:
                edge["status"] = "MISSING"
                missing[key] = edge
            else:
                target_component = by_code[target]

                if target_component.metadata.get(
                    "synthetic_canonical_anchor"
                ):
                    edge["status"] = "HISTORICAL"
                    historical[key] = edge

            edges[key] = edge

    adjacency: dict[str, list[str]] = {
        node: [] for node in nodes
    }

    for edge in edges.values():
        if edge["target"] in node_set:
            adjacency[edge["source"]].append(
                edge["target"]
            )

    cycles: list[list[str]] = []
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []

    def visit(node: str) -> None:
        if node in visiting:
            start = stack.index(node)
            cycle = stack[start:] + [node]

            if cycle not in cycles:
                cycles.append(cycle)
            return

        if node in visited:
            return

        visiting.add(node)
        stack.append(node)

        for target in adjacency.get(node, []):
            visit(target)

        stack.pop()
        visiting.remove(node)
        visited.add(node)

    for node in nodes:
        visit(node)

    sort_key = lambda item: (
        item["source"],
        item["target"],
    )

    return DependencyGraph(
        nodes=nodes,
        edges=sorted(edges.values(), key=sort_key),
        resolved_aliases=sorted(
            aliases.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        historical_dependencies=sorted(
            historical.values(),
            key=sort_key,
        ),
        missing_dependencies=sorted(
            missing.values(),
            key=sort_key,
        ),
        cycles=cycles,
    )