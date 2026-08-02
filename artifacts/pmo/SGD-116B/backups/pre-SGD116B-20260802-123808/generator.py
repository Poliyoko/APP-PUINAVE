"""Generación definitiva de SGD-116."""

from __future__ import annotations

import json
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

from .dependency_graph import build_dependency_graph
from .discovery import (
    discover_components,
    discover_repository_assets,
)
from .metrics import calculate_metrics
from .timeline import build_timeline
from .validator import validate_roadmap


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            payload,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        content.rstrip() + "\n",
        encoding="utf-8",
    )


def _phase_markdown(components: list) -> str:
    groups: dict[str, list] = {}
    for item in components:
        groups.setdefault(item.phase, []).append(item)

    lines: list[str] = []

    for phase in sorted(groups):
        lines.extend(
            (
                f"## {phase}",
                "",
                "| Código | Componente | Estado | Versión | Release |",
                "|---|---|---|---|---|",
            )
        )

        for item in sorted(
            groups[phase],
            key=lambda value: value.code,
        ):
            lines.append(
                f"| {item.code} | {item.name} | "
                f"{item.status} | {item.version} | "
                f"{item.release_path or 'Pendiente'} |"
            )

        lines.append("")

    return "\n".join(lines)


def generate_roadmap(
    root: str | Path,
    output_dir: str | Path,
) -> dict[str, Path]:
    repository = Path(root)
    output = Path(output_dir)

    output.mkdir(parents=True, exist_ok=True)

    for stale_name in (
        "roadmap.json",
        "dependency-graph.json",
        "metrics.json",
        "timeline.json",
        "validation.json",
        "executive-summary.json",
    ):
        stale = output / stale_name
        if stale.exists():
            stale.unlink()

    components = discover_components(repository)
    assets = discover_repository_assets(repository)
    graph = build_dependency_graph(components)
    metrics = calculate_metrics(components, assets)
    timeline = build_timeline(repository, components)

    generated_at = datetime.now(
        timezone.utc
    ).isoformat()

    paths = {
        "roadmap": output / "roadmap.json",
        "dependencies": output / "dependency-graph.json",
        "metrics": output / "metrics.json",
        "timeline": output / "timeline.json",
        "validation": output / "validation.json",
        "executive_summary": output / "executive-summary.json",
    }

    _write_json(
        paths["roadmap"],
        {
            "schema_version": "1.1",
            "generated_at_utc": generated_at,
            "components": [
                asdict(item) for item in components
            ],
            "phases": sorted(
                {item.phase for item in components}
            ),
        },
    )
    _write_json(
        paths["dependencies"],
        asdict(graph),
    )
    _write_json(
        paths["metrics"],
        asdict(metrics),
    )
    _write_json(paths["timeline"], timeline)

    roadmap_doc = repository / "docs/00_ROADMAP_MAESTRO.md"
    dependencies_doc = (
        repository / "docs/00_DEPENDENCIAS_MAESTRAS.md"
    )
    timeline_doc = (
        repository / "docs/00_TIMELINE_MAESTRO.md"
    )
    metrics_doc = (
        repository / "docs/00_METRICAS_ECOSISTEMA.md"
    )

    _write_text(
        roadmap_doc,
        "# Roadmap Maestro del Ecosistema SGODA-PUINAVE\n\n"
        "> Documento generado automáticamente por SGD-116.\n\n"
        f"Componentes registrados: **{metrics.total_components}**  \n"
        f"Avance institucional: **{metrics.completion_percent}%**\n\n"
        + _phase_markdown(components),
    )

    dependency_lines = [
        "# Dependencias Maestras",
        "",
        "> Documento generado automáticamente por SGD-116.",
        "",
        "| Componente | Depende de | Clasificación |",
        "|---|---|---|",
    ]

    historical_keys = {
        (item["source"], item["target"])
        for item in graph.historical_dependencies
    }

    for edge in graph.edges:
        classification = (
            "Histórica resuelta"
            if (
                edge["source"],
                edge["target"],
            ) in historical_keys
            else "Interna"
        )
        dependency_lines.append(
            f"| {edge['source']} | {edge['target']} | "
            f"{classification} |"
        )

    if not graph.edges:
        dependency_lines.append(
            "| Sin dependencias declaradas | — | — |"
        )

    _write_text(
        dependencies_doc,
        "\n".join(dependency_lines),
    )

    timeline_lines = [
        "# Timeline Maestro",
        "",
        "> Documento generado automáticamente por SGD-116.",
        "",
        "| Fecha Git | Código | Componente | Estado | Release |",
        "|---|---|---|---|---|",
    ]

    for item in timeline:
        timeline_lines.append(
            "| {date} | {code} | {name} | {status} | {release} |".format(
                date=item["last_git_date"] or "No determinada",
                code=item["code"],
                name=item["name"],
                status=item["status"],
                release=item["release"] or "Pendiente",
            )
        )

    _write_text(
        timeline_doc,
        "\n".join(timeline_lines),
    )

    _write_text(
        metrics_doc,
        "# Métricas del Ecosistema\n\n"
        "> Documento generado automáticamente por SGD-116.\n\n"
        f"- Componentes: **{metrics.total_components}**\n"
        f"- Implementados: **{metrics.implemented_components}**\n"
        f"- Pendientes: **{metrics.pending_components}**\n"
        f"- Releases: **{metrics.total_releases}**\n"
        f"- Archivos de prueba: **{metrics.total_test_files}**\n"
        f"- Documentos: **{metrics.total_documents}**\n"
        f"- Avance: **{metrics.completion_percent}%**\n"
        f"- Cobertura documental: **{metrics.documentation_percent}%**\n"
        f"- Cobertura declarada de pruebas: "
        f"**{metrics.test_coverage_percent}%**",
    )

    validation = validate_roadmap(
        repository,
        components,
    )
    _write_json(
        paths["validation"],
        asdict(validation),
    )

    summary = {
        "generated_at_utc": generated_at,
        "status": (
            "approved"
            if validation.passed
            else "rejected"
        ),
        "metrics": asdict(metrics),
        "validation": asdict(validation),
    }
    _write_json(
        paths["executive_summary"],
        summary,
    )

    dashboard = repository / "dashboard"
    dashboard.mkdir(parents=True, exist_ok=True)

    for source, name in (
        (paths["roadmap"], "ecosystem-roadmap.json"),
        (paths["dependencies"], "dependency-graph.json"),
        (paths["metrics"], "ecosystem-metrics.json"),
        (paths["timeline"], "timeline.json"),
        (
            paths["executive_summary"],
            "executive-summary.json",
        ),
    ):
        (dashboard / name).write_bytes(
            source.read_bytes()
        )

    return {
        **paths,
        "roadmap_document": roadmap_doc,
        "dependencies_document": dependencies_doc,
        "timeline_document": timeline_doc,
        "metrics_document": metrics_doc,
    }