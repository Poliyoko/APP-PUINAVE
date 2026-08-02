<#
.SYNOPSIS
    Corrige y cierra definitivamente SGD-116 — Roadmap Maestro Vivo.

.DESCRIPTION
    SGD-116 v1.1.0 reemplaza la resolución parcial de dependencias por una
    resolución institucional completa:

      - normaliza códigos con sufijos de versión;
      - descubre componentes desde todos los descriptores JSON;
      - reconoce componentes históricos por evidencia real;
      - crea anclas canónicas únicamente cuando existe evidencia;
      - distingue dependencias internas, históricas y realmente inexistentes;
      - evita falsos positivos por versiones como SGD-114-v2.0.1;
      - regenera documentos, dashboards y artefactos;
      - reemplaza validation.json para evitar evidencia obsoleta;
      - agrega pruebas de regresión;
      - ejecuta suite específica y suite completa;
      - publica release correctivo;
      - ejecuta quality gate;
      - actualiza SGD-115.

    No elimina evidencias históricas ni modifica Git automáticamente.

.PARAMETER ProjectRoot
    Raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.
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
    Write-Host "Corregido: $Path ($($Info.Length) bytes)" -ForegroundColor Green
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

$RoadmapDir = Join-Path $ProjectRoot "src\sgoda\roadmap"
$ModelsPath = Join-Path $RoadmapDir "models.py"
$DiscoveryPath = Join-Path $RoadmapDir "discovery.py"
$GraphPath = Join-Path $RoadmapDir "dependency_graph.py"
$ValidatorPath = Join-Path $RoadmapDir "validator.py"
$GeneratorPath = Join-Path $RoadmapDir "generator.py"
$CliPath = Join-Path $RoadmapDir "cli.py"
$TestPath = Join-Path $ProjectRoot "tests\roadmap\test_SGD_116_master_ecosystem_roadmap.py"

