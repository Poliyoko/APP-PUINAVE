<#
.SYNOPSIS
    Instala SGD-116 v1.0.0 — Roadmap Maestro Vivo del Ecosistema
    SGODA-PUINAVE.

.DESCRIPTION
    Este instalador único:
      - instala el módulo sgoda.roadmap;
      - descubre componentes registrados en config/**;
      - descubre pruebas, documentos, releases, scripts y artefactos;
      - construye el grafo de dependencias;
      - calcula métricas ejecutivas;
      - genera timeline y roadmap institucional;
      - genera documentos maestros Markdown;
      - genera dashboards JSON;
      - valida rutas, duplicados, dependencias y consistencia;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - ejecuta quality gate SGD-114;
      - actualiza documentación maestra SGD-115;
      - publica release técnico y evidencias.

    No realiza llamadas externas ni modifica Git de forma automática.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa; las pruebas específicas siempre se ejecutan.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
    $Info = Get-Item -LiteralPath $Path
    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }
    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)
    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        (($Data | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\roadmap"
$TestsDir = Join-Path $ProjectRoot "tests\roadmap"
$ConfigDir = Join-Path $ProjectRoot "config\roadmap"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SGD-116"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\roadmap\SGD-116"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-116"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-116-v1.0.0"

$ModelsPath = Join-Path $SourceDir "models.py"
$DiscoveryPath = Join-Path $SourceDir "discovery.py"
$GraphPath = Join-Path $SourceDir "dependency_graph.py"
$MetricsPath = Join-Path $SourceDir "metrics.py"
$TimelinePath = Join-Path $SourceDir "timeline.py"
$GeneratorPath = Join-Path $SourceDir "generator.py"
$ValidatorPath = Join-Path $SourceDir "validator.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SGD_116_master_ecosystem_roadmap.py"

$PolicyPath = Join-Path $ConfigDir "SGD-116-roadmap-policy.json"
$PhasesPath = Join-Path $ConfigDir "SGD-116-phases.json"
$ComponentPath = Join-Path $ConfigDir "SGD-116-component.json"

$DocPath = Join-Path $DocsDir "SGD-116-Roadmap-Maestro-Vivo.md"
$ArchitectureDocPath = Join-Path $DocsDir "SGD-116-Arquitectura-Descubrimiento.md"
$OperationsDocPath = Join-Path $DocsDir "SGD-116-Operacion-y-Regeneracion.md"

$InvokePath = Join-Path $ScriptsDir "Invoke-SGD116-MasterRoadmap.ps1"
$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SGD-116.json"
$GatePath = Join-Path $PmoDir "SGD-116-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SGD-116-dashboard.json"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "src\sgoda\installer_builder\generator.py"),
    (Join-Path $ProjectRoot "docs\00_INDICE_MAESTRO.md"),
    (Join-Path $ProjectRoot "docs\00_ARQUITECTURA_MAESTRA.md"),
    (Join-Path $ProjectRoot "docs\00_REGISTRO_MAESTRO_COMPONENTES.md"),
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot ".git")
)) {
    Assert-Path -Path $Required -Description $Required
}

$GitStatus = @(git status --porcelain | Where-Object { $_ })
$AllowedPatterns = @(
    '^\?\? Install-SGD116-Master-Ecosystem-Roadmap\.ps1$',
    '^\?\? Repair-SGD116-v[0-9.]+-.*\.ps1$',
    '^\?\? SGD116-.*\.zip$',
    '^\?\? LEAME-SGD116.*\.txt$'
)

$Unexpected = @(
    foreach ($Entry in $GitStatus) {
        $Allowed = $false
        foreach ($Pattern in $AllowedPatterns) {
            if ($Entry -match $Pattern) {
                $Allowed = $true
                break
            }
        }
        if (-not $Allowed) { $Entry }
    }
)

if ($Unexpected.Count -gt 0) {
    $Unexpected | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }
    throw "La línea base contiene cambios ajenos a SGD-116."
}

$ModelsContent = @'
"""Modelos del Roadmap Maestro Vivo."""

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
    dependency_cycles: list[list[str]]
    missing_master_documents: list[str]
    generated_at_utc: str
'@

$DiscoveryContent = @'
"""Descubrimiento automático de componentes y activos."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .models import ComponentRecord


COMPONENT_PATTERN = re.compile(
    r"^(ADR|SGD|SPB|SPT|SIB|MMGR)-[0-9]+(?:\.[0-9]+)?[A-Z]?$"
)


def _list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item).replace("\\", "/") for item in value]
    if isinstance(value, str) and value.strip():
        return [value.replace("\\", "/")]
    return []


def infer_phase(code: str, component_type: str) -> str:
    if code.startswith(("SGD-", "ADR-")):
        return "Gobierno y arquitectura"
    if code.startswith(("SPB-", "SIB-", "MMGR-")):
        return "Plataforma y construcción"
    if code.startswith("SPT-001"):
        return "Repositorio Léxico Base"
    if code.startswith("SPT-002"):
        return "Objetos Digitales de Aprendizaje"
    if code.startswith("SPT-003"):
        return "Automatización multimedia"
    if code.startswith("SPT-004"):
        return "Asistente e integraciones"
    if code.startswith("SPT-005"):
        return "Identidad cultural"
    if code.startswith("SPT-006"):
        return "Motor multilingüe y multimedia"
    return component_type or "Evolución futura"


def discover_components(root: str | Path) -> list[ComponentRecord]:
    repository = Path(root)
    records: list[ComponentRecord] = []

    for path in sorted(repository.glob("config/**/*component*.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            continue

        code = str(
            payload.get("increment_code")
            or payload.get("code")
            or payload.get("component_code")
            or ""
        ).strip()

        if not code or not COMPONENT_PATTERN.match(code):
            continue

        name = str(
            payload.get("name")
            or payload.get("component_name")
            or code
        ).strip()

        component_type = str(
            payload.get("component_type")
            or payload.get("type")
            or "unspecified"
        ).strip()

        dependencies = _list(
            payload.get("dependencies")
            or payload.get("depends_on")
            or payload.get("governed_by")
        )

        release_candidate = repository / "releases"
        release_matches = sorted(
            release_candidate.glob(f"{code}-v*")
        )
        release_path = (
            release_matches[-1].relative_to(repository).as_posix()
            if release_matches
            else None
        )

        records.append(
            ComponentRecord(
                code=code,
                name=name,
                version=str(payload.get("version", "0.0.0")),
                status=str(
                    payload.get("status", "registered")
                ),
                component_type=component_type,
                phase=str(
                    payload.get("phase")
                    or infer_phase(code, component_type)
                ),
                dependencies=dependencies,
                source_paths=_list(
                    payload.get("source")
                    or payload.get("source_paths")
                ),
                test_paths=_list(
                    payload.get("tests")
                    or payload.get("test_paths")
                ),
                documentation_paths=_list(
                    payload.get("documentation")
                    or payload.get("documents")
                ),
                release_path=release_path,
                config_path=path.relative_to(
                    repository
                ).as_posix(),
                metadata={
                    "raw_status": payload.get("status"),
                },
            )
        )

    deduplicated: dict[str, ComponentRecord] = {}
    for record in records:
        previous = deduplicated.get(record.code)
        if previous is None:
            deduplicated[record.code] = record
            continue
        if record.version >= previous.version:
            deduplicated[record.code] = record

    return sorted(
        deduplicated.values(),
        key=lambda item: item.code,
    )


