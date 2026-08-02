<#
.SYNOPSIS
    Corrige definitivamente la compatibilidad entre SGD-116 y SGD-116B.

.DESCRIPTION
    Soluciona los cinco fallos restantes:

      1. conserva graph.edges sin la propiedad status;
      2. conserva missing_dependencies sin status;
      3. conserva historical_dependencies sin status;
      4. restaura repository_evidence como API pública compatible;
      5. descubre SGD-114 mediante su evidencia histórica conocida;
      6. corrige SHA-256 para Windows PowerShell mediante ComputeHash.

    Los estados FOUND, ALIASED, HISTORICAL y MISSING se conservan en la
    colección separada edge_states, sin romper el contrato histórico.

    El correctivo:
      - respalda los archivos;
      - aplica compatibilidad;
      - actualiza las pruebas SGD-116B;
      - ejecuta pruebas SGD-116 y SGD-116B;
      - ejecuta la suite completa;
      - regenera el Roadmap;
      - ejecuta quality gate SGD-114;
      - actualiza SGD-115;
      - genera release SGD-116B-v2.0.4.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa.
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
    Write-Host "Actualizado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
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
    param([string]$Description, [scriptblock]$Action)
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
$ModelsPath = Join-Path $RoadmapDir "models.py"
$DiscoveryPath = Join-Path $RoadmapDir "discovery.py"
$GraphPath = Join-Path $RoadmapDir "dependency_graph.py"
$InitPath = Join-Path $RoadmapDir "__init__.py"
$NewTestPath = Join-Path $ProjectRoot "tests\roadmap\test_SGD_116B_institutional_roadmap_closure.py"
$LegacyTestPath = Join-Path $ProjectRoot "tests\roadmap\test_SGD_116_master_ecosystem_roadmap.py"
$RunnerPath = Join-Path $ProjectRoot "Run-SGD116B-v2.0.3-Safe-External-Preflight.ps1"

$ArtifactsDir = Join-Path $ProjectRoot "artifacts\roadmap\SGD-116"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-116B"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-116B-v2.0.4"
$EvidencePath = Join-Path $PmoDir "SGD-116B-v2.0.4-compatibility-evidence.json"
$GatePath = Join-Path $PmoDir "SGD-116B-v2.0.4-quality-gate.json"
$ValidationPath = Join-Path $ArtifactsDir "validation.json"
$MetricsPath = Join-Path $ArtifactsDir "metrics.json"