$ArtifactsDir = Join-Path $ProjectRoot "artifacts\roadmap\SGD-116"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-116"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-116-v1.1.0"
$BackupDir = Join-Path $PmoDir ("backups\v1.1.0-" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss"))
$EvidencePath = Join-Path $PmoDir "SGD-116-v1.1.0-definitive-closure.json"
$GatePath = Join-Path $PmoDir "SGD-116-v1.1.0-quality-gate.json"
$ValidationPath = Join-Path $ArtifactsDir "validation.json"
$MetricsPath = Join-Path $ArtifactsDir "metrics.json"

Write-Step "Validando instalación parcial SGD-116"

foreach ($Required in @(
    $ModelsPath,
    $DiscoveryPath,
    $GraphPath,
    $ValidatorPath,
    $GeneratorPath,
    $CliPath,
    $TestPath,
    (Join-Path $ProjectRoot "config\roadmap\SGD-116-component.json"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Assert-Path -Path $Required -Description $Required
}

Write-Step "Respaldando implementación actual"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Path in @(
    $ModelsPath,
    $DiscoveryPath,
    $GraphPath,
    $ValidatorPath,
    $GeneratorPath,
    $CliPath,
    $TestPath
)) {
    Copy-Item `
        -LiteralPath $Path `
        -Destination (Join-Path $BackupDir (Split-Path $Path -Leaf)) `
        -Force
}

$ModelsContent = @'
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
'@

$DiscoveryContent = @'
"""Descubrimiento institucional y resolución canónica."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from .models import ComponentRecord


CANONICAL_PATTERN = re.compile(
    r"^(ADR|SGD|SPB|SPT|SIB|MMGR)-[0-9]+(?:\.[0-9]+)?[A-Z]?$",
    re.IGNORECASE,
)

VERSION_SUFFIX_PATTERN = re.compile(
    r"^(?P<code>(?:ADR|SGD|SPB|SPT|SIB|MMGR)-[0-9]+"
    r"(?:\.[0-9]+)?[A-Z]?)"
    r"(?:-v[0-9]+(?:\.[0-9]+)*(?:[-._A-Za-z0-9]*)?)?$",
    re.IGNORECASE,
)


def canonical_component_code(value: str) -> str:
    """Convierte una referencia versionada en su código institucional."""
    clean = str(value).strip()
    if not clean:
        return ""

    clean = clean.split()[0].rstrip(",;:")
    match = VERSION_SUFFIX_PATTERN.match(clean)
    if match:
        return match.group("code").upper()

    return clean.upper()


def _as_paths(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value.replace("\\", "/")] if value.strip() else []
    if isinstance(value, list):
        return [
            str(item).replace("\\", "/")
            for item in value
            if str(item).strip()
        ]
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


def repository_evidence(
    root: str | Path,
    code: str,
) -> list[str]:
    """Busca evidencia real asociada a un código canónico."""
    repository = Path(root)
    normalized = canonical_component_code(code)
    if not normalized:
        return []

    needle = normalized.lower()
    matches: set[str] = set()

    roots = (
        "config",
        "src",
        "tests",
        "docs",
        "scripts",
        "artifacts/pmo",
        "releases",
        "dashboard",
    )

    for base in roots:
        location = repository / base
        if not location.exists():
            continue

        for path in location.rglob("*"):
            try:
                relative = path.relative_to(repository).as_posix()
            except ValueError:
                continue

            if needle in path.name.lower():
                matches.add(relative)
                continue

            if path.is_file() and path.suffix.lower() in {
                ".json",
                ".md",
                ".py",
                ".ps1",
                ".txt",
            }:
                try:
                    content = path.read_text(
                        encoding="utf-8-sig",
                        errors="ignore",
                    )
                except OSError:
                    continue

                if normalized in content:
                    matches.add(relative)

            if len(matches) >= 25:
                break

    return sorted(matches)


def _record_from_descriptor(
    repository: Path,
    path: Path,
    payload: dict[str, Any],
) -> ComponentRecord | None:
    raw_code = str(
        payload.get("increment_code")
        or payload.get("component_code")
        or payload.get("code")
        or ""
    ).strip()

    code = canonical_component_code(raw_code)
    if not CANONICAL_PATTERN.match(code):
        return None

    component_type = str(
        payload.get("component_type")
        or payload.get("type")
        or "unspecified"
    ).strip()

    dependencies = [
        canonical_component_code(item)
        for item in _as_paths(
            payload.get("dependencies")
            or payload.get("depends_on")
            or payload.get("governed_by")
        )
        if canonical_component_code(item)
    ]

    release_matches = sorted(
        (repository / "releases").glob(f"{code}-v*")
    )

    return ComponentRecord(
        code=code,
        name=str(
            payload.get("name")
            or payload.get("component_name")
            or code
        ).strip(),
        version=str(payload.get("version", "0.0.0")),
        status=str(payload.get("status", "registered")),
        component_type=component_type,
        phase=str(
            payload.get("phase")
            or infer_phase(code, component_type)
        ),
        dependencies=dependencies,
        source_paths=_as_paths(
            payload.get("source")
            or payload.get("source_paths")
        ),
        test_paths=_as_paths(
            payload.get("tests")
            or payload.get("test_paths")
        ),
        documentation_paths=_as_paths(
            payload.get("documentation")
            or payload.get("documents")
        ),
        release_path=(
            release_matches[-1]
            .relative_to(repository)
            .as_posix()
            if release_matches
            else None
        ),
        config_path=path.relative_to(repository).as_posix(),
        metadata={
            "raw_code": raw_code,
            "canonical_code": code,
            "descriptor": path.relative_to(
                repository
            ).as_posix(),
        },
    )


def _anchor_from_evidence(
    repository: Path,
    code: str,
    evidence: list[str],
) -> ComponentRecord:
    source_paths = [
        item
        for item in evidence
        if item.startswith("src/") and item.endswith(".py")
    ]
    test_paths = [
        item
        for item in evidence
        if item.startswith("tests/") and item.endswith(".py")
    ]
    documentation_paths = [
        item
        for item in evidence
        if item.startswith("docs/")
    ]
    releases = [
        item
        for item in evidence
        if item.startswith("releases/")
    ]

    return ComponentRecord(
        code=code,
        name=f"Componente histórico {code}",
        version="historical",
        status="historically_implemented",
        component_type="historical_component_anchor",
        phase=infer_phase(code, "historical_component_anchor"),
        dependencies=[],
        source_paths=source_paths[:10],
        test_paths=test_paths[:10],
        documentation_paths=documentation_paths[:10],
        release_path=releases[-1] if releases else None,
        config_path=None,
        metadata={
            "synthetic_canonical_anchor": True,
            "evidence_count": len(evidence),
            "evidence": evidence[:25],
        },
    )


def discover_components(root: str | Path) -> list[ComponentRecord]:
    repository = Path(root)
    records: list[ComponentRecord] = []

    descriptor_patterns = (
        "config/**/*component*.json",
        "config/**/*Component*.json",
    )

    descriptor_paths: set[Path] = set()
    for pattern in descriptor_patterns:
        descriptor_paths.update(repository.glob(pattern))

    for path in sorted(descriptor_paths):
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError):
            continue

        if not isinstance(payload, dict):
            continue

        record = _record_from_descriptor(
            repository,
            path,
            payload,
        )
        if record:
            records.append(record)

    deduplicated: dict[str, ComponentRecord] = {}
    for record in records:
        current = deduplicated.get(record.code)
        if current is None:
            deduplicated[record.code] = record
            continue

        current_has_config = current.config_path is not None
        record_has_config = record.config_path is not None

        if record_has_config and not current_has_config:
            deduplicated[record.code] = record
        elif record.version >= current.version:
            deduplicated[record.code] = record

    dependency_targets = {
        canonical_component_code(dependency)
        for record in deduplicated.values()
        for dependency in record.dependencies
        if canonical_component_code(dependency)
    }

    for target in sorted(dependency_targets):
        if target in deduplicated:
            continue

        evidence = repository_evidence(repository, target)
        if evidence:
            deduplicated[target] = _anchor_from_evidence(
                repository,
                target,
                evidence,
            )

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
"""Grafo de dependencias institucional."""

from __future__ import annotations

from .discovery import canonical_component_code
from .models import ComponentRecord, DependencyGraph


def build_dependency_graph(
    components: list[ComponentRecord],
) -> DependencyGraph:
    nodes = sorted({item.code for item in components})
    node_set = set(nodes)

    edges: dict[tuple[str, str], dict[str, str]] = {}
    missing: dict[tuple[str, str], dict[str, str]] = {}
    historical: dict[tuple[str, str], dict[str, str]] = {}

    component_by_code = {
        item.code: item for item in components
    }

    for component in components:
        for raw in component.dependencies:
            target = canonical_component_code(raw)
            if not target or target == component.code:
                continue

            edge = {
                "source": component.code,
                "target": target,
            }
            key = (component.code, target)
            edges[key] = edge

            if target not in node_set:
                missing[key] = edge
                continue

            target_record = component_by_code[target]
            if target_record.metadata.get(
                "synthetic_canonical_anchor"
            ):
                historical[key] = edge

    adjacency: dict[str, list[str]] = {
        node: [] for node in nodes
    }
    for edge in edges.values():
        if edge["target"] in node_set:
            adjacency[edge["source"]].append(edge["target"])

    cycles: list[list[str]] = []
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []

    def visit(node: str) -> None:
        if node in visiting:
            start = stack.index(node)
            cycle = stack[start:] + [node]
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

    return DependencyGraph(
        nodes=nodes,
        edges=sorted(
            edges.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        missing_dependencies=sorted(
            missing.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        historical_dependencies=sorted(
            historical.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        cycles=cycles,
    )
'@

$ValidatorContent = @'
"""Validador definitivo del Roadmap Maestro Vivo."""

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


def _declared_paths(
    component: ComponentRecord,
) -> list[str]:
    return (
        component.source_paths
        + component.test_paths
        + component.documentation_paths
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
        code
        for code, count in counts.items()
        if count > 1
    )

    broken_paths: list[str] = []
    for component in components:
        for declared in _declared_paths(component):
            clean = declared.rstrip("/")
            if not clean:
                continue

            if not (repository / clean).exists():
                broken_paths.append(
                    f"{component.code}:{clean}"
                )

    graph = build_dependency_graph(components)

    missing_master_documents = [
        document
        for document in MASTER_DOCUMENTS
        if not (repository / document).is_file()
    ]

    passed = (
        len(components) > 0
        and not duplicate_codes
        and not broken_paths
        and not graph.missing_dependencies
        and not graph.cycles
        and not missing_master_documents
    )

    return ValidationResult(
        passed=passed,
        component_count=len(components),
        duplicate_codes=duplicate_codes,
        broken_paths=sorted(set(broken_paths)),
        missing_dependencies=graph.missing_dependencies,
        historical_dependencies=graph.historical_dependencies,
        dependency_cycles=graph.cycles,
        missing_master_documents=missing_master_documents,
        generated_at_utc=datetime.now(
            timezone.utc
        ).isoformat(),
    )
'@

$GeneratorContent = @'
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
'@

$CliContent = @'
"""CLI definitiva de SGD-116."""

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

    paths = generate_roadmap(
        args.root,
        args.output,
    )

    validation = json.loads(
        Path(paths["validation"]).read_text(
            encoding="utf-8"
        )
    )

    print("SGD-116 ejecutado correctamente.")
    print(f"Componentes: {validation['component_count']}")
    print(
        "Validación: "
        f"{'APROBADA' if validation['passed'] else 'NO APROBADA'}"
    )
    print(
        "Dependencias faltantes: "
        f"{len(validation['missing_dependencies'])}"
    )
    print(
        "Dependencias históricas resueltas: "
        f"{len(validation['historical_dependencies'])}"
    )
    print(
        "Rutas rotas: "
        f"{len(validation['broken_paths'])}"
    )
    print(
        "Ciclos: "
        f"{len(validation['dependency_cycles'])}"
    )
    print(f"Roadmap: {paths['roadmap']}")

    if not validation["passed"]:
        if validation["missing_dependencies"]:
            print("Detalle de dependencias faltantes:")
            for item in validation["missing_dependencies"]:
                print(
                    f"  {item['source']} -> "
                    f"{item['target']}"
                )

        if validation["broken_paths"]:
            print("Detalle de rutas rotas:")
            for item in validation["broken_paths"]:
                print(f"  {item}")

    return 0 if validation["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

Write-Step "Aplicando arquitectura definitiva SGD-116"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $DiscoveryPath -Content $DiscoveryContent
Write-Utf8NoBom -Path $GraphPath -Content $GraphContent
Write-Utf8NoBom -Path $ValidatorPath -Content $ValidatorContent
Write-Utf8NoBom -Path $GeneratorPath -Content $GeneratorContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent

Write-Step "Agregando pruebas de cierre definitivo"

$CurrentTests = Get-Content `
    -LiteralPath $TestPath `
    -Raw `
    -Encoding UTF8

$AdditionalTests = @'


def test_SGD_116_canonicalizes_all_supported_version_suffixes():
    from sgoda.roadmap.discovery import canonical_component_code

    assert canonical_component_code("SGD-114-v2.0.1") == "SGD-114"
    assert canonical_component_code("SGD-115-v1.0.1") == "SGD-115"
    assert canonical_component_code("SPT-006A-v0.2.0") == "SPT-006A"
    assert canonical_component_code("ADR-010-v1.0.0") == "ADR-010"


def test_SGD_116_finds_repository_evidence_for_historical_code(
    tmp_path,
):
    from sgoda.roadmap.discovery import repository_evidence

    root = tmp_path
    (root / "docs").mkdir()
    (root / "docs/SGD-114-history.md").write_text(
        "# SGD-114\n",
        encoding="utf-8",
    )

    evidence = repository_evidence(root, "SGD-114")
    assert "docs/SGD-114-history.md" in evidence


def test_SGD_116_resolves_historical_dependency_with_evidence(
    tmp_path,
):
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "docs").mkdir(parents=True)
    (root / "releases").mkdir(parents=True)

    (root / "docs/SGD-114-history.md").write_text(
        "# SGD-114\n",
        encoding="utf-8",
    )

    payload = {
        "increment_code": "SPT-901",
        "name": "Consumer",
        "version": "1.0.0",
        "status": "implemented",
        "component_type": "test",
        "dependencies": ["SGD-114-v2.0.1"],
    }
    (root / "config/test/SPT-901-component.json").write_text(
        json.dumps(payload),
        encoding="utf-8",
    )

    components = discover_components(root)
    graph = build_dependency_graph(components)

    assert "SGD-114" in [item.code for item in components]
    assert graph.missing_dependencies == []
    assert graph.historical_dependencies == [
        {"source": "SPT-901", "target": "SGD-114"}
    ]


def test_SGD_116_still_blocks_dependency_without_evidence(
    tmp_path,
):
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "releases").mkdir(parents=True)

    payload = {
        "increment_code": "SPT-901",
        "name": "Consumer",
        "version": "1.0.0",
        "status": "implemented",
        "component_type": "test",
        "dependencies": ["SGD-999-v9.9.9"],
    }
    (root / "config/test/SPT-901-component.json").write_text(
        json.dumps(payload),
        encoding="utf-8",
    )

    components = discover_components(root)
    graph = build_dependency_graph(components)

    assert graph.missing_dependencies == [
        {"source": "SPT-901", "target": "SGD-999"}
    ]
'@

if ($CurrentTests -notmatch "test_SGD_116_canonicalizes_all_supported_version_suffixes") {
    Write-Utf8NoBom `
        -Path $TestPath `
        -Content ($CurrentTests.TrimEnd() + $AdditionalTests)
}
else {
    Write-Host "Las pruebas definitivas ya estaban instaladas." -ForegroundColor Yellow
}

Write-Step "Validando sintaxis e importaciones"

& python -m py_compile `
    "src/sgoda/roadmap/models.py" `
    "src/sgoda/roadmap/discovery.py" `
    "src/sgoda/roadmap/dependency_graph.py" `
    "src/sgoda/roadmap/validator.py" `
    "src/sgoda/roadmap/generator.py" `
    "src/sgoda/roadmap/cli.py" `
    "tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py"

if ($LASTEXITCODE -ne 0) {
    throw "La compilación SGD-116 v1.1.0 falló."
}

& python -c "from sgoda.roadmap.discovery import canonical_component_code, discover_components; from sgoda.roadmap.dependency_graph import build_dependency_graph; print(canonical_component_code('SGD-114-v2.0.1'), canonical_component_code('SGD-115-v1.0.1'))"

if ($LASTEXITCODE -ne 0) {
    throw "La importación SGD-116 v1.1.0 falló."
}

Write-Step "Ejecutando pruebas específicas SGD-116"

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

Write-Step "Eliminando evidencia de validación obsoleta"

if (Test-Path -LiteralPath $ArtifactsDir) {
    foreach ($Name in @(
        "roadmap.json",
        "dependency-graph.json",
        "metrics.json",
        "timeline.json",
        "validation.json",
        "executive-summary.json"
    )) {
        $Stale = Join-Path $ArtifactsDir $Name
        if (Test-Path -LiteralPath $Stale) {
            Remove-Item -LiteralPath $Stale -Force
        }
    }
}

Write-Step "Regenerando Roadmap Maestro desde cero"

& python -m sgoda.roadmap.cli `
    --root "$ProjectRoot" `
    --output "artifacts/roadmap/SGD-116"

if ($LASTEXITCODE -ne 0) {
    if (Test-Path -LiteralPath $ValidationPath) {
        $FailedValidation = Get-Content `
            -LiteralPath $ValidationPath `
            -Raw `
            -Encoding UTF8 |
            ConvertFrom-Json

        Write-Host ""
        Write-Host "=== VALIDACIÓN FALLIDA ===" -ForegroundColor Red
        Write-Host "Componentes: $($FailedValidation.component_count)"
        Write-Host "Dependencias faltantes: $(@($FailedValidation.missing_dependencies).Count)"
        @($FailedValidation.missing_dependencies) |
            Format-Table source, target -AutoSize
        Write-Host "Rutas rotas: $(@($FailedValidation.broken_paths).Count)"
        @($FailedValidation.broken_paths) |
            ForEach-Object { Write-Host $_ }
        Write-Host "Ciclos: $(@($FailedValidation.dependency_cycles).Count)"
    }

    throw "La regeneración definitiva SGD-116 no fue aprobada."
}

