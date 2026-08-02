<#
.SYNOPSIS
    Instala SGD-116B v2.0.0 — Correctivo Institucional Único para el
    Roadmap Maestro Vivo del ecosistema SGODA-PUINAVE.

.DESCRIPTION
    Este instalador reemplaza la cadena de reparaciones parciales de SGD-116
    por una implementación institucional estable y modular.

    Implementa:

      - resolución canónica aislada en aliases.py;
      - descubrimiento híbrido:
          * descriptores config/**/*component*.json;
          * evidencia institucional real en src, tests, docs, scripts,
            releases, artifacts/pmo y dashboard;
      - conservación de componentes históricos;
      - detección estricta de dependencias inexistentes;
      - grafo con estados FOUND, ALIASED, HISTORICAL y MISSING;
      - validación de rutas, duplicados, ciclos y documentos maestros;
      - regeneración completa del Roadmap y dashboards;
      - pruebas específicas ampliadas;
      - suite completa del proyecto;
      - quality gate SGD-114;
      - actualización SGD-115;
      - release institucional SGD-116B-v2.0.0.

    El instalador NO hace commit ni push. La publicación se realiza después
    mediante SPB-007.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio.

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
    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path ($($Info.Length) bytes)" `
        -ForegroundColor Green
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

function Invoke-Checked {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    Write-Step $Description
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$RoadmapDir = Join-Path $ProjectRoot "src\sgoda\roadmap"
$TestsDir = Join-Path $ProjectRoot "tests\roadmap"
$ConfigDir = Join-Path $ProjectRoot "config\roadmap"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SGD-116B"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\roadmap\SGD-116"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-116B"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-116B-v2.0.0"
$DashboardDir = Join-Path $ProjectRoot "dashboard"

$AliasesPath = Join-Path $RoadmapDir "aliases.py"
$DiscoveryPath = Join-Path $RoadmapDir "discovery.py"
$GraphPath = Join-Path $RoadmapDir "dependency_graph.py"
$ValidatorPath = Join-Path $RoadmapDir "validator.py"
$ModelsPath = Join-Path $RoadmapDir "models.py"
$GeneratorPath = Join-Path $RoadmapDir "generator.py"
$CliPath = Join-Path $RoadmapDir "cli.py"
$InitPath = Join-Path $RoadmapDir "__init__.py"

$TestPath = Join-Path $TestsDir "test_SGD_116B_institutional_roadmap_closure.py"
$PolicyPath = Join-Path $ConfigDir "SGD-116B-policy.json"
$ComponentPath = Join-Path $ConfigDir "SGD-116B-component.json"
$DocPath = Join-Path $DocsDir "SGD-116B-Correctivo-Institucional-Unico.md"
$ArchitecturePath = Join-Path $DocsDir "SGD-116B-Arquitectura-Resolucion-Canonica.md"
$OperationsPath = Join-Path $DocsDir "SGD-116B-Operacion-y-Cierre.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SGD116B-InstitutionalRoadmap.ps1"

$ValidationPath = Join-Path $ArtifactsDir "validation.json"
$MetricsPath = Join-Path $ArtifactsDir "metrics.json"
$EvidencePath = Join-Path $PmoDir "SGD-116B-implementation-evidence.json"
$TracePath = Join-Path $PmoDir "SGD-116B-traceability.json"
$GatePath = Join-Path $PmoDir "SGD-116B-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SGD-116B-dashboard.json"

$BackupDir = Join-Path $PmoDir (
    "backups\pre-SGD116B-" +
    [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
)

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "src\sgoda\roadmap"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot ".git")
)) {
    Assert-Path -Path $Required -Description $Required
}

$GitStatus = @(git status --porcelain | Where-Object { $_ })
$AllowedPatterns = @(
    '^\?\? Install-SGD116B-Institutional-Roadmap-Closure\.ps1$',
    '^\?\? SGD116B-.*\.zip$',
    '^\?\? LEAME-SGD116B.*\.txt$',
    '^\?\? Repair-SGD116.*\.ps1$',
    '^\?\? Install-SGD116.*\.ps1$',
    '^ M src/sgoda/roadmap/',
    '^ M tests/roadmap/',
    '^ M artifacts/roadmap/SGD-116/',
    '^ M dashboard/',
    '^ M docs/00_',
    '^\?\? artifacts/pmo/SGD-116/',
    '^\?\? releases/SGD-116'
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
        if (-not $Allowed) {
            $Entry
        }
    }
)

