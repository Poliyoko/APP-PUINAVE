"""Validación institucional de SGD-116."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from .dependency_graph import build_dependency_graph
from .models import ComponentRecord, ValidationResult


MASTER_DOCUMENTS = (
    "docs/00_INDICE_MAESTRO.md",
    "docs/00_ARQUITECTURA_MAESTRA.md",
    "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
    "docs/00_ROADMAP_MAESTRO.md",
    "docs/00_DEPENDENCIAS_MAESTRAS.md",
    "docs/00_TIMELINE_MAESTRO.md",
    "docs/00_METRICAS_ECOSISTEMA.md",
)


def validate_roadmap(
    root: str | Path,
    components: list[ComponentRecord],
) -> ValidationResult:
    repository = Path(root)
    counts: dict[str, int] = {}

    for item in components:
        counts[item.code] = counts.get(item.code, 0) + 1

    duplicate_codes = sorted(
        code for code, count in counts.items() if count > 1
    )

    broken_paths: list[str] = []
    for item in components:
        for value in (
            item.source_paths
            + item.test_paths
            + item.documentation_paths
        ):
            clean = value.rstrip("/")
            if clean and not (repository / clean).exists():
                broken_paths.append(
                    f"{item.code}:{clean}"
                )

    graph = build_dependency_graph(components)

    missing_master_documents = [
        path
        for path in MASTER_DOCUMENTS
        if not (repository / path).is_file()
    ]

    passed = not any(
        (
            duplicate_codes,
            broken_paths,
            graph.missing_dependencies,
            graph.cycles,
            missing_master_documents,
        )
    )

    return ValidationResult(
        passed=passed,
        component_count=len(components),
        duplicate_codes=duplicate_codes,
        broken_paths=sorted(set(broken_paths)),
        missing_dependencies=graph.missing_dependencies,
        dependency_cycles=graph.cycles,
        missing_master_documents=missing_master_documents,
        generated_at_utc=datetime.now(
            timezone.utc
        ).isoformat(),
    )