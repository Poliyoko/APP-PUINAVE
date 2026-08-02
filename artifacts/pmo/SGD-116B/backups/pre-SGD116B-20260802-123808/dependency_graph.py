"""Grafo de dependencias institucional."""

from __future__ import annotations

from .discovery import canonical_component_code
from .models import ComponentRecord, DependencyGraph


def build_dependency_graph(
    components: list[ComponentRecord],
) -> DependencyGraph:
    nodes = sorted({item.code for item in components})
    node_set = set(nodes)

    edges: dict[tuple[str, str], dict[str, str]] = {}
    missing: dict[tuple[str, str], dict[str, str]] = {}
    historical: dict[tuple[str, str], dict[str, str]] = {}

    component_by_code = {
        item.code: item for item in components
    }

    for component in components:
        for raw in component.dependencies:
            target = canonical_component_code(raw)
            if not target or target == component.code:
                continue

            edge = {
                "source": component.code,
                "target": target,
            }
            key = (component.code, target)
            edges[key] = edge

            if target not in node_set:
                missing[key] = edge
                continue

            target_record = component_by_code[target]
            if target_record.metadata.get(
                "synthetic_canonical_anchor"
            ):
                historical[key] = edge

    adjacency: dict[str, list[str]] = {
        node: [] for node in nodes
    }
    for edge in edges.values():
        if edge["target"] in node_set:
            adjacency[edge["source"]].append(edge["target"])

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

    return DependencyGraph(
        nodes=nodes,
        edges=sorted(
            edges.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        missing_dependencies=sorted(
            missing.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        historical_dependencies=sorted(
            historical.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        cycles=cycles,
    )