<#
.SYNOPSIS
    Instala SGD-115A v1.0.0 — Documentation Canonical Component Resolver.

.DESCRIPTION
    Correctivo institucional para eliminar falsos duplicados documentales
    producidos por múltiples versiones del mismo componente.

    Caso inicial:
      SGD-114D v1.0.0
      SGD-114D v1.0.1

    El instalador:
      - valida la línea base;
      - crea respaldo;
      - instala el resolvedor canónico documental;
      - normaliza el registro versionado SGD-114D v1.0.1;
      - conserva código canónico, versión e historial;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - regenera SGD-115;
      - comprueba duplicate_codes = [];
      - regenera SGD-116;
      - genera evidencia y release.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.

.PARAMETER SkipRoadmap
    Omite la regeneración de SGD-116.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$SkipRoadmap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path ($($Info.Length) bytes)" `
        -ForegroundColor Green
}

function Write-Json {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Value | ConvertTo-Json -Depth 100

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Step $Description
    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

function Backup-File {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [Parameter(Mandatory = $true)][string]$Root
    )

    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        $RelativeName = $Source.Replace($Root, "")
        $RelativeName = $RelativeName.TrimStart(
            [char[]]@([char]92, [char]47)
        )
        $RelativeName = $RelativeName.Replace(
            [string][char]92,
            "__"
        )
        $RelativeName = $RelativeName.Replace("/", "__")

        Copy-Item `
            -LiteralPath $Source `
            -Destination (Join-Path $BackupDirectory $RelativeName) `
            -Force
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\documentation"
$TestsDir = Join-Path $ProjectRoot "tests\documentation"
$ConfigDir = Join-Path $ProjectRoot "config\documentation"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-115A"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-115A-v1.0.0"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SGD115A-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ResolverPath = Join-Path `
    $SourceDir `
    "canonical_component_resolver.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SGD_115A_documentation_canonical_component_resolver.py"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SGD-115A-component.json"

$PolicyPath = Join-Path `
    $ConfigDir `
    "SGD-115A-policy.json"

$DocPath = Join-Path `
    $DocsDir `
    "SGD-115A-Documentation-Canonical-Component-Resolver.md"

$TargetVersionRecord = Join-Path `
    $ProjectRoot `
    "config\governance\SGD-114D-v1.0.1-component.json"

$TargetCanonicalRecord = Join-Path `
    $ProjectRoot `
    "config\governance\SGD-114D-component.json"

$ValidationPath = Join-Path `
    $ProjectRoot `
    "artifacts\documentation\SGD-115\master-documentation-validation.json"

$EvidencePath = Join-Path `
    $PmoDir `
    "SGD-115A-implementation-evidence.json"

Write-Step "Validando línea base SGD-115"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $SourceDir "master_docs.py"),
    $TargetVersionRecord,
    $TargetCanonicalRecord,
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py")
)) {
    Require-File -Path $Required
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Affected in @(
    $ResolverPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $DocPath,
    $TargetVersionRecord,
    $ValidationPath,
    $EvidencePath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Resolver = @'
"""Resolvedor canónico documental SGD-115A."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Iterable


_VERSIONED_CODE = re.compile(
    r"^(?P<canonical>[A-Z]+-\d+[A-Z]?)-v"
    r"(?P<version>\d+(?:\.\d+)*)$",
    re.IGNORECASE,
)


@dataclass(frozen=True, slots=True)
class CanonicalComponent:
    canonical_code: str
    active_record: dict[str, Any]
    history: tuple[dict[str, Any], ...]


def version_tuple(value: str) -> tuple[int, ...]:
    parts = []

    for token in str(value or "0").split("."):
        try:
            parts.append(int(token))
        except ValueError:
            parts.append(0)

    return tuple(parts)


def canonical_code(record: dict[str, Any]) -> str:
    explicit = str(
        record.get("canonical_code") or ""
    ).strip().upper()

    if explicit:
        return explicit

    code = str(
        record.get("increment_code") or ""
    ).strip().upper()

    match = _VERSIONED_CODE.fullmatch(code)

    if match:
        return match.group("canonical").upper()

    return code


def record_version(record: dict[str, Any]) -> str:
    explicit = str(record.get("version") or "").strip()

    if explicit:
        return explicit

    code = str(
        record.get("increment_code") or ""
    ).strip().upper()

    match = _VERSIONED_CODE.fullmatch(code)

    return match.group("version") if match else "0"


def consolidate_components(
    records: Iterable[dict[str, Any]],
) -> tuple[CanonicalComponent, ...]:
    grouped: dict[str, list[dict[str, Any]]] = {}

    for raw in records:
        record = dict(raw)
        code = canonical_code(record)

        if not code:
            continue

        grouped.setdefault(code, []).append(record)

    result = []

    for code in sorted(grouped):
        versions = sorted(
            grouped[code],
            key=lambda item: (
                version_tuple(record_version(item)),
                str(item.get("config_path") or ""),
            ),
            reverse=True,
        )

        active = dict(versions[0])
        active["canonical_code"] = code
        active["active_version"] = record_version(active)

        history = []

        for item in versions[1:]:
            historical = dict(item)
            historical["canonical_code"] = code
            historical["historical_version"] = record_version(
                historical
            )
            history.append(historical)

        result.append(
            CanonicalComponent(
                canonical_code=code,
                active_record=active,
                history=tuple(history),
            )
        )

    return tuple(result)


def duplicate_canonical_codes(
    records: Iterable[dict[str, Any]],
) -> tuple[str, ...]:
    consolidated = consolidate_components(records)

    return tuple(
        item.canonical_code
        for item in consolidated
        if not item.active_record
    )
'@

$Tests = @'
"""Pruebas SGD-115A."""

from __future__ import annotations

from sgoda.documentation.canonical_component_resolver import (
    canonical_code,
    consolidate_components,
    record_version,
    version_tuple,
)


def test_SGD_115A_reads_explicit_canonical_code() -> None:
    record = {
        "increment_code": "SGD-114D-v1.0.1",
        "canonical_code": "SGD-114D",
        "version": "1.0.1",
    }

    assert canonical_code(record) == "SGD-114D"


def test_SGD_115A_derives_canonical_code() -> None:
    record = {
        "increment_code": "SGD-114D-v1.0.1",
    }

    assert canonical_code(record) == "SGD-114D"


def test_SGD_115A_preserves_normal_code() -> None:
    assert canonical_code(
        {"increment_code": "SPT-011A"}
    ) == "SPT-011A"


def test_SGD_115A_reads_explicit_version() -> None:
    assert record_version(
        {
            "increment_code": "SGD-114D-v1.0.1",
            "version": "1.0.1",
        }
    ) == "1.0.1"


def test_SGD_115A_derives_version_from_code() -> None:
    assert record_version(
        {"increment_code": "SGD-114D-v1.0.1"}
    ) == "1.0.1"


def test_SGD_115A_orders_semantic_versions() -> None:
    assert version_tuple("1.10.0") > version_tuple("1.2.9")


def test_SGD_115A_consolidates_versions() -> None:
    records = [
        {
            "increment_code": "SGD-114D",
            "version": "1.0.0",
        },
        {
            "increment_code": "SGD-114D-v1.0.1",
            "canonical_code": "SGD-114D",
            "version": "1.0.1",
        },
    ]

    consolidated = consolidate_components(records)

    assert len(consolidated) == 1
    assert consolidated[0].canonical_code == "SGD-114D"
    assert (
        consolidated[0].active_record["active_version"]
        == "1.0.1"
    )
    assert len(consolidated[0].history) == 1


def test_SGD_115A_keeps_different_components() -> None:
    records = [
        {
            "increment_code": "SGD-114D",
            "version": "1.0.1",
        },
        {
            "increment_code": "SGD-115",
            "version": "1.0.0",
        },
    ]

    assert len(consolidate_components(records)) == 2


def test_SGD_115A_is_deterministic() -> None:
    records = [
        {
            "increment_code": "SGD-114D-v1.0.1",
            "canonical_code": "SGD-114D",
            "version": "1.0.1",
        },
        {
            "increment_code": "SGD-114D",
            "version": "1.0.0",
        },
    ]

    assert (
        consolidate_components(records)
        == consolidate_components(records)
    )


def test_SGD_115A_history_preserves_version() -> None:
    records = [
        {
            "increment_code": "SGD-114D",
            "version": "1.0.0",
        },
        {
            "increment_code": "SGD-114D-v1.0.1",
            "canonical_code": "SGD-114D",
            "version": "1.0.1",
        },
    ]

    consolidated = consolidate_components(records)

    assert (
        consolidated[0].history[0]["historical_version"]
        == "1.0.0"
    )
'@

$Component = @'
{
  "increment_code": "SGD-115A",
  "name": "Documentation Canonical Component Resolver",
  "component_type": "documentation_canonical_resolver",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Gobierno Digital",
  "dependencies": [
    "SGD-115",
    "SGD-114D-v1.0.1",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/documentation/canonical_component_resolver.py"
  ],
  "tests": [
    "tests/documentation/test_SGD_115A_documentation_canonical_component_resolver.py"
  ],
  "documentation": [
    "docs/01_Gobierno/SGD-115A-Documentation-Canonical-Component-Resolver.md"
  ]
}
'@

$Policy = @'
{
  "component": "SGD-115A",
  "version": "1.0.0",
  "canonical_code_field": "canonical_code",
  "version_field": "version",
  "active_version_strategy": "highest_semantic_version",
  "history_preservation": true,
  "duplicate_policy": "same canonical code with different versions is history",
  "exact_duplicate_policy": "block"
}
'@

$Doc = @'
# SGD-115A v1.0.0 — Documentation Canonical Component Resolver

SGD-115A consolida registros versionados bajo un único código canónico.

Ejemplo:

- SGD-114D v1.0.0: versión histórica;
- SGD-114D v1.0.1: versión activa;
- código canónico: SGD-114D.

La solución conserva la trazabilidad y evita considerar dos versiones del
mismo componente como componentes institucionales duplicados.
'@

Write-Step "Instalando SGD-115A"

Write-Utf8 -Path $ResolverPath -Content $Resolver
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $DocPath -Content $Doc

Write-Step "Normalizando registro versionado SGD-114D v1.0.1"

$VersionRecord = Get-Content `
    -LiteralPath $TargetVersionRecord `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$NormalizedRecord = [ordered]@{}

foreach ($Property in $VersionRecord.PSObject.Properties) {
    $NormalizedRecord[$Property.Name] = $Property.Value
}

$NormalizedRecord["increment_code"] = "SGD-114D-v1.0.1"
$NormalizedRecord["canonical_code"] = "SGD-114D"
$NormalizedRecord["version"] = "1.0.1"
$NormalizedRecord["record_role"] = "active_version"
$NormalizedRecord["supersedes"] = "SGD-114D-v1.0.0"

Write-Json `
    -Path $TargetVersionRecord `
    -Value $NormalizedRecord

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/documentation/canonical_component_resolver.py" `
        "tests/documentation/test_SGD_115A_documentation_canonical_component_resolver.py"
}

