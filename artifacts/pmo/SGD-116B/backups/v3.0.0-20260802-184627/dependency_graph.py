"""Grafo compatible y enriquecido para SGD-116B."""

from __future__ import annotations

from .aliases import resolve_alias
from .models import ComponentRecord, DependencyGraph


def build_dependency_graph(
    components: list[ComponentRecord],
) -> DependencyGraph:
    nodes = sorted({item.code for item in components})
    node_set = set(nodes)
    by_code = {item.code: item for item in components}

    edges: dict[tuple[str, str], dict[str, str]] = {}
    aliases: dict[tuple[str, str], dict[str, str]] = {}
    historical: dict[tuple[str, str], dict[str, str]] = {}
    missing: dict[tuple[str, str], dict[str, str]] = {}
    states: dict[tuple[str, str], dict[str, str]] = {}

    for component in components:
        for raw_dependency in component.dependencies:
            resolution = resolve_alias(raw_dependency)

            target = (
                resolution.canonical
                if resolution.valid_format
                else str(raw_dependency).strip().upper()
            )

            if not target or target == component.code:
                continue

            key = (component.code, target)

            public_edge = {
                "source": component.code,
                "target": target,
            }

            status = "FOUND"

            if resolution.changed:
                aliases[key] = {
                    "source": component.code,
                    "raw_target": resolution.raw,
                    "target": target,
                    "status": "ALIASED",
                }

            if target not in node_set:
                status = "MISSING"
                missing[key] = public_edge

            elif by_code[target].metadata.get(
                "synthetic_canonical_anchor"
            ):
                status = "HISTORICAL"
                historical[key] = public_edge

            edges[key] = public_edge

            states[key] = {
                "source": component.code,
                "target": target,
                "status": status,
            }

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

    def edge_key(
        item: dict[str, str],
    ) -> tuple[str, str]:
        return item["source"], item["target"]

    return DependencyGraph(
        nodes=nodes,
        edges=sorted(
            edges.values(),
            key=edge_key,
        ),
        resolved_aliases=sorted(
            aliases.values(),
            key=edge_key,
        ),
        historical_dependencies=sorted(
            historical.values(),
            key=edge_key,
        ),
        missing_dependencies=sorted(
            missing.values(),
            key=edge_key,
        ),
        cycles=cycles,
        edge_states=sorted(
            states.values(),
            key=edge_key,
        ),
    )