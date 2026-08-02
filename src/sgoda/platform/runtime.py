"""Construcción del runtime integrado."""

from __future__ import annotations

from pathlib import Path

from sgoda.knowledge_engine import KnowledgeGraph

from .facade import IntegratedPlatformFacade
from .registry import default_registry


def build_runtime(
    graph_path: str | Path,
) -> IntegratedPlatformFacade:
    graph = KnowledgeGraph.from_json(graph_path)
    return IntegratedPlatformFacade(
        graph=graph,
        registry=default_registry(),
    )