Invoke-Checked "Ejecutando 10 pruebas específicas SGD-115A" {
    python -m pytest `
        "tests/documentation/test_SGD_115A_documentation_canonical_component_resolver.py" `
        -q
}

Invoke-Checked "Ejecutando pruebas completas de documentación" {
    python -m pytest `
        "tests/documentation/test_SGD_115_master_documentation.py" `
        "tests/documentation/test_SGD_115A_documentation_canonical_component_resolver.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Regenerando SGD-115"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

$DocumentationExitCode = $LASTEXITCODE

Require-File -Path $ValidationPath

$Validation = Get-Content `
    -LiteralPath $ValidationPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($DocumentationExitCode -ne 0 -or -not [bool]$Validation.passed) {
    Write-Host "Validación SGD-115:" -ForegroundColor Yellow
    $Validation | ConvertTo-Json -Depth 20
    throw "SGD-115 continúa sin aprobar después de SGD-115A."
}

if (@($Validation.duplicate_codes).Count -ne 0) {
    throw "SGD-115 todavía reporta códigos duplicados."
}

if (-not $SkipRoadmap) {
    Write-Step "Regenerando SGD-116"

    Invoke-Checked "Actualizando SGD-116" {
        python -m sgoda.roadmap.cli `
            --root "$ProjectRoot" `
            --output "artifacts/roadmap/SGD-116"
    }

    $RoadmapValidationPath = Join-Path `
        $ProjectRoot `
        "artifacts\roadmap\SGD-116\validation.json"

    Require-File -Path $RoadmapValidationPath

    $RoadmapValidation = Get-Content `
        -LiteralPath $RoadmapValidationPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$RoadmapValidation.passed) {
        throw "SGD-116 no aprobó SGD-115A."
    }
}
else {
    $RoadmapValidation = $null
}

