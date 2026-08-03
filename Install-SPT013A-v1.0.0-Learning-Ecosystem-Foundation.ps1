<#
SPT-013A v1.0.0 — Learning Ecosystem Foundation
Fundación institucional de la Fase Tecnológica IV.
Compatible con Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Publish -and $SkipFullSuite) {
    throw "No se permite publicar con -SkipFullSuite."
}

function Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8([string]$Path, [string]$Content) {
    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )

    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path" -ForegroundColor Green
}

function Write-Json([string]$Path, [object]$Value) {
    Write-Utf8 `
        -Path $Path `
        -Content (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
}

function Run([string]$Description, [scriptblock]$Action) {
    Step $Description
    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\learning_foundation"
$TestsDir = Join-Path $ProjectRoot "tests\learning_foundation"
$ConfigDir = Join-Path $ProjectRoot "config\learning_foundation"
$DocsDir = Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-013A"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-013A"
$ArtifactDir = Join-Path $ProjectRoot "artifacts\learning_foundation\SPT-013A"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-013A-v1.0.0"
$BackupDir = Join-Path $PmoDir ("backups\pre-SPT013A-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "models.py"
$RegistryPath = Join-Path $SourceDir "registry.py"
$ServicePath = Join-Path $SourceDir "service.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPT_013A_learning_ecosystem_foundation.py"
$ComponentPath = Join-Path $ConfigDir "SPT-013A-component.json"
$PolicyPath = Join-Path $ConfigDir "SPT-013A-policy.json"
$RoadmapPath = Join-Path $ConfigDir "SPT-013A-phase-IV.json"
$DemoPath = Join-Path $ArtifactDir "foundation-demo.json"
$EvidencePath = Join-Path $PmoDir "SPT-013A-implementation-evidence.json"
$PolicyJson = Join-Path $PmoDir "SPT-013A-policy-result.json"
$PolicyMd = Join-Path $PmoDir "SPT-013A-policy-result.md"
$NativeJson = Join-Path $PmoDir "SPT-013A-native-result.json"
$NativeMd = Join-Path $PmoDir "SPT-013A-native-result.md"

Step "Validando línea base"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\learning_platform\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\adaptive_policy_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File $Required
}

Step "Creando respaldo"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Path in @(
    $ModelsPath,
    $RegistryPath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $RoadmapPath
)) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Copy-Item -LiteralPath $Path -Destination $BackupDir -Force
    }
}