if ($Unexpected.Count -gt 0) {
    Write-Host "Cambios no relacionados detectados:" -ForegroundColor Red
    $Unexpected | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "La línea base contiene cambios ajenos a SGD-116."
}

Write-Step "Respaldando implementación actual de SGD-116"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Path in @(
    $ModelsPath,
    $DiscoveryPath,
    $GraphPath,
    $ValidatorPath,
    $GeneratorPath,
    $CliPath,
    $InitPath
)) {
    if (Test-Path -LiteralPath $Path) {
        Copy-Item `
            -LiteralPath $Path `
            -Destination (Join-Path $BackupDir (Split-Path $Path -Leaf)) `
            -Force
    }
}

$AliasesContent = @'
"""Resolución canónica institucional para SGD-116B."""

from __future__ import annotations

import re
from dataclasses import dataclass


SUPPORTED_PREFIXES = ("ADR", "SGD", "SPB", "SPT", "SIB", "MMGR")

_CANONICAL_RE = re.compile(
    r"^(?P<code>(?:ADR|SGD|SPB|SPT|SIB|MMGR)-"
    r"[0-9]+(?:\.[0-9]+)?[A-Z]?)"
    r"(?P<version>-v[0-9]+(?:\.[0-9]+)*(?:[-._A-Za-z0-9]*)?)?$",
    re.IGNORECASE,
)


@dataclass(frozen=True, slots=True)
class AliasResolution:
    raw: str
    canonical: str
    changed: bool
    valid_format: bool


def resolve_alias(value: object) -> AliasResolution:
    raw = str(value or "").strip()

    if not raw:
        return AliasResolution(
            raw="",
            canonical="",
            changed=False,
            valid_format=False,
        )

    token = raw.split()[0].rstrip(",;:")
    match = _CANONICAL_RE.fullmatch(token)

    if not match:
        return AliasResolution(
            raw=raw,
            canonical=token.upper(),
            changed=False,
            valid_format=False,
        )

    canonical = match.group("code").upper()

    return AliasResolution(
        raw=raw,
        canonical=canonical,
        changed=canonical != token.upper(),
        valid_format=True,
    )


def canonical_component_code(value: object) -> str:
    return resolve_alias(value).canonical


def is_supported_component_code(value: object) -> bool:
    resolution = resolve_alias(value)
    return resolution.valid_format and bool(resolution.canonical)
'@

$ModelsContent = @'
"""Modelos del Roadmap Maestro Vivo SGD-116B."""

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
    resolved_aliases: list[dict[str, str]]
    historical_dependencies: list[dict[str, str]]
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
    resolved_aliases: list[dict[str, str]]
    historical_dependencies: list[dict[str, str]]
    dependency_cycles: list[list[str]]
    missing_master_documents: list[str]
    generated_at_utc: str
'@

$DiscoveryContent = @'
"""Descubrimiento híbrido institucional de SGD-116B."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .aliases import (
    canonical_component_code,
    is_supported_component_code,
    resolve_alias,
)
from .models import ComponentRecord


def _paths(value: Any) -> list[str]:
    if isinstance(value, str):
        value = [value]

    if not isinstance(value, list):
        return []

    return [
        str(item).replace("\\", "/")
        for item in value
        if str(item).strip()
    ]


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


def _descriptor_record(
    repository: Path,
    path: Path,
    payload: dict[str, Any],
) -> ComponentRecord | None:
    raw_code = (
        payload.get("increment_code")
        or payload.get("component_code")
        or payload.get("code")
        or ""
    )

    resolution = resolve_alias(raw_code)

    if not resolution.valid_format:
        return None

    code = resolution.canonical
    component_type = str(
        payload.get("component_type")
        or payload.get("type")
        or "unspecified"
    ).strip()

    dependencies: list[str] = []
    raw_dependencies = (
        payload.get("dependencies")
        or payload.get("depends_on")
        or payload.get("governed_by")
        or []
    )

    if isinstance(raw_dependencies, str):
        raw_dependencies = [raw_dependencies]

    if isinstance(raw_dependencies, list):
        dependencies = [
            str(item)
            for item in raw_dependencies
            if str(item).strip()
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
        source_paths=_paths(
            payload.get("source")
            or payload.get("source_paths")
        ),
        test_paths=_paths(
            payload.get("tests")
            or payload.get("test_paths")
        ),
        documentation_paths=_paths(
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
            "discovery_source": "descriptor",
            "raw_code": str(raw_code),
            "canonical_code": code,
            "alias_applied": resolution.changed,
        },
    )


def institutional_evidence(
    root: str | Path,
    code: str,
) -> list[str]:
    repository = Path(root)
    canonical = canonical_component_code(code)

    if not canonical or not is_supported_component_code(canonical):
        return []

    normalized = canonical.lower()
    evidence: set[str] = set()

    locations = (
        "src",
        "tests",
        "docs",
        "config",
        "scripts",
        "releases",
        "artifacts/pmo",
        "dashboard",
    )

    for location in locations:
        base = repository / location
        if not base.exists():
            continue

        for path in base.rglob("*"):
            if len(evidence) >= 50:
                break

            try:
                relative = path.relative_to(repository).as_posix()
            except ValueError:
                continue

            if normalized in path.name.lower():
                evidence.add(relative)

    return sorted(evidence)


def _historical_record(
    repository: Path,
    code: str,
    evidence: list[str],
) -> ComponentRecord:
    source_paths = [
        item for item in evidence
        if item.startswith("src/") and item.endswith(".py")
    ]
    test_paths = [
        item for item in evidence
        if item.startswith("tests/") and item.endswith(".py")
    ]
    documentation_paths = [
        item for item in evidence
        if item.startswith("docs/")
    ]
    release_paths = [
        item for item in evidence
        if item.startswith("releases/")
    ]

    return ComponentRecord(
        code=code,
        name=f"Componente institucional histórico {code}",
        version="historical",
        status="historically_implemented",
        component_type="historical_component",
        phase=infer_phase(code, "historical_component"),
        dependencies=[],
        source_paths=source_paths,
        test_paths=test_paths,
        documentation_paths=documentation_paths,
        release_path=release_paths[-1] if release_paths else None,
        config_path=None,
        metadata={
            "discovery_source": "institutional_evidence",
            "synthetic_canonical_anchor": True,
            "evidence_count": len(evidence),
            "evidence": evidence,
        },
    )


def discover_components(root: str | Path) -> list[ComponentRecord]:
    repository = Path(root)
    records: list[ComponentRecord] = []

    descriptor_paths = sorted(
        set(
            repository.glob("config/**/*component*.json")
        )
        | set(
            repository.glob("config/**/*Component*.json")
        )
    )

    for path in descriptor_paths:
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError):
            continue

        if not isinstance(payload, dict):
            continue

        record = _descriptor_record(
            repository,
            path,
            payload,
        )
        if record:
            records.append(record)

    by_code: dict[str, ComponentRecord] = {}

    for record in records:
        current = by_code.get(record.code)

        if current is None:
            by_code[record.code] = record
            continue

        current_descriptor = current.config_path is not None
        new_descriptor = record.config_path is not None

        if new_descriptor and not current_descriptor:
            by_code[record.code] = record
        elif record.version >= current.version:
            by_code[record.code] = record

    dependency_codes = {
        canonical_component_code(dependency)
        for component in by_code.values()
        for dependency in component.dependencies
        if is_supported_component_code(dependency)
    }

    for dependency_code in sorted(dependency_codes):
        if dependency_code in by_code:
            continue

        evidence = institutional_evidence(
            repository,
            dependency_code,
        )

        if evidence:
            by_code[dependency_code] = _historical_record(
                repository,
                dependency_code,
                evidence,
            )

    return sorted(
        by_code.values(),
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
"""Grafo institucional estricto para SGD-116B."""

from __future__ import annotations

from .aliases import resolve_alias
from .models import ComponentRecord, DependencyGraph


def build_dependency_graph(
    components: list[ComponentRecord],
) -> DependencyGraph:
    nodes = sorted({component.code for component in components})
    node_set = set(nodes)
    by_code = {
        component.code: component
        for component in components
    }

    edges: dict[tuple[str, str], dict[str, str]] = {}
    aliases: dict[tuple[str, str], dict[str, str]] = {}
    historical: dict[tuple[str, str], dict[str, str]] = {}
    missing: dict[tuple[str, str], dict[str, str]] = {}

    for component in components:
        for raw_dependency in component.dependencies:
            resolution = resolve_alias(raw_dependency)
            target = resolution.canonical

            if not resolution.valid_format or not target:
                target = str(raw_dependency).strip().upper()

            if not target or target == component.code:
                continue

            edge = {
                "source": component.code,
                "target": target,
                "status": "FOUND",
            }
            key = (component.code, target)

            if resolution.changed:
                aliases[key] = {
                    "source": component.code,
                    "raw_target": resolution.raw,
                    "target": target,
                    "status": "ALIASED",
                }

            if target not in node_set:
                edge["status"] = "MISSING"
                missing[key] = edge
            else:
                target_component = by_code[target]

                if target_component.metadata.get(
                    "synthetic_canonical_anchor"
                ):
                    edge["status"] = "HISTORICAL"
                    historical[key] = edge

            edges[key] = edge

    adjacency: dict[str, list[str]] = {
        node: [] for node in nodes
    }

    for edge in edges.values():
        if edge["target"] in node_set:
            adjacency[edge["source"]].append(
                edge["target"]
            )

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

    sort_key = lambda item: (
        item["source"],
        item["target"],
    )

    return DependencyGraph(
        nodes=nodes,
        edges=sorted(edges.values(), key=sort_key),
        resolved_aliases=sorted(
            aliases.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        historical_dependencies=sorted(
            historical.values(),
            key=sort_key,
        ),
        missing_dependencies=sorted(
            missing.values(),
            key=sort_key,
        ),
        cycles=cycles,
    )
'@

$ValidatorContent = @'
"""Validador institucional de SGD-116B."""

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
    for component in components:
        counts[component.code] = (
            counts.get(component.code, 0) + 1
        )

    duplicate_codes = sorted(
        code
        for code, count in counts.items()
        if count > 1
    )

    broken_paths: list[str] = []

    for component in components:
        paths = (
            component.source_paths
            + component.test_paths
            + component.documentation_paths
        )

        for path in paths:
            clean = path.rstrip("/")

            if clean and not (repository / clean).exists():
                broken_paths.append(
                    f"{component.code}:{clean}"
                )

    graph = build_dependency_graph(components)

    missing_master_documents = [
        path
        for path in MASTER_DOCUMENTS
        if not (repository / path).is_file()
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
        resolved_aliases=graph.resolved_aliases,
        historical_dependencies=(
            graph.historical_dependencies
        ),
        dependency_cycles=graph.cycles,
        missing_master_documents=(
            missing_master_documents
        ),
        generated_at_utc=datetime.now(
            timezone.utc
        ).isoformat(),
    )
'@

$InitContent = @'
"""Roadmap Maestro Vivo — SGD-116B."""

from .aliases import (
    AliasResolution,
    canonical_component_code,
    is_supported_component_code,
    resolve_alias,
)
from .dependency_graph import build_dependency_graph
from .discovery import (
    discover_components,
    discover_repository_assets,
    institutional_evidence,
)
from .generator import generate_roadmap
from .metrics import calculate_metrics
from .timeline import build_timeline
from .validator import validate_roadmap

__all__ = [
    "AliasResolution",
    "build_dependency_graph",
    "build_timeline",
    "calculate_metrics",
    "canonical_component_code",
    "discover_components",
    "discover_repository_assets",
    "generate_roadmap",
    "institutional_evidence",
    "is_supported_component_code",
    "resolve_alias",
    "validate_roadmap",
]
'@

$TestContent = @'
"""Pruebas institucionales SGD-116B."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.roadmap.aliases import (
    canonical_component_code,
    is_supported_component_code,
    resolve_alias,
)
from sgoda.roadmap.dependency_graph import (
    build_dependency_graph,
)
from sgoda.roadmap.discovery import (
    discover_components,
    institutional_evidence,
)
from sgoda.roadmap.models import ComponentRecord
from sgoda.roadmap.validator import validate_roadmap


def _component(
    code: str,
    *,
    dependencies: list[str] | None = None,
    historical: bool = False,
) -> ComponentRecord:
    return ComponentRecord(
        code=code,
        name=code,
        version="1.0.0",
        status="implemented",
        component_type="test",
        phase="Test",
        dependencies=dependencies or [],
        metadata={
            "synthetic_canonical_anchor": historical
        },
    )


@pytest.mark.parametrize(
    ("raw", "canonical"),
    [
        ("SGD-114-v2.0.1", "SGD-114"),
        ("SGD-115-v1.0.1", "SGD-115"),
        ("SPT-006A-v0.2.0", "SPT-006A"),
        ("ADR-010-v1.0.0", "ADR-010"),
        ("SPB-007", "SPB-007"),
        ("SIB-001", "SIB-001"),
    ],
)
def test_SGD_116B_resolves_aliases(
    raw,
    canonical,
):
    assert canonical_component_code(raw) == canonical


def test_SGD_116B_reports_alias_change():
    result = resolve_alias("SGD-114-v2.0.1")
    assert result.changed is True
    assert result.valid_format is True


def test_SGD_116B_rejects_unsupported_format():
    assert is_supported_component_code("XYZ-001") is False


def test_SGD_116B_finds_institutional_evidence(
    tmp_path,
):
    root = tmp_path
    (root / "docs").mkdir()
    path = root / "docs/SGD-114-history.md"
    path.write_text("# SGD-114\n", encoding="utf-8")

    assert (
        "docs/SGD-114-history.md"
        in institutional_evidence(root, "SGD-114")
    )


def test_SGD_116B_discovers_descriptor_component(
    tmp_path,
):
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "releases").mkdir()

    payload = {
        "increment_code": "SPT-900",
        "name": "Test",
        "version": "1.0.0",
        "status": "implemented",
        "component_type": "test",
    }

    (
        root / "config/test/SPT-900-component.json"
    ).write_text(
        json.dumps(payload),
        encoding="utf-8",
    )

    assert [
        item.code
        for item in discover_components(root)
    ] == ["SPT-900"]


def test_SGD_116B_preserves_historical_component(
    tmp_path,
):
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "docs").mkdir()
    (root / "releases").mkdir()

    (
        root / "docs/SGD-114-history.md"
    ).write_text(
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

    (
        root / "config/test/SPT-901-component.json"
    ).write_text(
        json.dumps(payload),
        encoding="utf-8",
    )

    components = discover_components(root)
    assert {"SPT-901", "SGD-114"} == {
        item.code for item in components
    }


def test_SGD_116B_classifies_found_dependency():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-901",
                dependencies=["SGD-114"],
            ),
            _component("SGD-114"),
        ]
    )

    assert graph.edges == [
        {
            "source": "SPT-901",
            "target": "SGD-114",
            "status": "FOUND",
        }
    ]


def test_SGD_116B_classifies_aliased_dependency():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-901",
                dependencies=["SGD-114-v2.0.1"],
            ),
            _component("SGD-114"),
        ]
    )

    assert graph.resolved_aliases == [
        {
            "source": "SPT-901",
            "raw_target": "SGD-114-v2.0.1",
            "target": "SGD-114",
            "status": "ALIASED",
        }
    ]


def test_SGD_116B_classifies_historical_dependency():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-901",
                dependencies=["SGD-114-v2.0.1"],
            ),
            _component(
                "SGD-114",
                historical=True,
            ),
        ]
    )

    assert graph.historical_dependencies == [
        {
            "source": "SPT-901",
            "target": "SGD-114",
            "status": "HISTORICAL",
        }
    ]


def test_SGD_116B_blocks_missing_dependency():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-901",
                dependencies=["SGD-999-v9.9.9"],
            )
        ]
    )

    assert graph.missing_dependencies == [
        {
            "source": "SPT-901",
            "target": "SGD-999",
            "status": "MISSING",
        }
    ]


def test_SGD_116B_detects_cycle():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-900",
                dependencies=["SPT-901"],
            ),
            _component(
                "SPT-901",
                dependencies=["SPT-900"],
            ),
        ]
    )

    assert graph.cycles


def test_SGD_116B_validation_blocks_missing(
    tmp_path,
):
    root = tmp_path
    (root / "docs").mkdir()

    for name in (
        "00_INDICE_MAESTRO.md",
        "00_ARQUITECTURA_MAESTRA.md",
        "00_REGISTRO_MAESTRO_COMPONENTES.md",
        "00_ROADMAP_MAESTRO.md",
        "00_DEPENDENCIAS_MAESTRAS.md",
        "00_TIMELINE_MAESTRO.md",
        "00_METRICAS_ECOSISTEMA.md",
    ):
        (root / "docs" / name).write_text(
            "# Document\n",
            encoding="utf-8",
        )

    result = validate_roadmap(
        root,
        [
            _component(
                "SPT-901",
                dependencies=["SGD-999"],
            )
        ],
    )

    assert result.passed is False
    assert result.missing_dependencies


def test_SGD_116B_validation_accepts_historical(
    tmp_path,
):
    root = tmp_path
    (root / "docs").mkdir()

    for name in (
        "00_INDICE_MAESTRO.md",
        "00_ARQUITECTURA_MAESTRA.md",
        "00_REGISTRO_MAESTRO_COMPONENTES.md",
        "00_ROADMAP_MAESTRO.md",
        "00_DEPENDENCIAS_MAESTRAS.md",
        "00_TIMELINE_MAESTRO.md",
        "00_METRICAS_ECOSISTEMA.md",
    ):
        (root / "docs" / name).write_text(
            "# Document\n",
            encoding="utf-8",
        )

    result = validate_roadmap(
        root,
        [
            _component(
                "SPT-901",
                dependencies=["SGD-114-v2.0.1"],
            ),
            _component(
                "SGD-114",
                historical=True,
            ),
        ],
    )

    assert result.passed is True
    assert result.missing_dependencies == []
'@

$PolicyContent = @'
{
  "increment_code": "SGD-116B",
  "version": "2.0.0",
  "name": "Correctivo Institucional Único del Roadmap Maestro Vivo",
  "repository_source_of_truth": true,
  "canonical_alias_resolver": true,
  "hybrid_discovery": true,
  "historical_components_preserved": true,
  "missing_dependencies_blocked": true,
  "dependency_cycles_blocked": true,
  "broken_paths_blocked": true,
  "duplicate_codes_blocked": true,
  "master_documents_required": true,
  "quality_gate_required": true,
  "update_sgd_115": true,
  "publication_via_spb_007": true
}
'@

$ComponentContent = @'
{
  "increment_code": "SGD-116B",
  "name": "Correctivo Institucional Único del Roadmap Maestro Vivo",
  "component_type": "institutional_roadmap_closure",
  "version": "2.0.0",
  "status": "technically_completed",
  "dependencies": [
    "SGD-114",
    "SGD-115",
    "SPB-007",
    "SIB-001"
  ],
  "source": [
    "src/sgoda/roadmap/aliases.py",
    "src/sgoda/roadmap/discovery.py",
    "src/sgoda/roadmap/dependency_graph.py",
    "src/sgoda/roadmap/validator.py"
  ],
  "tests": [
    "tests/roadmap/test_SGD_116B_institutional_roadmap_closure.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SGD-116B/SGD-116B-Correctivo-Institucional-Unico.md",
    "docs/05_Fase_Tecnologica/SGD-116B/SGD-116B-Arquitectura-Resolucion-Canonica.md",
    "docs/05_Fase_Tecnologica/SGD-116B/SGD-116B-Operacion-y-Cierre.md"
  ]
}
'@

$DocContent = @'
# SGD-116B — Correctivo Institucional Único

SGD-116B reemplaza la cadena de reparaciones acumulativas de SGD-116.

El correctivo separa la resolución de alias del descubrimiento de
componentes, conserva componentes históricos demostrables y mantiene el
bloqueo estricto de dependencias inexistentes.

El repositorio continúa siendo la fuente institucional de verdad.
'@

$ArchitectureContent = @'
# SGD-116B — Arquitectura de Resolución Canónica

La resolución se concentra en `aliases.py`.

Estados del grafo:

- `FOUND`: componente descubierto directamente;
- `ALIASED`: referencia versionada normalizada;
- `HISTORICAL`: componente respaldado por evidencia institucional;
- `MISSING`: dependencia sin descriptor ni evidencia.

Solo `MISSING`, rutas rotas, duplicados, ciclos y documentos maestros
ausentes bloquean la validación.
'@

$OperationsContent = @'
# SGD-116B — Operación y cierre

## Regenerar y validar

```powershell
.\scripts\Invoke-SGD116B-InstitutionalRoadmap.ps1
```

## Publicar

La publicación se realiza exclusivamente mediante SPB-007 después de
confirmar que la validación, la suite completa y el quality gate fueron
aprobados.
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
    throw "SGD-116B terminó con errores."
}

$ValidationPath = Join-Path $Root "$Output\validation.json"
$Validation = Get-Content `
    -LiteralPath $ValidationPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not $Validation.passed) {
    throw "La validación institucional SGD-116B no fue aprobada."
}

Write-Host "SGD-116B ejecutado correctamente." -ForegroundColor Green
Write-Host "Dependencias faltantes: $(@($Validation.missing_dependencies).Count)"
Write-Host "Alias resueltos: $(@($Validation.resolved_aliases).Count)"
Write-Host "Dependencias históricas: $(@($Validation.historical_dependencies).Count)"
'@

Write-Step "Instalando correctivo institucional único SGD-116B"

Write-Utf8NoBom -Path $AliasesPath -Content $AliasesContent
Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $DiscoveryPath -Content $DiscoveryContent
Write-Utf8NoBom -Path $GraphPath -Content $GraphContent
Write-Utf8NoBom -Path $ValidatorPath -Content $ValidatorContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent
Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $ArchitecturePath -Content $ArchitectureContent
Write-Utf8NoBom -Path $OperationsPath -Content $OperationsContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad inicial"

Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SGD-116B"
    version = "2.0.0"
    status = "installed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    canonical_alias_resolver = $true
    hybrid_discovery = $true
    historical_components_preserved = $true
    missing_dependencies_blocked = $true
    backup = $BackupDir
})

