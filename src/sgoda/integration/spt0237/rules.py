from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


DEFAULT_DIMENSIONS = (
    "integrity",
    "missing_resources",
    "consistency",
    "nomenclature",
    "traceability",
    "quality",
    "institutional_conformity",
)


@dataclass(frozen=True)
class AuditPolicy:
    scope: tuple[str, ...]
    dimensions: tuple[str, ...]
    required_files_per_component: int = 1
    require_sha256: bool = True
    require_tests: bool = True
    require_documentation: bool = True
    fail_on_error: bool = True

    @classmethod
    def default(cls) -> "AuditPolicy":
        return cls(
            scope=tuple(f"SPT-023.{i}" for i in range(1, 7)),
            dimensions=DEFAULT_DIMENSIONS,
        )

    @classmethod
    def from_json(cls, path: str | Path) -> "AuditPolicy":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        return cls(
            scope=tuple(data.get("scope") or [f"SPT-023.{i}" for i in range(1, 7)]),
            dimensions=tuple(data.get("dimensions") or DEFAULT_DIMENSIONS),
            required_files_per_component=int(data.get("required_files_per_component", 1)),
            require_sha256=bool(data.get("require_sha256", True)),
            require_tests=bool(data.get("require_tests", True)),
            require_documentation=bool(data.get("require_documentation", True)),
            fail_on_error=bool(data.get("fail_on_error", True)),
        )