Assert-Path -Path $ValidationPath -Description "validation.json"
Assert-Path -Path $MetricsPath -Description "metrics.json"

$Validation = Get-Content `
    -LiteralPath $ValidationPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$Metrics = Get-Content `
    -LiteralPath $MetricsPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not $Validation.passed) {
    throw "SGD-116 continúa sin passed=true."
}

if (@($Validation.missing_dependencies).Count -ne 0) {
    throw "Persisten dependencias faltantes."
}

if (@($Validation.broken_paths).Count -ne 0) {
    throw "Persisten rutas rotas."
}

if (@($Validation.dependency_cycles).Count -ne 0) {
    throw "Persisten ciclos de dependencias."
}

Write-Step "Generando evidencia definitiva"

Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SGD-116"
    version = "1.1.0"
    status = "definitively_closed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    component_count = $Validation.component_count
    missing_dependencies = @($Validation.missing_dependencies).Count
    historical_dependencies_resolved = @($Validation.historical_dependencies).Count
    broken_paths = @($Validation.broken_paths).Count
    dependency_cycles = @($Validation.dependency_cycles).Count
    duplicate_codes = @($Validation.duplicate_codes).Count
    missing_master_documents = @($Validation.missing_master_documents).Count
    total_test_files = $Metrics.total_test_files
    total_documents = $Metrics.total_documents
    total_releases = $Metrics.total_releases
    validation = "approved"
    roadmap = "operational"
})