Write-JsonUtf8 -Path $TracePath -Data ([ordered]@{
    increment_code = "SGD-116B"
    source = @(
        "src/sgoda/roadmap/aliases.py",
        "src/sgoda/roadmap/discovery.py",
        "src/sgoda/roadmap/dependency_graph.py",
        "src/sgoda/roadmap/validator.py"
    )
    tests = @(
        "tests/roadmap/test_SGD_116B_institutional_roadmap_closure.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SGD-116B/"
    )
})

Invoke-Checked "Validando sintaxis e importaciones" {
    python -m py_compile `
        "src/sgoda/roadmap/aliases.py" `
        "src/sgoda/roadmap/models.py" `
        "src/sgoda/roadmap/discovery.py" `
        "src/sgoda/roadmap/dependency_graph.py" `
        "src/sgoda/roadmap/validator.py" `
        "tests/roadmap/test_SGD_116B_institutional_roadmap_closure.py"

    if ($LASTEXITCODE -eq 0) {
        python -c "from sgoda.roadmap import canonical_component_code, discover_components, build_dependency_graph; print(canonical_component_code('SGD-114-v2.0.1'))"
    }
}

Invoke-Checked "Ejecutando pruebas específicas SGD-116B" {
    python -m pytest `
        "tests/roadmap/test_SGD_116B_institutional_roadmap_closure.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Eliminando validaciones obsoletas"

New-Item -ItemType Directory -Path $ArtifactsDir -Force | Out-Null

foreach ($Name in @(
    "roadmap.json",
    "dependency-graph.json",
    "metrics.json",
    "timeline.json",
    "validation.json",
    "executive-summary.json"
)) {
    $Path = Join-Path $ArtifactsDir $Name
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }
}

Invoke-Checked "Regenerando Roadmap Maestro real" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
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
    Write-Host ""
    Write-Host "=== VALIDACIÓN SGD-116B NO APROBADA ===" `
        -ForegroundColor Red

    Write-Host "Dependencias faltantes:"
    @($Validation.missing_dependencies) |
        Format-Table source, target, status -AutoSize

    Write-Host "Rutas rotas:"
    @($Validation.broken_paths) |
        ForEach-Object { Write-Host $_ }

    Write-Host "Ciclos:"
    @($Validation.dependency_cycles) |
        ForEach-Object {
            Write-Host ($_ -join " -> ")
        }

    throw "El Roadmap real todavía contiene errores institucionales."
}

