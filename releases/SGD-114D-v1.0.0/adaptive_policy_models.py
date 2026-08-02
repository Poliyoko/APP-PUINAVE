"""Modelos de SGD-114D."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class ResolvedArtifact:
    artifact_type: str
    increment_code: str
    path: Path | None
    found: bool
    strategy: str
    candidates: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class AdaptiveRuleResult:
    rule_code: str
    name: str
    passed: bool
    blocking: bool
    message: str
    remediation: str
    evidence: tuple[str, ...] = ()
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class AdaptivePolicyResult:
    increment_code: str
    approved: bool
    exit_code: int
    results: tuple[AdaptiveRuleResult, ...]
    evidence_path: str | None
    release_path: str | None