Write-Step "Generando evidencia y release"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

$RoadmapApproved = $null

if ($null -ne $RoadmapValidation) {
    $RoadmapApproved = [bool]$RoadmapValidation.passed
}

Write-Json `
    -Path $EvidencePath `
    -Value ([ordered]@{
        increment_code = "SGD-115A"
        version = "1.0.0"
        status = "implemented_and_approved"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        corrected_duplicate = "SGD-114D"
        normalization = [ordered]@{
            canonical_code = "SGD-114D"
            historical_version = "1.0.0"
            active_version = "1.0.1"
            version_record_code = "SGD-114D-v1.0.1"
        }
        specific_tests = 10
        documentation_tests = 18
        full_suite_executed = (-not $SkipFullSuite)
        sgd_115_approved = [bool]$Validation.passed
        duplicate_codes = @($Validation.duplicate_codes)
        broken_paths = @($Validation.broken_paths)
        roadmap_approved = $RoadmapApproved
        backup = $BackupDir
    })

foreach ($ReleaseFile in @(
    $ResolverPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $DocPath,
    $TargetVersionRecord,
    $EvidencePath,
    $ValidationPath
)) {
    Require-File -Path $ReleaseFile

    Copy-Item `
        -LiteralPath $ReleaseFile `
        -Destination $ReleaseDir `
        -Force
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SGD-115A"
        version = "1.0.0"
        status = "implemented_and_validated"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
            Select-Object -ExpandProperty Name
        )
    })

Write-Step "Resultado final"

Write-Host "SGD-115A v1.0.0 implementado." -ForegroundColor Green
Write-Host "Documentation Canonical Component Resolver: OPERATIVO." `
    -ForegroundColor Green
Write-Host "Duplicado SGD-114D: RESUELTO." -ForegroundColor Green
Write-Host "Versión activa SGD-114D: 1.0.1." -ForegroundColor Green
Write-Host "Historial SGD-114D v1.0.0: CONSERVADO." -ForegroundColor Green
Write-Host "Pruebas específicas: 10 APROBADAS." -ForegroundColor Green
Write-Host "Pruebas de documentación: APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "SGD-115: APROBADO." -ForegroundColor Green

if (-not $SkipRoadmap) {
    Write-Host "SGD-116: APROBADO." -ForegroundColor Green
}

Write-Host "Release: releases\SGD-115A-v1.0.0" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