def discover_repository_assets(root: str | Path) -> dict:
    repository = Path(root)

    return {
        "test_files": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("tests/**/*.py")
            if path.name.startswith("test")
        ),
        "documents": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("docs/**/*")
            if path.is_file()
        ),
        "releases": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("releases/*")
            if path.is_dir()
        ),
        "scripts": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("scripts/*.ps1")
        ),
        "source_files": sorted(
            path.relative_to(repository).as_posix()
            for path in repository.glob("src/**/*.py")
        ),
    }
'@

$GraphContent = @'
"""Construcción y validación del grafo de dependencias."""

from __future__ import annotations

from .models import ComponentRecord, DependencyGraph


def _normalize_dependency(value: str) -> str:
    return value.strip().split()[0].rstrip(",;")


def build_dependency_graph(
    components: list[ComponentRecord],
) -> DependencyGraph:
    nodes = sorted({item.code for item in components})
    node_set = set(nodes)
    edges: list[dict[str, str]] = []
    missing: list[dict[str, str]] = []

    for component in components:
        for raw in component.dependencies:
            dependency = _normalize_dependency(raw)
            if not dependency:
                continue
            edge = {
                "source": component.code,
                "target": dependency,
            }
            edges.append(edge)
            if dependency not in node_set:
                missing.append(edge)

    adjacency: dict[str, list[str]] = {
        node: [] for node in nodes
    }
    for edge in edges:
        if edge["target"] in adjacency:
            adjacency[edge["source"]].append(edge["target"])

    cycles: list[list[str]] = []
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []

    def visit(node: str) -> None:
        if node in visiting:
            index = stack.index(node)
            cycle = stack[index:] + [node]
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

    unique_edges = {
        (item["source"], item["target"]): item
        for item in edges
    }

    return DependencyGraph(
        nodes=nodes,
        edges=sorted(
            unique_edges.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        missing_dependencies=sorted(
            missing,
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        cycles=cycles,
    )
'@

$MetricsContent = @'
"""Cálculo de métricas ejecutivas."""

from __future__ import annotations

from .models import ComponentRecord, EcosystemMetrics


IMPLEMENTED_STATES = {
    "implemented",
    "validated",
    "technically_completed",
    "completed",
    "closed",
    "published",
    "released",
}


def calculate_metrics(
    components: list[ComponentRecord],
    assets: dict,
) -> EcosystemMetrics:
    total = len(components)

    implemented = sum(
        1
        for item in components
        if item.status.lower() in IMPLEMENTED_STATES
    )
    released = sum(
        1 for item in components if item.release_path
    )
    documented = sum(
        1 for item in components if item.documentation_paths
    )
    tested = sum(
        1 for item in components if item.test_paths
    )

    def percent(value: int) -> float:
        return round(
            (value / total * 100.0) if total else 0.0,
            2,
        )

    return EcosystemMetrics(
        total_components=total,
        implemented_components=implemented,
        pending_components=max(total - implemented, 0),
        released_components=released,
        documented_components=documented,
        tested_components=tested,
        total_test_files=len(assets["test_files"]),
        total_documents=len(assets["documents"]),
        total_releases=len(assets["releases"]),
        completion_percent=percent(implemented),
        documentation_percent=percent(documented),
        test_coverage_percent=percent(tested),
    )
'@

$TimelineContent = @'
"""Timeline derivado de releases, configuración y Git."""

from __future__ import annotations

import subprocess
from pathlib import Path

from .models import ComponentRecord


def _git_date(root: Path, path: str | None) -> str | None:
    if not path:
        return None

    completed = subprocess.run(
        [
            "git",
            "log",
            "-1",
            "--format=%cI",
            "--",
            path,
        ],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )

    value = completed.stdout.strip()
    return value or None


def build_timeline(
    root: str | Path,
    components: list[ComponentRecord],
) -> list[dict]:
    repository = Path(root)
    timeline: list[dict] = []

    for item in components:
        reference = item.release_path or item.config_path
        timeline.append(
            {
                "code": item.code,
                "name": item.name,
                "phase": item.phase,
                "status": item.status,
                "version": item.version,
                "release": item.release_path,
                "last_git_date": _git_date(
                    repository,
                    reference,
                ),
            }
        )

    return sorted(
        timeline,
        key=lambda item: (
            item["last_git_date"] or "9999",
            item["code"],
        ),
    )
'@

$ValidatorContent = @'
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
'@

$GeneratorContent = @'
"""Generación del Roadmap Maestro Vivo."""

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
        json.dumps(payload, ensure_ascii=False, indent=2)
        + "\n",
        encoding="utf-8",
    )


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def _phase_markdown(components: list) -> str:
    groups: dict[str, list] = {}
    for item in components:
        groups.setdefault(item.phase, []).append(item)

    lines: list[str] = []

    for phase in sorted(groups):
        lines.extend((f"## {phase}", "", "| Código | Componente | Estado | Versión | Release |", "|---|---|---|---|---|"))
        for item in sorted(groups[phase], key=lambda value: value.code):
            release = item.release_path or "Pendiente"
            lines.append(
                f"| {item.code} | {item.name} | "
                f"{item.status} | {item.version} | {release} |"
            )
        lines.append("")

    return "\n".join(lines)


def generate_roadmap(
    root: str | Path,
    output_dir: str | Path,
) -> dict[str, Path]:
    repository = Path(root)
    output = Path(output_dir)

    components = discover_components(repository)
    assets = discover_repository_assets(repository)
    graph = build_dependency_graph(components)
    metrics = calculate_metrics(components, assets)
    timeline = build_timeline(repository, components)

    roadmap_payload = {
        "schema_version": "1.0",
        "generated_at_utc": datetime.now(
            timezone.utc
        ).isoformat(),
        "components": [asdict(item) for item in components],
        "phases": sorted({item.phase for item in components}),
    }

    paths = {
        "roadmap": output / "roadmap.json",
        "dependencies": output / "dependency-graph.json",
        "metrics": output / "metrics.json",
        "timeline": output / "timeline.json",
        "validation": output / "validation.json",
        "executive_summary": output / "executive-summary.json",
    }

    _write_json(paths["roadmap"], roadmap_payload)
    _write_json(paths["dependencies"], asdict(graph))
    _write_json(paths["metrics"], asdict(metrics))
    _write_json(paths["timeline"], timeline)

    roadmap_doc = repository / "docs/00_ROADMAP_MAESTRO.md"
    dependencies_doc = repository / "docs/00_DEPENDENCIAS_MAESTRAS.md"
    timeline_doc = repository / "docs/00_TIMELINE_MAESTRO.md"
    metrics_doc = repository / "docs/00_METRICAS_ECOSISTEMA.md"

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
        "| Componente | Depende de |",
        "|---|---|",
    ]
    dependency_lines.extend(
        f"| {edge['source']} | {edge['target']} |"
        for edge in graph.edges
    )
    if not graph.edges:
        dependency_lines.append(
            "| Sin dependencias declaradas | — |"
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
    timeline_lines.extend(
        "| {date} | {code} | {name} | {status} | {release} |".format(
            date=item["last_git_date"] or "No determinada",
            code=item["code"],
            name=item["name"],
            status=item["status"],
            release=item["release"] or "Pendiente",
        )
        for item in timeline
    )
    _write_text(timeline_doc, "\n".join(timeline_lines))

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
        f"- Cobertura declarada de pruebas: **{metrics.test_coverage_percent}%**",
    )

    validation = validate_roadmap(repository, components)
    _write_json(paths["validation"], asdict(validation))

    summary = {
        "generated_at_utc": roadmap_payload["generated_at_utc"],
        "status": "approved" if validation.passed else "rejected",
        "metrics": asdict(metrics),
        "validation": asdict(validation),
    }
    _write_json(paths["executive_summary"], summary)

    dashboard = repository / "dashboard"
    dashboard.mkdir(parents=True, exist_ok=True)

    for source, name in (
        (paths["roadmap"], "ecosystem-roadmap.json"),
        (paths["dependencies"], "dependency-graph.json"),
        (paths["metrics"], "ecosystem-metrics.json"),
        (paths["timeline"], "timeline.json"),
        (paths["executive_summary"], "executive-summary.json"),
    ):
        (dashboard / name).write_bytes(source.read_bytes())

    return {
        **paths,
        "roadmap_document": roadmap_doc,
        "dependencies_document": dependencies_doc,
        "timeline_document": timeline_doc,
        "metrics_document": metrics_doc,
    }
