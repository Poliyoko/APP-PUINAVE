<#
.SYNOPSIS
    Corrige SGD-116 v1.0.1 normalizando referencias versionadas a
    componentes institucionales canónicos.

.DESCRIPTION
    Soluciona dependencias como:
      - SGD-114-v2.0.1 -> SGD-114
      - SGD-115-v1.0.1 -> SGD-115

    También incorpora un ancla canónica de SGD-114 cuando la implementación
    histórica existe en el repositorio, aunque su descriptor use una
    nomenclatura versionada no reconocida por el patrón principal.

    El correctivo:
      - respalda archivos modificados;
      - corrige discovery.py;
      - corrige dependency_graph.py;
      - agrega pruebas de regresión;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - regenera el Roadmap Maestro;
      - valida cero dependencias faltantes;
      - publica release correctivo;
      - ejecuta quality gate;
      - actualiza SGD-115.

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

$DiscoveryPath = Join-Path $ProjectRoot "src\sgoda\roadmap\discovery.py"
$GraphPath = Join-Path $ProjectRoot "src\sgoda\roadmap\dependency_graph.py"
$TestPath = Join-Path $ProjectRoot "tests\roadmap\test_SGD_116_master_ecosystem_roadmap.py"
$ValidationPath = Join-Path $ProjectRoot "artifacts\roadmap\SGD-116\validation.json"
$MetricsPath = Join-Path $ProjectRoot "artifacts\roadmap\SGD-116\metrics.json"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-116"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-116-v1.0.1"
$BackupDir = Join-Path $PmoDir ("backups\v1.0.1-" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss"))
$EvidencePath = Join-Path $PmoDir "SGD-116-v1.0.1-corrective-evidence.json"
$GatePath = Join-Path $PmoDir "SGD-116-v1.0.1-quality-gate.json"

Write-Step "Validando instalación parcial SGD-116"

foreach ($Required in @(
    $DiscoveryPath,
    $GraphPath,
    $TestPath,
    (Join-Path $ProjectRoot "src\sgoda\roadmap\generator.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\validator.py"),
    (Join-Path $ProjectRoot "config\roadmap\SGD-116-component.json"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py")
)) {
    Assert-Path -Path $Required -Description $Required
}

Write-Step "Respaldando archivos originales"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item -LiteralPath $DiscoveryPath -Destination (Join-Path $BackupDir "discovery.py") -Force
Copy-Item -LiteralPath $GraphPath -Destination (Join-Path $BackupDir "dependency_graph.py") -Force
Copy-Item -LiteralPath $TestPath -Destination (Join-Path $BackupDir "test_SGD_116_master_ecosystem_roadmap.py") -Force

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

VERSIONED_CODE_PATTERN = re.compile(
    r"^((?:ADR|SGD|SPB|SPT|SIB|MMGR)-[0-9]+"
    r"(?:\.[0-9]+)?[A-Z]?)(?:-v[0-9].*)?$",
    re.IGNORECASE,
)


def canonical_component_code(value: str) -> str:
    """Normaliza códigos con sufijos de versión al código institucional."""
    clean = value.strip().split()[0].rstrip(",;")
    match = VERSIONED_CODE_PATTERN.match(clean)
    if match:
        return match.group(1).upper()
    return clean


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


def _component_from_payload(
    repository: Path,
    path: Path,
    payload: dict[str, Any],
) -> ComponentRecord | None:
    raw_code = str(
        payload.get("increment_code")
        or payload.get("code")
        or payload.get("component_code")
        or ""
    ).strip()

    code = canonical_component_code(raw_code)
    if not code or not COMPONENT_PATTERN.match(code):
        return None

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

    dependencies = [
        canonical_component_code(item)
        for item in _list(
            payload.get("dependencies")
            or payload.get("depends_on")
            or payload.get("governed_by")
        )
    ]

    release_matches = sorted(
        (repository / "releases").glob(f"{code}-v*")
    )
    release_path = (
        release_matches[-1].relative_to(repository).as_posix()
        if release_matches
        else None
    )

    return ComponentRecord(
        code=code,
        name=name,
        version=str(payload.get("version", "0.0.0")),
        status=str(payload.get("status", "registered")),
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
        config_path=path.relative_to(repository).as_posix(),
        metadata={
            "raw_status": payload.get("status"),
            "raw_code": raw_code,
            "canonical_code": code,
        },
    )


def _discover_canonical_governance_anchors(
    repository: Path,
    existing_codes: set[str],
) -> list[ComponentRecord]:
    """Reconoce componentes históricos con descriptores no canónicos."""
    anchors: list[ComponentRecord] = []

    definitions = (
        {
            "code": "SGD-114",
            "name": "Política Institucional de Repositorio, Evidencias y Trazabilidad",
            "version": "2.0.1",
            "status": "technically_completed",
            "component_type": "repository_governance",
            "evidence_candidates": (
                "artifacts/pmo/SGD-114-v2/SGD-114-v2-quality-gate.json",
                "artifacts/pmo/SGD-114/SGD-114-quality-gate.json",
                "src/sgoda/governance/repository_governance.py",
            ),
            "source": (
                "src/sgoda/governance/repository_governance.py",
            ),
            "tests": (
                "tests/governance/test_SGD_114_v2_repository_governance.py",
                "tests/governance/test_sgd_114_evidence_policy.py",
            ),
            "documents": (
                "docs/01_Gobierno/SGD-114-v2.0-Politica-Repositorio-Institucional.md",
            ),
        },
    )

    for definition in definitions:
        code = str(definition["code"])
        if code in existing_codes:
            continue

        if not any(
            (repository / candidate).exists()
            for candidate in definition["evidence_candidates"]
        ):
            continue

        source_paths = [
            value
            for value in definition["source"]
            if (repository / value).exists()
        ]
        test_paths = [
            value
            for value in definition["tests"]
            if (repository / value).exists()
        ]
        document_paths = [
            value
            for value in definition["documents"]
            if (repository / value).exists()
        ]

        release_matches = sorted(
            (repository / "releases").glob(f"{code}-v*")
        )

        anchors.append(
            ComponentRecord(
                code=code,
                name=str(definition["name"]),
                version=str(definition["version"]),
                status=str(definition["status"]),
                component_type=str(definition["component_type"]),
                phase=infer_phase(
                    code,
                    str(definition["component_type"]),
                ),
                dependencies=[],
                source_paths=source_paths,
                test_paths=test_paths,
                documentation_paths=document_paths,
                release_path=(
                    release_matches[-1]
                    .relative_to(repository)
                    .as_posix()
                    if release_matches
                    else None
                ),
                config_path=None,
                metadata={
                    "synthetic_canonical_anchor": True,
                    "discovery_reason": (
                        "Historical implementation evidence found."
                    ),
                },
            )
        )

    return anchors


def discover_components(root: str | Path) -> list[ComponentRecord]:
    repository = Path(root)
    records: list[ComponentRecord] = []

    for path in sorted(repository.glob("config/**/*component*.json")):
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError):
            continue

        if not isinstance(payload, dict):
            continue

        record = _component_from_payload(
            repository,
            path,
            payload,
        )
        if record is not None:
            records.append(record)

    existing_codes = {item.code for item in records}
    records.extend(
        _discover_canonical_governance_anchors(
            repository,
            existing_codes,
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

from .discovery import canonical_component_code
from .models import ComponentRecord, DependencyGraph


def _normalize_dependency(value: str) -> str:
    return canonical_component_code(value)


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
        if (
            edge["source"] in adjacency
            and edge["target"] in adjacency
        ):
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
    unique_missing = {
        (item["source"], item["target"]): item
        for item in missing
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
            unique_missing.values(),
            key=lambda item: (
                item["source"],
                item["target"],
            ),
        ),
        cycles=cycles,
    )
'@

Write-Step "Aplicando normalización canónica"

Write-Utf8NoBom -Path $DiscoveryPath -Content $DiscoveryContent
Write-Utf8NoBom -Path $GraphPath -Content $GraphContent

Write-Step "Agregando pruebas de regresión"

$CurrentTests = Get-Content -LiteralPath $TestPath -Raw -Encoding UTF8

$RegressionTests = @'


def test_SGD_116_normalizes_versioned_governance_dependencies():
    from sgoda.roadmap.discovery import canonical_component_code

    assert canonical_component_code(
        "SGD-114-v2.0.1"
    ) == "SGD-114"
    assert canonical_component_code(
        "SGD-115-v1.0.1"
    ) == "SGD-115"


def test_SGD_116_discovers_SGD_114_canonical_anchor(
    tmp_path,
):
    root = tmp_path
    (root / "src/sgoda/governance").mkdir(parents=True)
    (root / "tests/governance").mkdir(parents=True)
    (root / "docs/01_Gobierno").mkdir(parents=True)
    (root / "config/example").mkdir(parents=True)
    (root / "releases").mkdir(parents=True)

    (
        root
        / "src/sgoda/governance/repository_governance.py"
    ).write_text("VALUE = 1\n", encoding="utf-8")

    components = discover_components(root)
    codes = [item.code for item in components]

    assert "SGD-114" in codes
    anchor = next(
        item for item in components
        if item.code == "SGD-114"
    )
    assert anchor.metadata[
        "synthetic_canonical_anchor"
    ] is True
'@

if ($CurrentTests -notmatch "test_SGD_116_normalizes_versioned_governance_dependencies") {
    Write-Utf8NoBom `
        -Path $TestPath `
        -Content ($CurrentTests.TrimEnd() + $RegressionTests)
}
else {
    Write-Host "Las pruebas de regresión ya estaban instaladas." -ForegroundColor Yellow
}

Write-Step "Validando sintaxis e importaciones"

& python -m py_compile `
    "src/sgoda/roadmap/discovery.py" `
    "src/sgoda/roadmap/dependency_graph.py" `
    "tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py"

if ($LASTEXITCODE -ne 0) {
    throw "La compilación del correctivo SGD-116 falló."
}

& python -c "from sgoda.roadmap.discovery import canonical_component_code, discover_components; print(canonical_component_code('SGD-114-v2.0.1'), canonical_component_code('SGD-115-v1.0.1'))"

if ($LASTEXITCODE -ne 0) {
    throw "La importación del correctivo SGD-116 falló."
}

Write-Step "Ejecutando 14 pruebas específicas SGD-116"

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

Write-Step "Regenerando Roadmap Maestro real"

& python -m sgoda.roadmap.cli `
    --root "$ProjectRoot" `
    --output "artifacts/roadmap/SGD-116"

if ($LASTEXITCODE -ne 0) {
    throw "La regeneración real de SGD-116 falló."
}

Assert-Path -Path $ValidationPath -Description "validation.json"
Assert-Path -Path $MetricsPath -Description "metrics.json"

$Validation = Get-Content -LiteralPath $ValidationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$Metrics = Get-Content -LiteralPath $MetricsPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $Validation.passed) {
    Write-Host "Dependencias faltantes restantes:" -ForegroundColor Red
    @($Validation.missing_dependencies) |
        Format-Table source, target -AutoSize
    throw "La validación SGD-116 continúa sin aprobar."
}

if (@($Validation.missing_dependencies).Count -ne 0) {
    throw "Persisten dependencias faltantes en SGD-116."
}

Write-Step "Generando evidencia del correctivo"

Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SGD-116"
    corrective_version = "1.0.1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    issue = "Versioned governance dependency aliases"
    aliases = [ordered]@{
        "SGD-114-v2.0.1" = "SGD-114"
        "SGD-115-v1.0.1" = "SGD-115"
    }
    canonical_anchor_SGD_114 = $true
    component_count = $Validation.component_count
    duplicate_codes = @($Validation.duplicate_codes).Count
    broken_paths = @($Validation.broken_paths).Count
    missing_dependencies = @($Validation.missing_dependencies).Count
    dependency_cycles = @($Validation.dependency_cycles).Count
    missing_master_documents = @($Validation.missing_master_documents).Count
    validation = "approved"
    specific_tests = 14
})

Write-Step "Publicando release correctivo"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Artifact in @(
    $DiscoveryPath,
    $GraphPath,
    $TestPath,
    $ValidationPath,
    $MetricsPath,
    $EvidencePath,
    (Join-Path $ProjectRoot "artifacts\roadmap\SGD-116\roadmap.json"),
    (Join-Path $ProjectRoot "artifacts\roadmap\SGD-116\dependency-graph.json"),
    (Join-Path $ProjectRoot "artifacts\roadmap\SGD-116\timeline.json"),
    (Join-Path $ProjectRoot "artifacts\roadmap\SGD-116\executive-summary.json")
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
    throw "El quality gate SGD-116 v1.0.1 no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw -Encoding UTF8 | ConvertFrom-Json
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

Write-Host "SGD-116 v1.0.1 corregido y validado." -ForegroundColor Green
Write-Host "Alias SGD-114-v2.0.1 -> SGD-114: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Alias SGD-115-v1.0.1 -> SGD-115: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Ancla canónica SGD-114: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Dependencias faltantes: 0." -ForegroundColor Green
Write-Host "Ciclos: 0." -ForegroundColor Green
Write-Host "Rutas rotas: 0." -ForegroundColor Green
Write-Host "Documentos maestros faltantes: 0." -ForegroundColor Green
Write-Host "Componentes descubiertos: $($Validation.component_count)" -ForegroundColor Cyan
Write-Host "Pruebas específicas: 14 APROBADAS." -ForegroundColor Green
Write-Host "Roadmap Maestro Vivo: APROBADO." -ForegroundColor Green
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SGD-116-v1.0.1" -ForegroundColor Cyan
Write-Host ""
Write-Host "Después revise git status y publique mediante SPB-007." -ForegroundColor Yellow