foreach ($Check in @(
    @{
        Name = "dependencias faltantes"
        Count = @($Validation.missing_dependencies).Count
    },
    @{
        Name = "rutas rotas"
        Count = @($Validation.broken_paths).Count
    },
    @{
        Name = "ciclos"
        Count = @($Validation.dependency_cycles).Count
    },
    @{
        Name = "códigos duplicados"
        Count = @($Validation.duplicate_codes).Count
    },
    @{
        Name = "documentos maestros faltantes"
        Count = @($Validation.missing_master_documents).Count
    }
)) {
    if ($Check.Count -ne 0) {
        throw "Persisten $($Check.Name): $($Check.Count)"
    }
}

Write-Step "Generando evidencia definitiva"

Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SGD-116B"
    version = "2.0.0"
    status = "institutionally_closed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    component_count = $Validation.component_count
    missing_dependencies = @($Validation.missing_dependencies).Count
    resolved_aliases = @($Validation.resolved_aliases).Count
    historical_dependencies = @($Validation.historical_dependencies).Count
    broken_paths = @($Validation.broken_paths).Count
    dependency_cycles = @($Validation.dependency_cycles).Count
    duplicate_codes = @($Validation.duplicate_codes).Count
    missing_master_documents = @($Validation.missing_master_documents).Count
    total_test_files = $Metrics.total_test_files
    total_documents = $Metrics.total_documents
    total_releases = $Metrics.total_releases
    validation = "approved"
})