'@

$CliContent = @'
"""CLI institucional de SGD-116."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .generator import generate_roadmap


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--output",
        default="artifacts/roadmap/SGD-116",
    )
    args = parser.parse_args()

    paths = generate_roadmap(args.root, args.output)

    validation = json.loads(
        Path(paths["validation"]).read_text(
            encoding="utf-8"
        )
    )

    print("SGD-116 ejecutado correctamente.")
    print(
        "Componentes: "
        f"{validation['component_count']}"
    )
    print(
        "Validación: "
        f"{'APROBADA' if validation['passed'] else 'NO APROBADA'}"
    )
    print(f"Roadmap: {paths['roadmap']}")
    print(f"Dashboard: dashboard/ecosystem-roadmap.json")

    return 0 if validation["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Roadmap Maestro Vivo SGODA-PUINAVE."""

from .dependency_graph import build_dependency_graph
from .discovery import (
    discover_components,
    discover_repository_assets,
)
from .generator import generate_roadmap
from .metrics import calculate_metrics
from .timeline import build_timeline
from .validator import validate_roadmap

__all__ = [
    "build_dependency_graph",
    "build_timeline",
    "calculate_metrics",
    "discover_components",
    "discover_repository_assets",
    "generate_roadmap",
    "validate_roadmap",
]
'@

