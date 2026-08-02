"""Construcción y validación del grafo de dependencias."""

from __future__ import annotations

from .discovery import canonical_component_code
from .models import ComponentRecord, DependencyGraph


def _normalize_dependency(value: str) -> str:
    return canonical_component_code(value)


def build_dependency_graph(
    components: list[ComponentRecord],
) -> DependencyGraph:
    nodes = sorted({item.code for item in components})
    node_set = set(nodes)
    edges: list[dict[str, str]] = []
    missing: list[dict[str, str]] = []

    for component in components:
        for raw in component.dependencies:
            dependency = _normalize_dependency(raw)
            if not dependency:
                continue
            edge = {
                "source": component.code,
                "target": dependency,
            }
            edges.append(edge)
            if dependency not in node_set:
                missing.append(edge)

    adjacency: dict[str, list[str]] = {
        node: [] for node in nodes
    }
    for edge in edges:
        if (
            edge["source"] in adjacency
            and edge["target"] in adjacency
        ):
            adjacency[edge["source"]].append(edge["target"])

    cycles: list[list[str]] = []
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []

    def visit(node: str) -> None:
        if node in visiting:
            index = stack.index(node)
            cycle = stack[index:] + [node]
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

    unique_edges = {
        (item["source"], item["target"]): item
        for item in edges
    }
    unique_missing = {
        (item["source"], item["target"]): item
        for item in missing
    }

    return DependencyGraph(
        nodes=nodes,
        edges=sorted(
            unique_edges.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        missing_dependencies=sorted(
            unique_missing.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        cycles=cycles,
    )