$Models = @'
"""Modelos compartidos de la Fase Tecnológica IV."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class PhaseCapability:
    code: str
    name: str
    domain: str
    status: str = "planned"
    native: bool = True
    dependencies: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class FoundationRequest:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class FoundationResponse:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True
'@

$Registry = @'
"""Registro institucional de capacidades de la Fase IV."""

from __future__ import annotations

from .models import PhaseCapability


_CAPABILITIES = (
    PhaseCapability(
        "SPT-013",
        "Gestor Institucional del Diccionario Digital",
        "dictionary",
        dependencies=("SPT-012",),
    ),
    PhaseCapability(
        "SPT-014",
        "Motor Multimedia Inteligente",
        "multimedia",
        dependencies=("SPT-013",),
    ),
    PhaseCapability(
        "SPT-015",
        "Motor de Evaluación Adaptativa",
        "assessment",
        dependencies=("SPT-013", "SPT-014"),
    ),
    PhaseCapability(
        "SPT-016",
        "Motor de Analítica del Aprendizaje",
        "analytics",
        dependencies=("SPT-015",),
    ),
    PhaseCapability(
        "SPT-017",
        "Centro de Conocimiento Puinave",
        "knowledge",
        dependencies=("SPT-013", "SPT-014"),
    ),
    PhaseCapability(
        "SPT-018",
        "IA Pedagógica SGODA",
        "pedagogical_ai",
        dependencies=(
            "SPT-013",
            "SPT-014",
            "SPT-015",
            "SPT-016",
            "SPT-017",
        ),
    ),
)


def phase_capabilities() -> tuple[PhaseCapability, ...]:
    return _CAPABILITIES


def dependency_gaps() -> tuple[dict[str, str], ...]:
    codes = {item.code for item in _CAPABILITIES}
    gaps = []

    for item in _CAPABILITIES:
        for dependency in item.dependencies:
            if dependency.startswith("SPT-01") and dependency not in codes:
                gaps.append(
                    {
                        "source": item.code,
                        "target": dependency,
                    }
                )

    return tuple(gaps)
'@

$Service = @'
"""Servicio de fundación de la Fase IV."""

from __future__ import annotations

from .models import FoundationRequest, FoundationResponse
from .registry import dependency_gaps, phase_capabilities


class LearningEcosystemFoundation:
    def execute(
        self,
        request: FoundationRequest,
    ) -> FoundationResponse:
        if request.operation == "status":
            return FoundationResponse(
                operation="status",
                status="ok",
                data={
                    "component": "SPT-013A",
                    "version": "1.0.0",
                    "phase": "Fase Tecnológica IV",
                    "capabilityCount": len(phase_capabilities()),
                    "nativeEcosystem": True,
                    "localFirst": True,
                    "freeOpenTechnology": True,
                    "mandatoryProprietaryDependencies": [],
                    "noInvention": True,
                },
            )

        if request.operation == "capabilities":
            items = [
                {
                    "code": item.code,
                    "name": item.name,
                    "domain": item.domain,
                    "status": item.status,
                    "native": item.native,
                    "dependencies": list(item.dependencies),
                }
                for item in phase_capabilities()
            ]

            return FoundationResponse(
                operation="capabilities",
                status="ok",
                data={"total": len(items), "items": items},
            )

        if request.operation == "validate":
            gaps = list(dependency_gaps())

            return FoundationResponse(
                operation="validate",
                status="ok" if not gaps else "not_approved",
                data={
                    "approved": not gaps,
                    "dependencyGaps": gaps,
                    "nativeOnly": all(
                        item.native for item in phase_capabilities()
                    ),
                },
            )

        return FoundationResponse(
            operation=request.operation,
            status="unsupported_operation",
            data={},
            warnings=("La operación no está soportada.",),
        )
'@

$Cli = @'
"""CLI SPT-013A."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import FoundationRequest
from .service import LearningEcosystemFoundation


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--operation", default="status")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    result = LearningEcosystemFoundation().execute(
        FoundationRequest(operation=args.operation)
    )

    payload = {
        "operation": result.operation,
        "status": result.status,
        "data": result.data,
        "warnings": list(result.warnings),
        "no_invention": result.no_invention,
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print("SPT-013A ejecutado correctamente.")
    print(f"Operación: {result.operation}")
    print(f"Estado: {result.status}")
    print(f"Resultado: {output}")

    return 0 if result.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""SPT-013A — Learning Ecosystem Foundation."""

from .models import FoundationRequest, FoundationResponse, PhaseCapability
from .registry import dependency_gaps, phase_capabilities
from .service import LearningEcosystemFoundation

__all__ = [
    "FoundationRequest",
    "FoundationResponse",
    "LearningEcosystemFoundation",
    "PhaseCapability",
    "dependency_gaps",
    "phase_capabilities",
]
'@

$Tests = @'
from __future__ import annotations

from sgoda.learning_foundation import (
    FoundationRequest,
    LearningEcosystemFoundation,
    dependency_gaps,
    phase_capabilities,
)


def test_SPT_013A_has_six_capabilities() -> None:
    assert len(phase_capabilities()) == 6


def test_SPT_013A_starts_with_SPT_013() -> None:
    assert phase_capabilities()[0].code == "SPT-013"


def test_SPT_013A_ends_with_SPT_018() -> None:
    assert phase_capabilities()[-1].code == "SPT-018"


def test_SPT_013A_all_capabilities_are_native() -> None:
    assert all(item.native for item in phase_capabilities())


def test_SPT_013A_has_no_dependency_gaps() -> None:
    assert dependency_gaps() == ()


def test_SPT_013A_status_is_operational() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="status")
    )

    assert response.status == "ok"
    assert response.data["component"] == "SPT-013A"


def test_SPT_013A_declares_phase_four() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="status")
    )

    assert response.data["phase"] == "Fase Tecnológica IV"


def test_SPT_013A_declares_open_technology() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="status")
    )

    assert response.data["freeOpenTechnology"] is True
    assert response.data["mandatoryProprietaryDependencies"] == []


def test_SPT_013A_preserves_no_invention() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="status")
    )

    assert response.no_invention is True
    assert response.data["noInvention"] is True


def test_SPT_013A_lists_capabilities() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="capabilities")
    )

    assert response.status == "ok"
    assert response.data["total"] == 6


def test_SPT_013A_validates_foundation() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="validate")
    )

    assert response.status == "ok"
    assert response.data["approved"] is True


def test_SPT_013A_rejects_unknown_operation() -> None:
    response = LearningEcosystemFoundation().execute(
        FoundationRequest(operation="unknown")
    )

    assert response.status == "unsupported_operation"


def test_SPT_013A_is_deterministic() -> None:
    service = LearningEcosystemFoundation()
    request = FoundationRequest(operation="status")

    assert service.execute(request) == service.execute(request)


def test_SPT_013A_domains_are_complete() -> None:
    assert {item.domain for item in phase_capabilities()} == {
        "dictionary",
        "multimedia",
        "assessment",
        "analytics",
        "knowledge",
        "pedagogical_ai",
    }
'@

$Component = @'
{
  "increment_code": "SPT-013A",
  "name": "Learning Ecosystem Foundation",
  "component_type": "learning_ecosystem_foundation",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica IV",
  "native_ecosystem": true,
  "ecosystem_role": "native_component",
  "technology_policy": "free_open_optional_proprietary",
  "mandatory_proprietary_dependencies": [],
  "institutional_terminology": "integrado nativamente al ecosistema SGODA-PUINAVE",
  "dependencies": [
    "SPT-012",
    "SGD-114D",
    "SGD-114E",
    "SGD-115A",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/learning_foundation/models.py",
    "src/sgoda/learning_foundation/registry.py",
    "src/sgoda/learning_foundation/service.py",
    "src/sgoda/learning_foundation/cli.py"
  ],
  "tests": [
    "tests/learning_foundation/test_SPT_013A_learning_ecosystem_foundation.py"
  ],
  "documentation": [
    "docs/08_Fase_Tecnologica_IV/SPT-013A/SPT-013A-Arquitectura.md",
    "docs/08_Fase_Tecnologica_IV/SPT-013A/SPT-013A-Roadmap.md"
  ]
}
'@

$Policy = @'
{
  "component": "SPT-013A",
  "version": "1.0.0",
  "native_ecosystem": true,
  "local_first": true,
  "no_invention": true,
  "free_open_technology": true,
  "mandatory_proprietary_dependencies": []
}
'@

$Roadmap = @'
{
  "phase": "Fase Tecnológica IV",
  "foundation": "SPT-013A",
  "components": [
    "SPT-013",
    "SPT-014",
    "SPT-015",
    "SPT-016",
    "SPT-017",
    "SPT-018"
  ]
}
'@

$ArchitectureDoc = @'
# SPT-013A — Arquitectura

SPT-013A inicia formalmente la Fase Tecnológica IV y establece una base
común para diccionario, multimedia, evaluación, analítica, conocimiento
cultural e IA pedagógica.

Todos los componentes son nativos del ecosistema SGODA-PUINAVE, utilizan
tecnologías gratuitas y abiertas cuando corresponde y no requieren
dependencias propietarias obligatorias.
'@

$RoadmapDoc = @'
# SPT-013A — Roadmap de la Fase IV

1. SPT-013 — Gestor Institucional del Diccionario Digital.
2. SPT-014 — Motor Multimedia Inteligente.
3. SPT-015 — Motor de Evaluación Adaptativa.
4. SPT-016 — Motor de Analítica del Aprendizaje.
5. SPT-017 — Centro de Conocimiento Puinave.
6. SPT-018 — IA Pedagógica SGODA.
'@

Step "Instalando SPT-013A"

Write-Utf8 $ModelsPath $Models
Write-Utf8 $RegistryPath $Registry
Write-Utf8 $ServicePath $Service
Write-Utf8 $CliPath $Cli
Write-Utf8 $InitPath $Init
Write-Utf8 $TestPath $Tests
Write-Utf8 $ComponentPath $Component
Write-Utf8 $PolicyPath $Policy
Write-Utf8 $RoadmapPath $Roadmap
Write-Utf8 (Join-Path $DocsDir "SPT-013A-Arquitectura.md") $ArchitectureDoc
Write-Utf8 (Join-Path $DocsDir "SPT-013A-Roadmap.md") $RoadmapDoc

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/learning_foundation/models.py" `
        "src/sgoda/learning_foundation/registry.py" `
        "src/sgoda/learning_foundation/service.py" `
        "src/sgoda/learning_foundation/cli.py" `
        "src/sgoda/learning_foundation/__init__.py" `
        "tests/learning_foundation/test_SPT_013A_learning_ecosystem_foundation.py"
}

Run "Ejecutando 14 pruebas específicas SPT-013A" {
    python -m pytest `
        "tests/learning_foundation/test_SPT_013A_learning_ecosystem_foundation.py" `
        -q
}

if (-not $SkipFullSuite) {
    Run "Ejecutando suite completa" {
        python -m pytest
    }
}

Run "Ejecutando demostración" {
    python -m sgoda.learning_foundation.cli `
        --operation "status" `
        --output "$DemoPath"
}

$Demo = Get-Content -LiteralPath $DemoPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración SPT-013A no fue aprobada."
}

if (-not [bool]$Demo.data.nativeEcosystem) {
    throw "La demostración no declaró ecosistema nativo."
}

Step "Creando evidencia y release"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json `
    -Path $EvidencePath `
    -Value ([ordered]@{
        increment_code = "SPT-013A"
        version = "1.0.0"
        status = "implemented_and_tested"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        specific_tests = 14
        full_suite_executed = (-not $SkipFullSuite)
        demo_approved = $true
        native_ecosystem = $true
        mandatory_proprietary_dependencies = @()
        backup = $BackupDir
    })

foreach ($File in @(
    $ModelsPath,
    $RegistryPath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $RoadmapPath,
    $DemoPath,
    $EvidencePath,
    (Join-Path $DocsDir "SPT-013A-Arquitectura.md"),
    (Join-Path $DocsDir "SPT-013A-Roadmap.md")
)) {
    Require-File $File
    Copy-Item -LiteralPath $File -Destination $ReleaseDir -Force
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SPT-013A"
        version = "1.0.0"
        status = "implemented_and_tested"
        files = @(
            Get-ChildItem -LiteralPath $ReleaseDir -File |
                Select-Object -ExpandProperty Name
        )
    })

Step "Evaluando SGD-114D"

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$ProjectRoot" `
    --increment "SPT-013A" `
    --output-json "$PolicyJson" `
    --output-md "$PolicyMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114D no aprobó SPT-013A."
}

Step "Evaluando SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$NativeJson" `
    --output-md "$NativeMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SPT-013A."
}

Run "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Run "Regenerando SGD-116" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

if ($Publish) {
    Step "Publicando mediante SPB-007"

    & (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1") `
        -Publish `
        -CommitMessage "feat(learning): implement SPT-013A learning ecosystem foundation" `
        -EvidenceCommitMessage "chore(learning): publish SPT-013A evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SPT-013A v1.0.0 implementado." -ForegroundColor Green
Write-Host "Fase Tecnológica IV: INICIADA FORMALMENTE." -ForegroundColor Green
Write-Host "Learning Ecosystem Foundation: OPERATIVA." -ForegroundColor Green
Write-Host "Pruebas específicas: 14 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Demostración: APROBADA." -ForegroundColor Green
Write-Host "SGD-114D: APROBADO." -ForegroundColor Green
Write-Host "SGD-114E: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-013A-v1.0.0" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