$TestContent = @'
"""Pruebas SGD-116."""

import json
from pathlib import Path

from sgoda.roadmap.dependency_graph import (
    build_dependency_graph,
)
from sgoda.roadmap.discovery import (
    discover_components,
    discover_repository_assets,
)
from sgoda.roadmap.generator import generate_roadmap
from sgoda.roadmap.metrics import calculate_metrics
from sgoda.roadmap.models import ComponentRecord
from sgoda.roadmap.validator import validate_roadmap


def _repository(tmp_path: Path) -> Path:
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "src/example").mkdir(parents=True)
    (root / "tests/example").mkdir(parents=True)
    (root / "docs").mkdir(parents=True)
    (root / "releases/SPT-900-v1.0.0").mkdir(parents=True)

    (root / "src/example/module.py").write_text(
        "VALUE = 1\n",
        encoding="utf-8",
    )
    (root / "tests/example/test_module.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )
    (root / "docs/example.md").write_text(
        "# Example\n",
        encoding="utf-8",
    )

    component = {
        "increment_code": "SPT-900",
        "name": "Componente de prueba",
        "version": "1.0.0",
        "status": "technically_completed",
        "component_type": "test_component",
        "dependencies": [],
        "source": ["src/example/module.py"],
        "tests": ["tests/example/test_module.py"],
        "documentation": ["docs/example.md"],
    }
    (root / "config/test/SPT-900-component.json").write_text(
        json.dumps(component),
        encoding="utf-8",
    )
    return root


def _master_documents(root: Path) -> None:
    for name in (
        "00_INDICE_MAESTRO.md",
        "00_ARQUITECTURA_MAESTRA.md",
        "00_REGISTRO_MAESTRO_COMPONENTES.md",
    ):
        (root / "docs" / name).write_text(
            f"# {name}\n",
            encoding="utf-8",
        )


def test_SGD_116_discovers_component(tmp_path):
    root = _repository(tmp_path)
    components = discover_components(root)
    assert [item.code for item in components] == ["SPT-900"]


def test_SGD_116_discovers_assets(tmp_path):
    assets = discover_repository_assets(
        _repository(tmp_path)
    )
    assert len(assets["test_files"]) == 1
    assert len(assets["documents"]) == 1
    assert len(assets["releases"]) == 1


def test_SGD_116_builds_dependency_graph():
    components = [
        ComponentRecord(
            code="SPT-901",
            name="A",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
            dependencies=["SPT-900"],
        ),
        ComponentRecord(
            code="SPT-900",
            name="B",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
        ),
    ]
    graph = build_dependency_graph(components)
    assert graph.edges == [
        {"source": "SPT-901", "target": "SPT-900"}
    ]
    assert graph.missing_dependencies == []


def test_SGD_116_detects_missing_dependency():
    components = [
        ComponentRecord(
            code="SPT-901",
            name="A",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
            dependencies=["SPT-999"],
        )
    ]
    graph = build_dependency_graph(components)
    assert graph.missing_dependencies


def test_SGD_116_detects_cycle():
    components = [
        ComponentRecord(
            code="SPT-900",
            name="A",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
            dependencies=["SPT-901"],
        ),
        ComponentRecord(
            code="SPT-901",
            name="B",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
            dependencies=["SPT-900"],
        ),
    ]
    assert build_dependency_graph(components).cycles


def test_SGD_116_calculates_metrics(tmp_path):
    root = _repository(tmp_path)
    components = discover_components(root)
    assets = discover_repository_assets(root)
    metrics = calculate_metrics(components, assets)
    assert metrics.total_components == 1
    assert metrics.completion_percent == 100.0
    assert metrics.total_releases == 1


def test_SGD_116_generates_master_documents(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    generate_roadmap(root, root / "artifacts/roadmap/SGD-116")
    assert (root / "docs/00_ROADMAP_MAESTRO.md").is_file()
    assert (root / "docs/00_DEPENDENCIAS_MAESTRAS.md").is_file()
    assert (root / "docs/00_TIMELINE_MAESTRO.md").is_file()
    assert (root / "docs/00_METRICAS_ECOSISTEMA.md").is_file()


def test_SGD_116_generates_dashboard(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    generate_roadmap(root, root / "artifacts/roadmap/SGD-116")
    assert (root / "dashboard/ecosystem-roadmap.json").is_file()
    assert (root / "dashboard/ecosystem-metrics.json").is_file()
    assert (root / "dashboard/dependency-graph.json").is_file()


def test_SGD_116_validation_passes(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    generate_roadmap(root, root / "artifacts/roadmap/SGD-116")
    components = discover_components(root)
    result = validate_roadmap(root, components)
    assert result.passed is True


def test_SGD_116_validation_detects_broken_path(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    generate_roadmap(root, root / "artifacts/roadmap/SGD-116")
    (root / "src/example/module.py").unlink()
    result = validate_roadmap(
        root,
        discover_components(root),
    )
    assert result.passed is False
    assert result.broken_paths


def test_SGD_116_executive_summary_is_approved(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    paths = generate_roadmap(
        root,
        root / "artifacts/roadmap/SGD-116",
    )
    summary = json.loads(
        Path(paths["executive_summary"]).read_text(
            encoding="utf-8"
        )
    )
    assert summary["status"] == "approved"


def test_SGD_116_is_idempotent(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    output = root / "artifacts/roadmap/SGD-116"
    generate_roadmap(root, output)
    first = (output / "roadmap.json").read_text(
        encoding="utf-8"
    )
    generate_roadmap(root, output)
    second = (output / "roadmap.json").read_text(
        encoding="utf-8"
    )
    first_payload = json.loads(first)
    second_payload = json.loads(second)
    first_payload.pop("generated_at_utc")
    second_payload.pop("generated_at_utc")
    assert first_payload == second_payload
'@

$PolicyContent = @'
{
  "increment_code": "SGD-116",
  "version": "1.0.0",
  "policy_name": "Roadmap Maestro Vivo del Ecosistema SGODA-PUINAVE",
  "repository_is_source_of_truth": true,
  "automatic_discovery": true,
  "generate_master_documents": true,
  "generate_dashboards": true,
  "validate_dependencies": true,
  "block_dependency_cycles": true,
  "block_missing_dependencies": true,
  "block_broken_paths": true,
  "update_sgd_115": true,
  "quality_gate_required": true,
  "publication_via_spb_007": true,
  "master_documents": [
    "docs/00_ROADMAP_MAESTRO.md",
    "docs/00_DEPENDENCIAS_MAESTRAS.md",
    "docs/00_TIMELINE_MAESTRO.md",
    "docs/00_METRICAS_ECOSISTEMA.md"
  ],
  "dashboards": [
    "dashboard/ecosystem-roadmap.json",
    "dashboard/ecosystem-metrics.json",
    "dashboard/dependency-graph.json",
    "dashboard/timeline.json",
    "dashboard/executive-summary.json"
  ]
}
'@

$PhasesContent = @'
{
  "phases": [
    {
      "id": "governance",
      "name": "Gobierno y arquitectura",
      "prefixes": ["SGD-", "ADR-"]
    },
    {
      "id": "platform",
      "name": "Plataforma y construcción",
      "prefixes": ["SPB-", "SIB-", "MMGR-"]
    },
    {
      "id": "rlb",
      "name": "Repositorio Léxico Base",
      "prefixes": ["SPT-001"]
    },
    {
      "id": "oda",
      "name": "Objetos Digitales de Aprendizaje",
      "prefixes": ["SPT-002"]
    },
    {
      "id": "automation",
      "name": "Automatización multimedia",
      "prefixes": ["SPT-003"]
    },
    {
      "id": "assistant",
      "name": "Asistente e integraciones",
      "prefixes": ["SPT-004"]
    },
    {
      "id": "identity",
      "name": "Identidad cultural",
      "prefixes": ["SPT-005"]
    },
    {
      "id": "language",
      "name": "Motor multilingüe y multimedia",
      "prefixes": ["SPT-006"]
    }
  ]
}
'@

$ComponentContent = @'
{
  "increment_code": "SGD-116",
  "name": "Roadmap Maestro Vivo del Ecosistema SGODA-PUINAVE",
  "component_type": "living_master_ecosystem_roadmap",
  "version": "1.0.0",
  "status": "technically_completed",
  "dependencies": [
    "SGD-114",
    "SGD-115",
    "SPB-007",
    "SIB-001"
  ],
  "source": [
    "src/sgoda/roadmap/models.py",
    "src/sgoda/roadmap/discovery.py",
    "src/sgoda/roadmap/dependency_graph.py",
    "src/sgoda/roadmap/metrics.py",
    "src/sgoda/roadmap/timeline.py",
    "src/sgoda/roadmap/generator.py",
    "src/sgoda/roadmap/validator.py",
    "src/sgoda/roadmap/cli.py"
  ],
  "tests": [
    "tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SGD-116/SGD-116-Roadmap-Maestro-Vivo.md",
    "docs/05_Fase_Tecnologica/SGD-116/SGD-116-Arquitectura-Descubrimiento.md",
    "docs/05_Fase_Tecnologica/SGD-116/SGD-116-Operacion-y-Regeneracion.md"
  ]
}
'@

$DocContent = @'
# SGD-116 — Roadmap Maestro Vivo

SGD-116 convierte el repositorio SGODA-PUINAVE en la fuente institucional
de verdad para el estado del ecosistema.

El componente descubre automáticamente configuraciones, código, pruebas,
documentos, releases y dependencias. Luego genera el Roadmap Maestro,
el timeline, las métricas, el grafo de dependencias y los dashboards.

No sustituye SGD-115: lo complementa y utiliza sus documentos maestros
como línea base documental.
'@

$ArchitectureDocContent = @'
# SGD-116 — Arquitectura de Descubrimiento

El descubrimiento se realiza sobre archivos `*component*.json` ubicados
bajo `config/`. Cada registro puede declarar código, nombre, versión,
estado, dependencias, fuentes, pruebas, documentación y release.

El grafo bloquea dependencias faltantes y ciclos. Las rutas declaradas
también deben existir en el repositorio.
'@

$OperationsDocContent = @'
# SGD-116 — Operación y Regeneración

## Regeneración

```powershell
.\scripts\Invoke-SGD116-MasterRoadmap.ps1
```

## Validaciones

La ejecución falla cuando encuentra:

- códigos duplicados;
- rutas rotas;
- dependencias faltantes;
- ciclos de dependencias;
- documentos maestros ausentes.

Después de regenerar y revisar, el incremento debe publicarse mediante
SPB-007.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [string]$Output = "artifacts/roadmap/SGD-116"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.roadmap.cli `
    --root "." `
    --output $Output

if ($LASTEXITCODE -ne 0) {
    throw "SGD-116 terminó con errores."
}
'@

Write-Step "Instalando SGD-116"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $DiscoveryPath -Content $DiscoveryContent
Write-Utf8NoBom -Path $GraphPath -Content $GraphContent
Write-Utf8NoBom -Path $MetricsPath -Content $MetricsContent
Write-Utf8NoBom -Path $TimelinePath -Content $TimelineContent
Write-Utf8NoBom -Path $GeneratorPath -Content $GeneratorContent
Write-Utf8NoBom -Path $ValidatorPath -Content $ValidatorContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent

Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $PhasesPath -Content $PhasesContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent

Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $ArchitectureDocPath -Content $ArchitectureDocContent
Write-Utf8NoBom -Path $OperationsDocPath -Content $OperationsDocContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad inicial"

Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SGD-116"
    version = "1.0.0"
    status = "implemented"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    repository_source_of_truth = $true
    automatic_discovery = $true
    dependency_graph = $true
    timeline = $true
    executive_metrics = $true
    master_documents = 4
    dashboards = 5
})

Write-JsonUtf8 -Path $TracePath -Data ([ordered]@{
    increment_code = "SGD-116"
    source = @("src/sgoda/roadmap/")
    tests = @(
        "tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py"
    )
    configuration = @(
        "config/roadmap/SGD-116-roadmap-policy.json",
        "config/roadmap/SGD-116-phases.json",
        "config/roadmap/SGD-116-component.json"
    )
})

Write-Step "Validando sintaxis e importaciones"

& python -m py_compile `
    "src/sgoda/roadmap/models.py" `
    "src/sgoda/roadmap/discovery.py" `
    "src/sgoda/roadmap/dependency_graph.py" `
    "src/sgoda/roadmap/metrics.py" `
    "src/sgoda/roadmap/timeline.py" `
    "src/sgoda/roadmap/generator.py" `
    "src/sgoda/roadmap/validator.py" `
    "src/sgoda/roadmap/cli.py"

if ($LASTEXITCODE -ne 0) {
    throw "La compilación SGD-116 falló."
}

& python -c "from sgoda.roadmap import discover_components, generate_roadmap, validate_roadmap; print(discover_components.__name__, generate_roadmap.__name__, validate_roadmap.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "La importación SGD-116 falló."
}

Write-Step "Ejecutando 12 pruebas específicas SGD-116"

& python -m pytest `
    "tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SGD-116 fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Generando Roadmap Maestro real"

& python -m sgoda.roadmap.cli `
    --root "$ProjectRoot" `
    --output "artifacts/roadmap/SGD-116"

if ($LASTEXITCODE -ne 0) {
    throw "La generación real de SGD-116 falló."
}

$ValidationPath = Join-Path $ArtifactsDir "validation.json"
$MetricsOutputPath = Join-Path $ArtifactsDir "metrics.json"
Assert-Path -Path $ValidationPath -Description "validation.json"
Assert-Path -Path $MetricsOutputPath -Description "metrics.json"

$Validation = Get-Content -LiteralPath $ValidationPath -Raw | ConvertFrom-Json
$Metrics = Get-Content -LiteralPath $MetricsOutputPath -Raw | ConvertFrom-Json

if (-not $Validation.passed) {
    throw "La validación real del Roadmap Maestro no fue aprobada."
}

Write-Step "Publicando release técnico"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Artifact in @(
    $PolicyPath,
    $PhasesPath,
    $ComponentPath,
    $DocPath,
    $ArchitectureDocPath,
    $OperationsDocPath,
    (Join-Path $ArtifactsDir "roadmap.json"),
    (Join-Path $ArtifactsDir "dependency-graph.json"),
    (Join-Path $ArtifactsDir "timeline.json"),
    (Join-Path $ArtifactsDir "metrics.json"),
    (Join-Path $ArtifactsDir "validation.json"),
    (Join-Path $ArtifactsDir "executive-summary.json")
)) {
    Copy-Item `
        -LiteralPath $Artifact `
        -Destination (Join-Path $ReleaseDir (Split-Path $Artifact -Leaf)) `
        -Force
}

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SGD-116" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SGD-116 no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw | ConvertFrom-Json
if (-not $Gate.passed) {
    throw "El quality gate no contiene passed=true."
}

Write-JsonUtf8 -Path $DashboardPath -Data ([ordered]@{
    increment_code = "SGD-116"
    version = "1.0.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    total_components = $Metrics.total_components
    implemented_components = $Metrics.implemented_components
    pending_components = $Metrics.pending_components
    total_releases = $Metrics.total_releases
    total_test_files = $Metrics.total_test_files
    total_documents = $Metrics.total_documents
    completion_percent = $Metrics.completion_percent
    validation = "approved"
    specific_tests = 12
    quality_gate = "approved"
    release = "SGD-116-v1.0.0"
})

Write-Step "Actualizando documentación maestra SGD-115"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La actualización SGD-115 falló."
}

Write-Step "Resultado final"

Write-Host "SGD-116 v1.0.0 implementado y validado." -ForegroundColor Green
Write-Host "Roadmap Maestro Vivo: OPERATIVO." -ForegroundColor Green
Write-Host "Descubrimiento automático: APROBADO." -ForegroundColor Green
Write-Host "Grafo de dependencias: APROBADO." -ForegroundColor Green
Write-Host "Timeline Maestro: GENERADO." -ForegroundColor Green
Write-Host "Métricas ejecutivas: GENERADAS." -ForegroundColor Green
Write-Host "Dashboards: GENERADOS." -ForegroundColor Green
Write-Host "Componentes descubiertos: $($Metrics.total_components)" -ForegroundColor Cyan
Write-Host "Componentes implementados: $($Metrics.implemented_components)" -ForegroundColor Cyan
Write-Host "Releases detectados: $($Metrics.total_releases)" -ForegroundColor Cyan
Write-Host "Archivos de prueba: $($Metrics.total_test_files)" -ForegroundColor Cyan
Write-Host "Documentos: $($Metrics.total_documents)" -ForegroundColor Cyan
Write-Host "Avance institucional: $($Metrics.completion_percent)%" -ForegroundColor Cyan
Write-Host "Pruebas específicas: 12 APROBADAS." -ForegroundColor Green
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SGD-116-v1.0.0" -ForegroundColor Cyan

Write-Host ""
Write-Host "Después revise git status y publique mediante SPB-007." -ForegroundColor Yellow
