from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .deliverable_classifier import ClassifiedDeliverable


@dataclass(frozen=True, slots=True)
class SourceTrace:
    path: str
    source_type: str
    tracked: bool
    exists: bool


@dataclass(frozen=True, slots=True)
class DeliverableTraceability:
    code: str
    family: str
    classification: str
    confidence: int
    traces: tuple[SourceTrace, ...]

    @property
    def tracked_source_count(self) -> int:
        return sum(1 for trace in self.traces if trace.tracked)

    @property
    def missing_source_count(self) -> int:
        return sum(1 for trace in self.traces if not trace.exists)


class SourceTraceabilityResolver:
    def __init__(self, repository_root: str | Path) -> None:
        self.repository_root = Path(repository_root).resolve()

    @staticmethod
    def source_type(path: str) -> str:
        lower = path.lower()

        if lower.startswith("releases/"):
            return "RELEASE"
        if lower.startswith("artifacts/pmo/"):
            return "PMO_EVIDENCE"
        if lower.startswith("artifacts/institutional/"):
            return "INSTITUTIONAL_EVIDENCE"
        if lower.startswith("docs/00_estado_maestro/"):
            return "MASTER_STATE"
        if lower.startswith("docs/07_actas/"):
            return "ACTA"
        if lower.startswith("docs/"):
            return "DOCUMENTATION"
        if lower.startswith("tests/") or "/tests/" in lower:
            return "TEST"
        if lower.startswith("src/") or lower.startswith("builder/src/"):
            return "CODE"
        if lower.startswith("tools/"):
            return "TOOL"
        return "OTHER"

    def _tracked_paths(self) -> frozenset[str]:
        completed = subprocess.run(
            [
                "git",
                "-c",
                "core.quotepath=false",
                "ls-files",
            ],
            cwd=self.repository_root,
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

        return frozenset(
            line.strip()
            for line in completed.stdout.splitlines()
            if line.strip()
        )

    def resolve(
        self,
        item: ClassifiedDeliverable,
    ) -> DeliverableTraceability:
        tracked_paths = self._tracked_paths()

        traces = tuple(
            SourceTrace(
                path=path,
                source_type=self.source_type(path),
                tracked=path in tracked_paths,
                exists=(self.repository_root / Path(path)).is_file(),
            )
            for path in sorted(set(item.source_paths))
        )

        return DeliverableTraceability(
            code=item.code,
            family=item.family,
            classification=item.classification.value,
            confidence=item.confidence,
            traces=traces,
        )

    def resolve_many(
        self,
        items: Iterable[ClassifiedDeliverable],
    ) -> tuple[DeliverableTraceability, ...]:
        tracked_paths = self._tracked_paths()

        resolved: list[DeliverableTraceability] = []

        for item in items:
            traces = tuple(
                SourceTrace(
                    path=path,
                    source_type=self.source_type(path),
                    tracked=path in tracked_paths,
                    exists=(self.repository_root / Path(path)).is_file(),
                )
                for path in sorted(set(item.source_paths))
            )

            resolved.append(
                DeliverableTraceability(
                    code=item.code,
                    family=item.family,
                    classification=item.classification.value,
                    confidence=item.confidence,
                    traces=traces,
                )
            )

        return tuple(
            sorted(resolved, key=lambda value: (value.family, value.code))
        )