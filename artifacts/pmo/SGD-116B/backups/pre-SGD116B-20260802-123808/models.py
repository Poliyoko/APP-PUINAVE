"""Modelos institucionales de SGD-116."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class ComponentRecord:
    code: str
    name: str
    version: str
    status: str
    component_type: str
    phase: str
    dependencies: list[str] = field(default_factory=list)
    source_paths: list[str] = field(default_factory=list)
    test_paths: list[str] = field(default_factory=list)
    documentation_paths: list[str] = field(default_factory=list)
    release_path: str | None = None
    config_path: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class DependencyGraph:
    nodes: list[str]
    edges: list[dict[str, str]]
    missing_dependencies: list[dict[str, str]]
    historical_dependencies: list[dict[str, str]]
    cycles: list[list[str]]


@dataclass(slots=True)
class EcosystemMetrics:
    total_components: int
    implemented_components: int
    pending_components: int
    released_components: int
    documented_components: int
    tested_components: int
    total_test_files: int
    total_documents: int
    total_releases: int
    completion_percent: float
    documentation_percent: float
    test_coverage_percent: float


@dataclass(slots=True)
class ValidationResult:
    passed: bool
    component_count: int
    duplicate_codes: list[str]
    broken_paths: list[str]
    missing_dependencies: list[dict[str, str]]
    historical_dependencies: list[dict[str, str]]
    dependency_cycles: list[list[str]]
    missing_master_documents: list[str]
    generated_at_utc: str