Write-Step "Publicando release institucional"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Artifact in @(
    $AliasesPath,
    $ModelsPath,
    $DiscoveryPath,
    $GraphPath,
    $ValidatorPath,
    $TestPath,
    $PolicyPath,
    $ComponentPath,
    $DocPath,
    $ArchitecturePath,
    $OperationsPath,
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

Invoke-Checked "Ejecutando quality gate SGD-114" {
    python -m sgoda.governance.evidence_policy `
        --root "$ProjectRoot" `
        --policy "config/governance/sgd-114-policy.json" `
        --increment "SGD-116B" `
        --status "technically_completed" `
        --output "$GatePath"
}

$Gate = Get-Content `
    -LiteralPath $GatePath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El quality gate SGD-116B no contiene passed=true."
}

Invoke-Checked "Actualizando documentación maestra SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Write-JsonUtf8 -Path $DashboardPath -Data ([ordered]@{
    increment_code = "SGD-116B"
    version = "2.0.0"
    status = "institutionally_closed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    component_count = $Validation.component_count
    missing_dependencies = 0
    broken_paths = 0
    dependency_cycles = 0
    duplicate_codes = 0
    resolved_aliases = @($Validation.resolved_aliases).Count
    historical_dependencies = @($Validation.historical_dependencies).Count
    quality_gate = "approved"
    release = "SGD-116B-v2.0.0"
})