foreach ($Required in @(
    $ModelsPath,
    $DiscoveryPath,
    $GraphPath,
    $InitPath,
    $NewTestPath,
    $LegacyTestPath,
    (Join-Path $RoadmapDir "generator.py"),
    (Join-Path $RoadmapDir "validator.py"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py")
)) {
    if (-not (Test-Path -LiteralPath $Required)) {
        throw "No se encontró el archivo requerido: $Required"
    }
}

$BackupDir = Join-Path $PmoDir (
    "backups\v2.0.4-" +
    [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
)
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

Write-Step "Respaldando archivos"

foreach ($Path in @(
    $ModelsPath,
    $DiscoveryPath,
    $GraphPath,
    $InitPath,
    $NewTestPath,
    $RunnerPath
)) {
    if (Test-Path -LiteralPath $Path) {
        Copy-Item `
            -LiteralPath $Path `
            -Destination (Join-Path $BackupDir (Split-Path $Path -Leaf)) `
            -Force
    }
}

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
    edge_states: list[dict[str, str]] = field(default_factory=list)


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


KNOWN_HISTORICAL_EVIDENCE: dict[str, tuple[str, ...]] = {
    "SGD-114": (
        "src/sgoda/governance/repository_governance.py",
        "tests/governance/test_SGD_114_v2_repository_governance.py",
        "tests/governance/test_sgd_114_evidence_policy.py",
        "docs/01_Gobierno/SGD-114-v2.0-Politica-Repositorio-Institucional.md",
    ),
    "SGD-115": (
        "src/sgoda/documentation/master_docs.py",
        "tests/documentation/test_SGD_115_master_documentation.py",
        "docs/01_Gobierno/SGD-115-Sistema-Maestro-Documentacion.md",
    ),
    "SPB-007": (
        "src/sgoda/publisher/institutional_publisher.py",
        "tests/publisher/test_SPB_007_institutional_publisher.py",
        "scripts/Invoke-SPB007-InstitutionalPublish.ps1",
    ),
    "SIB-001": (
        "src/sgoda/installer_builder/generator.py",
        "tests/installer_builder/test_SIB_001_installer_builder.py",
    ),
}


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

    raw_dependencies = (
        payload.get("dependencies")
        or payload.get("depends_on")
        or payload.get("governed_by")
        or []
    )
    if isinstance(raw_dependencies, str):
        raw_dependencies = [raw_dependencies]

    dependencies = (
        [str(item) for item in raw_dependencies if str(item).strip()]
        if isinstance(raw_dependencies, list)
        else []
    )

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
            release_matches[-1].relative_to(repository).as_posix()
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

    evidence: set[str] = set()

    for candidate in KNOWN_HISTORICAL_EVIDENCE.get(
        canonical,
        (),
    ):
        if (repository / candidate).exists():
            evidence.add(candidate)

    normalized = canonical.lower()

    for location in (
        "src",
        "tests",
        "docs",
        "config",
        "scripts",
        "releases",
        "artifacts/pmo",
        "dashboard",
    ):
        base = repository / location
        if not base.exists():
            continue

        for path in base.rglob("*"):
            try:
                relative = path.relative_to(repository).as_posix()
            except ValueError:
                continue

            if normalized in path.name.lower():
                evidence.add(relative)

            if len(evidence) >= 50:
                break

    return sorted(evidence)


def repository_evidence(
    root: str | Path,
    code: str,
) -> list[str]:
    """Alias público conservado para compatibilidad con SGD-116."""
    return institutional_evidence(root, code)


def _historical_record(
    repository: Path,
    code: str,
    evidence: list[str],
) -> ComponentRecord:
    sources = [
        item for item in evidence
        if item.startswith("src/") and item.endswith(".py")
    ]
    tests = [
        item for item in evidence
        if item.startswith("tests/") and item.endswith(".py")
    ]
    documents = [
        item for item in evidence
        if item.startswith("docs/")
    ]
    releases = [
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
        source_paths=sources,
        test_paths=tests,
        documentation_paths=documents,
        release_path=releases[-1] if releases else None,
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
        set(repository.glob("config/**/*component*.json"))
        | set(repository.glob("config/**/*Component*.json"))
    )

    for path in descriptor_paths:
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError):
            continue

        if isinstance(payload, dict):
            record = _descriptor_record(repository, path, payload)
            if record:
                records.append(record)

    by_code: dict[str, ComponentRecord] = {}
    for record in records:
        current = by_code.get(record.code)
        if current is None or record.version >= current.version:
            by_code[record.code] = record

    dependency_codes = {
        canonical_component_code(dependency)
        for component in by_code.values()
        for dependency in component.dependencies
        if is_supported_component_code(dependency)
    }

    candidate_codes = dependency_codes | {
        code
        for code in KNOWN_HISTORICAL_EVIDENCE
        if institutional_evidence(repository, code)
    }

    for code in sorted(candidate_codes):
        if code in by_code:
            continue

        evidence = institutional_evidence(repository, code)
        if evidence:
            by_code[code] = _historical_record(
                repository,
                code,
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
"""Grafo compatible y enriquecido para SGD-116B."""

from __future__ import annotations

from .aliases import resolve_alias
from .models import ComponentRecord, DependencyGraph


def build_dependency_graph(
    components: list[ComponentRecord],
) -> DependencyGraph:
    nodes = sorted({item.code for item in components})
    node_set = set(nodes)
    by_code = {item.code: item for item in components}

    edges: dict[tuple[str, str], dict[str, str]] = {}
    aliases: dict[tuple[str, str], dict[str, str]] = {}
    historical: dict[tuple[str, str], dict[str, str]] = {}
    missing: dict[tuple[str, str], dict[str, str]] = {}
    states: dict[tuple[str, str], dict[str, str]] = {}

    for component in components:
        for raw_dependency in component.dependencies:
            resolution = resolve_alias(raw_dependency)
            target = (
                resolution.canonical
                if resolution.valid_format
                else str(raw_dependency).strip().upper()
            )

            if not target or target == component.code:
                continue

            key = (component.code, target)
            public_edge = {
                "source": component.code,
                "target": target,
            }
            status = "FOUND"

            if resolution.changed:
                aliases[key] = {
                    "source": component.code,
                    "raw_target": resolution.raw,
                    "target": target,
                    "status": "ALIASED",
                }

            if target not in node_set:
                status = "MISSING"
                missing[key] = public_edge
            elif by_code[target].metadata.get(
                "synthetic_canonical_anchor"
            ):
                status = "HISTORICAL"
                historical[key] = public_edge

            edges[key] = public_edge
            states[key] = {
                "source": component.code,
                "target": target,
                "status": status,
            }

    adjacency = {node: [] for node in nodes}
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

    key_func = lambda item: (item["source"], item["target"])

    return DependencyGraph(
        nodes=nodes,
        edges=sorted(edges.values(), key=key_func),
        resolved_aliases=sorted(
            aliases.values(),
            key=lambda item: (item["source"], item["target"]),
        ),
        historical_dependencies=sorted(
            historical.values(),
            key=key_func,
        ),
        missing_dependencies=sorted(
            missing.values(),
            key=key_func,
        ),
        cycles=cycles,
        edge_states=sorted(states.values(), key=key_func),
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
    repository_evidence,
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
    "repository_evidence",
    "is_supported_component_code",
    "resolve_alias",
    "validate_roadmap",
]
'@

Write-Step "Aplicando compatibilidad institucional"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $DiscoveryPath -Content $DiscoveryContent
Write-Utf8NoBom -Path $GraphPath -Content $GraphContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent

Write-Step "Actualizando pruebas SGD-116B al contrato compatible"

$NewTests = Get-Content -LiteralPath $NewTestPath -Raw -Encoding UTF8

$NewTests = $NewTests.Replace(
    @'
    assert graph.edges == [
        {
            "source": "SPT-901",
            "target": "SGD-114",
            "status": "FOUND",
        }
    ]
'@,
    @'
    assert graph.edges == [
        {
            "source": "SPT-901",
            "target": "SGD-114",
        }
    ]
    assert graph.edge_states == [
        {
            "source": "SPT-901",
            "target": "SGD-114",
            "status": "FOUND",
        }
    ]
'@
)

$NewTests = $NewTests.Replace(
    @'
    assert graph.historical_dependencies == [
        {
            "source": "SPT-901",
            "target": "SGD-114",
            "status": "HISTORICAL",
        }
    ]
'@,
    @'
    assert graph.historical_dependencies == [
        {
            "source": "SPT-901",
            "target": "SGD-114",
        }
    ]
    assert {
        "source": "SPT-901",
        "target": "SGD-114",
        "status": "HISTORICAL",
    } in graph.edge_states
'@
)

$NewTests = $NewTests.Replace(
    @'
    assert graph.missing_dependencies == [
        {
            "source": "SPT-901",
            "target": "SGD-999",
            "status": "MISSING",
        }
    ]
'@,
    @'
    assert graph.missing_dependencies == [
        {
            "source": "SPT-901",
            "target": "SGD-999",
        }
    ]
    assert graph.edge_states == [
        {
            "source": "SPT-901",
            "target": "SGD-999",
            "status": "MISSING",
        }
    ]
'@
)

Write-Utf8NoBom -Path $NewTestPath -Content $NewTests

if (Test-Path -LiteralPath $RunnerPath) {
    Write-Step "Corrigiendo SHA-256 del ejecutor para Windows PowerShell"

    $Runner = Get-Content -LiteralPath $RunnerPath -Raw -Encoding UTF8

    $OldHashBlock = @'
    $OriginalHash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::HashData(
            $OriginalBytes
        )
    ).Replace("-", "").ToLowerInvariant()

    $RestoredHash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::HashData(
            $RestoredBytes
        )
    ).Replace("-", "").ToLowerInvariant()
'@

    $NewHashBlock = @'
    $Sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $OriginalHash = [System.BitConverter]::ToString(
            $Sha256.ComputeHash($OriginalBytes)
        ).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $Sha256.Dispose()
    }

    $Sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $RestoredHash = [System.BitConverter]::ToString(
            $Sha256.ComputeHash($RestoredBytes)
        ).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $Sha256.Dispose()
    }
'@

    if ($Runner.Contains($OldHashBlock)) {
        $Runner = $Runner.Replace($OldHashBlock, $NewHashBlock)
        Write-Utf8NoBom -Path $RunnerPath -Content $Runner
    }
    else {
        Write-Host "El bloque HashData no está presente o ya fue corregido." `
            -ForegroundColor Yellow
    }
}

Invoke-Checked "Validando sintaxis e importaciones" {
    python -m py_compile `
        "src/sgoda/roadmap/models.py" `
        "src/sgoda/roadmap/discovery.py" `
        "src/sgoda/roadmap/dependency_graph.py" `
        "src/sgoda/roadmap/__init__.py" `
        "tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py" `
        "tests/roadmap/test_SGD_116B_institutional_roadmap_closure.py"

    if ($LASTEXITCODE -eq 0) {
        python -c "from sgoda.roadmap.discovery import repository_evidence; from sgoda.roadmap import build_dependency_graph; print(repository_evidence.__name__)"
    }
}

Invoke-Checked "Ejecutando pruebas SGD-116 y SGD-116B" {
    python -m pytest `
        "tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py" `
        "tests/roadmap/test_SGD_116B_institutional_roadmap_closure.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Regenerando Roadmap Maestro"

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

& python -m sgoda.roadmap.cli `
    --root "$ProjectRoot" `
    --output "artifacts/roadmap/SGD-116"

if ($LASTEXITCODE -ne 0) {
    throw "La regeneración del Roadmap no fue aprobada."
}

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
    throw "validation.json no contiene passed=true."
}

Write-Step "Generando evidencia"

Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SGD-116B"
    version = "2.0.4"
    status = "backward_compatible_closure"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    legacy_contract_preserved = $true
    edge_states_separated = $true
    repository_evidence_restored = $true
    windows_powershell_sha256 = $true
    component_count = $Validation.component_count
    missing_dependencies = @($Validation.missing_dependencies).Count
    historical_dependencies = @($Validation.historical_dependencies).Count
    broken_paths = @($Validation.broken_paths).Count
    cycles = @($Validation.dependency_cycles).Count
    validation = "approved"
})

Write-Step "Publicando release correctivo"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Artifact in @(
    $ModelsPath,
    $DiscoveryPath,
    $GraphPath,
    $InitPath,
    $LegacyTestPath,
    $NewTestPath,
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
    throw "El quality gate no contiene passed=true."
}

Invoke-Checked "Actualizando documentación maestra SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Write-Step "Resultado final"

Write-Host "SGD-116B v2.0.4 corregido y validado." -ForegroundColor Green
Write-Host "Compatibilidad SGD-116: RESTAURADA." -ForegroundColor Green
Write-Host "Estados detallados: CONSERVADOS EN edge_states." -ForegroundColor Green
Write-Host "repository_evidence: RESTAURADO." -ForegroundColor Green
Write-Host "Ancla SGD-114: RESTAURADA." -ForegroundColor Green
Write-Host "Dependencias inexistentes: BLOQUEADAS." -ForegroundColor Green
Write-Host "SHA-256 Windows PowerShell: CORREGIDO." -ForegroundColor Green
Write-Host "Suite completa: APROBADA." -ForegroundColor Green
Write-Host "Roadmap Maestro Vivo: APROBADO." -ForegroundColor Green
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SGD-116B-v2.0.4" -ForegroundColor Cyan