Write-Step "Publicando release SGD-116 v1.1.0"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Artifact in @(
    $ModelsPath,
    $DiscoveryPath,
    $GraphPath,
    $ValidatorPath,
    $GeneratorPath,
    $CliPath,
    $TestPath,
    $ValidationPath,
    $MetricsPath,
    $EvidencePath,
    (Join-Path $ArtifactsDir "roadmap.json"),
    (Join-Path $ArtifactsDir "dependency-graph.json"),
    (Join-Path $ArtifactsDir "timeline.json"),
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
    throw "El quality gate SGD-116 v1.1.0 no fue aprobado."
}

$Gate = Get-Content `
    -LiteralPath $GatePath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El quality gate no contiene passed=true."
}

Write-Step "Actualizando documentación maestra SGD-115"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La actualización SGD-115 falló."
}

Write-Step "Resultado final"

Write-Host "SGD-116 v1.1.0 cerrado definitivamente." -ForegroundColor Green
Write-Host "Roadmap Maestro Vivo: OPERATIVO." -ForegroundColor Green
Write-Host "Validación: APROBADA." -ForegroundColor Green
Write-Host "Dependencias faltantes: 0." -ForegroundColor Green
Write-Host "Dependencias históricas resueltas: $(@($Validation.historical_dependencies).Count)" -ForegroundColor Green
Write-Host "Rutas rotas: 0." -ForegroundColor Green
Write-Host "Ciclos: 0." -ForegroundColor Green
Write-Host "Códigos duplicados: 0." -ForegroundColor Green
Write-Host "Documentos maestros faltantes: 0." -ForegroundColor Green
Write-Host "Componentes descubiertos: $($Validation.component_count)" -ForegroundColor Cyan
Write-Host "Archivos de prueba: $($Metrics.total_test_files)" -ForegroundColor Cyan
Write-Host "Documentos: $($Metrics.total_documents)" -ForegroundColor Cyan
Write-Host "Releases: $($Metrics.total_releases)" -ForegroundColor Cyan
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SGD-116-v1.1.0" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." -ForegroundColor Yellow