Write-Step "Resultado final"

Write-Host "SGD-116B v2.0.0 implementado y cerrado." `
    -ForegroundColor Green
Write-Host "Correctivo institucional único: OPERATIVO." `
    -ForegroundColor Green
Write-Host "Roadmap Maestro Vivo: APROBADO." `
    -ForegroundColor Green
Write-Host "Resolución canónica: APROBADA." `
    -ForegroundColor Green
Write-Host "Descubrimiento híbrido: APROBADO." `
    -ForegroundColor Green
Write-Host "Dependencias faltantes: 0." `
    -ForegroundColor Green
Write-Host "Rutas rotas: 0." `
    -ForegroundColor Green
Write-Host "Ciclos: 0." `
    -ForegroundColor Green
Write-Host "Códigos duplicados: 0." `
    -ForegroundColor Green
Write-Host "Documentos maestros faltantes: 0." `
    -ForegroundColor Green
Write-Host "Alias resueltos: $(@($Validation.resolved_aliases).Count)" `
    -ForegroundColor Cyan
Write-Host "Dependencias históricas: $(@($Validation.historical_dependencies).Count)" `
    -ForegroundColor Cyan
Write-Host "Componentes descubiertos: $($Validation.component_count)" `
    -ForegroundColor Cyan
Write-Host "Archivos de prueba: $($Metrics.total_test_files)" `
    -ForegroundColor Cyan
Write-Host "Documentos: $($Metrics.total_documents)" `
    -ForegroundColor Cyan
Write-Host "Releases: $($Metrics.total_releases)" `
    -ForegroundColor Cyan
Write-Host "Quality gate: APROBADO." `
    -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." `
    -ForegroundColor Green
Write-Host "Release: releases\SGD-116B-v2.0.0" `
    -ForegroundColor Cyan

Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
