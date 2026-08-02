"""Modelos del Motor de Conocimiento SPT-007C."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class KnowledgeNode:
    node_id: str
    node_type: str
    label: str
    language: str | None = None
    validated: bool = False
    cultural_status: str = "pending"
    source_ref: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class KnowledgeEdge:
    source_id: str
    target_id: str
    relation_type: str
    weight: float = 1.0
    validated: bool = False
    cultural: bool = False
    source_ref: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class InferenceStep:
    source_id: str
    relation_type: str
    target_id: str
    rule_code: str
    explanation: str


@dataclass(frozen=True, slots=True)
class KnowledgeResult:
    query_node_id: str
    nodes: tuple[KnowledgeNode, ...]
    edges: tuple[KnowledgeEdge, ...]
    inference_steps: tuple[InferenceStep, ...]
    no_invention: bool = True