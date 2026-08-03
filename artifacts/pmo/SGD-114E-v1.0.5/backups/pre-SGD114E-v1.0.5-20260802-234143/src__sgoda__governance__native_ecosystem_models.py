"""Modelos de SGD-114E."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class NativeComponentRecord:
    code: str
    version: str
    native: bool
    mandatory_proprietary_dependencies: tuple[str, ...]
    technologies: tuple[str, ...]
    metadata: dict[str, Any]


@dataclass(frozen=True, slots=True)
class NativePolicyFinding:
    rule_code: str
    passed: bool
    blocking: bool
    message: str
    path: str | None = None
    remediation: str = ""


@dataclass(frozen=True, slots=True)
class NativePolicyResult:
    approved: bool
    exit_code: int
    component_count: int
    findings: tuple[NativePolicyFinding, ...]
    forbidden_term_count: int
    proprietary_dependency_count: int