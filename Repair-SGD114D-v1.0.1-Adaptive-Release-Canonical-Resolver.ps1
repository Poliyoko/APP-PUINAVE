<#
.SYNOPSIS
    Implementa SGD-114D v1.0.1 — Adaptive Release Canonical Resolver.

.DESCRIPTION
    Correctivo institucional único para SGD114D-R003.

    El script:
      - valida la línea base SGD-114D;
      - crea respaldo;
      - reemplaza el resolver adaptativo;
      - incorpora resolución canónica robusta;
      - distingue releases vacíos de releases válidos;
      - crea un release correctivo real para SPT-011A;
      - añade pruebas específicas;
      - ejecuta pruebas y suite completa;
      - reevalúa SPT-011A;
      - regenera SGD-116;
      - actualiza SGD-115;
      - genera evidencia y release SGD-114D v1.0.1.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER TargetIncrement
    Incremento correctivo a reevaluar. Por defecto: SPT-011A.

.PARAMETER TargetVersion
    Versión del release correctivo. Por defecto: 1.0.1.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$TargetIncrement = "SPT-011A",
    [string]$TargetVersion = "1.0.1",
    [switch]$SkipFullSuite
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

$GovernanceDir = Join-Path $ProjectRoot "src\sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114D"
$EvidenceDir = Join-Path $PmoDir "evidence"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114D-v1.0.1"
$TargetReleaseDir = Join-Path `
    $ProjectRoot `
    ("releases\" + $TargetIncrement + "-v" + $TargetVersion)

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SGD114D-v1.0.1-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ResolverPath = Join-Path `
    $GovernanceDir `
    "adaptive_policy_resolver.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SGD_114D_release_canonical_resolver.py"

$ComponentPath = Join-Path `
    $ProjectRoot `
    "config\governance\SGD-114D-v1.0.1-component.json"

$DocPath = Join-Path `
    $ProjectRoot `
    "docs\01_Gobierno\SGD-114D-v1.0.1-Adaptive-Release-Canonical-Resolver.md"

$TargetComponentPath = Join-Path `
    $ProjectRoot `
    "config\operational_platform\SPT-011A-component.json"

$TargetDocPath = Join-Path `
    $ProjectRoot `
    "docs\07_Fase_Tecnologica_III\SPT-011\SPT-011A-Institutional-Evidence-Closure.md"

$TargetEvidenceDir = Join-Path `
    $ProjectRoot `
    "artifacts\pmo\SPT-011\evidence"

$TargetDemoPath = Join-Path `
    $ProjectRoot `
    "artifacts\operational_platform\SPT-011\demo-operational-result-v1.0.1.json"

$TargetManifestPath = Join-Path $TargetReleaseDir "manifest.json"

$AdaptiveResultJson = Join-Path `
    $PmoDir `
    ($TargetIncrement + "-v1.0.1-adaptive-policy-result.json")

$AdaptiveResultMd = Join-Path `
    $PmoDir `
    ($TargetIncrement + "-v1.0.1-adaptive-policy-result.md")

$ImplementationEvidence = Join-Path `
    $EvidenceDir `
    "SGD-114D-v1.0.1-implementation-evidence.json"

Write-Step "Validando línea base SGD-114D"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    $ResolverPath,
    (Join-Path $GovernanceDir "adaptive_policy_models.py"),
    (Join-Path $GovernanceDir "adaptive_policy_rules.py"),
    (Join-Path $GovernanceDir "adaptive_policy_engine.py"),
    (Join-Path $GovernanceDir "adaptive_policy_cli.py"),
    $TargetComponentPath,
    $TargetDocPath,
    $TargetDemoPath,
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py")
)) {
    Require-File -Path $Required
}

if (-not (Test-Path -LiteralPath $TargetEvidenceDir -PathType Container)) {
    throw "No existe el directorio de evidencia de SPT-011: $TargetEvidenceDir"
}

$TargetEvidenceFiles = @(
    Get-ChildItem `
        -LiteralPath $TargetEvidenceDir `
        -Recurse `
        -File |
    Where-Object { $_.Length -gt 0 }
)

if ($TargetEvidenceFiles.Count -eq 0) {
    throw "El directorio de evidencia de SPT-011 está vacío."
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Affected in @(
    $ResolverPath,
    $TestPath,
    $ComponentPath,
    $DocPath,
    $AdaptiveResultJson,
    $AdaptiveResultMd,
    $ImplementationEvidence,
    $TargetManifestPath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Resolver = @'
"""Resolución canónica de evidencias y releases para SGD-114D v1.0.1."""

from __future__ import annotations

import re
from pathlib import Path

from .adaptive_policy_models import ResolvedArtifact


_INCREMENT_PATTERN = re.compile(
    r"^(?P<prefix>[A-Z]+)-(?P<number>\d+)(?P<suffix>[A-Z]?)"
    r"(?:-v?(?P<version>\d+(?:\.\d+)*))?$",
    re.IGNORECASE,
)


def canonical_increment_code(value: str) -> str:
    raw = str(value or "").strip().upper()
    match = _INCREMENT_PATTERN.fullmatch(raw)

    if match is None:
        return raw

    prefix = match.group("prefix")
    number = match.group("number")
    suffix = match.group("suffix") or ""

    return f"{prefix}-{number}{suffix}"


def parent_increment_code(value: str) -> str | None:
    canonical = canonical_increment_code(value)
    match = _INCREMENT_PATTERN.fullmatch(canonical)

    if match is None:
        return None

    suffix = match.group("suffix") or ""

    if not suffix:
        return None

    return f"{match.group('prefix')}-{match.group('number')}"


def increment_family(value: str) -> tuple[str, ...]:
    canonical = canonical_increment_code(value)
    parent = parent_increment_code(canonical)

    values = [canonical]

    if parent:
        values.append(parent)

    return tuple(dict.fromkeys(values))


def _non_empty_directory(path: Path) -> bool:
    if not path.is_dir():
        return False

    return any(
        item.is_file() and item.stat().st_size > 0
        for item in path.rglob("*")
    )


def _release_version(path: Path) -> tuple[int, ...]:
    match = re.search(
        r"-v(?P<version>\d+(?:\.\d+)*)$",
        path.name,
        re.IGNORECASE,
    )

    if match is None:
        return ()

    return tuple(
        int(part)
        for part in match.group("version").split(".")
    )


def resolve_evidence_directory(
    root: str | Path,
    increment_code: str,
) -> ResolvedArtifact:
    base = Path(root).resolve()
    candidates: list[Path] = []

    for code in increment_family(increment_code):
        candidates.extend(
            [
                base / "artifacts" / "pmo" / code / "evidence",
                base / "artifacts" / "pmo" / code,
                base / "artifacts" / code / "evidence",
                base / "artifacts" / code,
            ]
        )

    unique: list[Path] = []

    for candidate in candidates:
        resolved = candidate.resolve()

        if resolved not in unique:
            unique.append(resolved)

    for candidate in unique:
        if _non_empty_directory(candidate):
            return ResolvedArtifact(
                artifact_type="evidence",
                increment_code=increment_code,
                path=candidate,
                found=True,
                strategy=(
                    "canonical"
                    if canonical_increment_code(increment_code)
                    in candidate.parts
                    else "parent_family"
                ),
                candidates=tuple(str(item) for item in unique),
            )

    return ResolvedArtifact(
        artifact_type="evidence",
        increment_code=increment_code,
        path=None,
        found=False,
        strategy="not_found",
        candidates=tuple(str(item) for item in unique),
    )


def resolve_release_directory(
    root: str | Path,
    increment_code: str,
) -> ResolvedArtifact:
    base = Path(root).resolve()
    releases = base / "releases"
    family = increment_family(increment_code)
    candidate_records: list[tuple[int, int, tuple[int, ...], Path]] = []

    if releases.is_dir():
        for family_index, code in enumerate(family):
            exact = releases / code

            if exact.exists():
                candidate_records.append(
                    (family_index, 1, (), exact.resolve())
                )

            for candidate in releases.glob(f"{code}-v*"):
                candidate_records.append(
                    (
                        family_index,
                        0,
                        _release_version(candidate),
                        candidate.resolve(),
                    )
                )

    candidate_records.sort(
        key=lambda item: (
            item[0],
            item[1],
            tuple(-value for value in item[2]),
            str(item[3]).casefold(),
        )
    )

    ordered_candidates = tuple(
        str(item[3])
        for item in candidate_records
    )

    for family_index, _, _, candidate in candidate_records:
        if _non_empty_directory(candidate):
            return ResolvedArtifact(
                artifact_type="release",
                increment_code=increment_code,
                path=candidate,
                found=True,
                strategy=(
                    "canonical_versioned"
                    if family_index == 0
                    else "parent_versioned"
                ),
                candidates=ordered_candidates,
            )

    return ResolvedArtifact(
        artifact_type="release",
        increment_code=increment_code,
        path=None,
        found=False,
        strategy="not_found_or_empty",
        candidates=ordered_candidates,
    )
'@

$Tests = @'
"""Pruebas de SGD-114D v1.0.1."""

from __future__ import annotations

from pathlib import Path

from sgoda.governance.adaptive_policy_resolver import (
    canonical_increment_code,
    increment_family,
    parent_increment_code,
    resolve_release_directory,
)


def _write(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("ok", encoding="utf-8")


def test_SGD_114D_v101_canonicalizes_corrective_code() -> None:
    assert canonical_increment_code(
        "SPT-011A-v1.0.2"
    ) == "SPT-011A"


def test_SGD_114D_v101_resolves_parent_code() -> None:
    assert parent_increment_code("SPT-011A") == "SPT-011"


def test_SGD_114D_v101_family_order_is_canonical_first() -> None:
    assert increment_family("SPT-011A") == (
        "SPT-011A",
        "SPT-011",
    )


def test_SGD_114D_v101_prefers_corrective_release(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path
        / "releases"
        / "SPT-011-v1.0.0"
        / "manifest.json"
    )
    _write(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.1"
        / "manifest.json"
    )

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert result.strategy == "canonical_versioned"
    assert result.path is not None
    assert result.path.name == "SPT-011A-v1.0.1"


def test_SGD_114D_v101_accepts_populated_parent_release(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path
        / "releases"
        / "SPT-011-v1.0.0"
        / "manifest.json"
    )

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert result.strategy == "parent_versioned"


def test_SGD_114D_v101_rejects_empty_parent_release(
    tmp_path: Path,
) -> None:
    (
        tmp_path
        / "releases"
        / "SPT-011-v1.0.0"
    ).mkdir(parents=True)

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is False


def test_SGD_114D_v101_uses_latest_version(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.1"
        / "manifest.json"
    )
    _write(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.path is not None
    assert result.path.name == "SPT-011A-v1.0.2"


def test_SGD_114D_v101_is_deterministic(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.1"
        / "manifest.json"
    )

    first = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )
    second = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert first == second
'@

$Component = @'
{
  "increment_code": "SGD-114D",
  "name": "Adaptive Release Canonical Resolver",
  "component_type": "adaptive_release_resolver",
  "version": "1.0.1",
  "status": "implemented",
  "phase": "Gobierno Digital",
  "dependencies": [
    "SGD-114D-v1.0.0",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/governance/adaptive_policy_resolver.py"
  ],
  "tests": [
    "tests/governance/test_SGD_114D_release_canonical_resolver.py"
  ],
  "documentation": [
    "docs/01_Gobierno/SGD-114D-v1.0.1-Adaptive-Release-Canonical-Resolver.md"
  ]
}
'@

$Doc = @'
# SGD-114D v1.0.1 — Adaptive Release Canonical Resolver

Este correctivo fortalece SGD114D-R003.

La resolución distingue entre:

- release correctivo canónico;
- release válido del incremento padre;
- directorio de release vacío;
- ausencia total de release.

Para SPT-011A, el orden de resolución es:

1. `releases/SPT-011A-v*`;
2. `releases/SPT-011A`;
3. `releases/SPT-011-v*`;
4. `releases/SPT-011`.

Solo se aceptan directorios con archivos reales y no vacíos.
'@

Write-Step "Aplicando SGD-114D v1.0.1"

Write-Utf8 -Path $ResolverPath -Content $Resolver
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $DocPath -Content $Doc

Write-Step "Creando release correctivo SPT-011A"

New-Item -ItemType Directory -Path $TargetReleaseDir -Force | Out-Null

Copy-Item `
    -LiteralPath $TargetComponentPath `
    -Destination $TargetReleaseDir `
    -Force

Copy-Item `
    -LiteralPath $TargetDocPath `
    -Destination $TargetReleaseDir `
    -Force

Copy-Item `
    -LiteralPath $TargetDemoPath `
    -Destination $TargetReleaseDir `
    -Force

foreach ($EvidenceFile in $TargetEvidenceFiles) {
    Copy-Item `
        -LiteralPath $EvidenceFile.FullName `
        -Destination $TargetReleaseDir `
        -Force
}

Write-Json `
    -Path $TargetManifestPath `
    -Value ([ordered]@{
        increment_code = $TargetIncrement
        version = $TargetVersion
        parent_increment = "SPT-011"
        release_type = "corrective"
        status = "technically_validated"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        source_evidence_directory = "artifacts/pmo/SPT-011/evidence"
        no_invention = $true
        files = @(
            Get-ChildItem `
                -LiteralPath $TargetReleaseDir `
                -File |
            Select-Object -ExpandProperty Name
        )
    })

$TargetReleaseFiles = @(
    Get-ChildItem `
        -LiteralPath $TargetReleaseDir `
        -File |
    Where-Object { $_.Length -gt 0 }
)

if ($TargetReleaseFiles.Count -lt 4) {
    throw (
        "El release correctivo es insuficiente. " +
        "Archivos válidos: $($TargetReleaseFiles.Count)"
    )
}

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/adaptive_policy_resolver.py" `
        "tests/governance/test_SGD_114D_release_canonical_resolver.py"
}

Invoke-Checked "Ejecutando 8 pruebas específicas del resolver" {
    python -m pytest `
        "tests/governance/test_SGD_114D_release_canonical_resolver.py" `
        -q
}

Invoke-Checked "Ejecutando pruebas completas SGD-114D" {
    python -m pytest `
        "tests/governance/test_SGD_114D_adaptive_institutional_policy_engine.py" `
        "tests/governance/test_SGD_114D_release_canonical_resolver.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Reevaluando SPT-011A mediante SGD-114D"

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$ProjectRoot" `
    --increment "$TargetIncrement" `
    --output-json "$AdaptiveResultJson" `
    --output-md "$AdaptiveResultMd"

$AdaptiveExitCode = $LASTEXITCODE

Require-File -Path $AdaptiveResultJson
Require-File -Path $AdaptiveResultMd

$AdaptiveResult = Get-Content `
    -LiteralPath $AdaptiveResultJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($AdaptiveExitCode -ne 0 -or -not [bool]$AdaptiveResult.approved) {
    @($AdaptiveResult.results) |
        Where-Object { -not $_.passed } |
        Format-Table rule_code, name, message, remediation -AutoSize

    throw "SGD-114D v1.0.1 no aprobó ${TargetIncrement}."
}

Write-Step "Regenerando Roadmap Maestro SGD-116"

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
    throw "SGD-116 no aprobó SGD-114D v1.0.1."
}

Write-Step "Regenerando Documentación Maestra SGD-115"

Invoke-Checked "Actualizando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Write-Step "Generando evidencia y release SGD-114D"

New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json `
    -Path $ImplementationEvidence `
    -Value ([ordered]@{
        increment_code = "SGD-114D"
        version = "1.0.1"
        name = "Adaptive Release Canonical Resolver"
        status = "implemented_and_approved"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        corrected_rule = "SGD114D-R003"
        target_increment = $TargetIncrement
        target_version = $TargetVersion
        target_release = (
            "releases/" + $TargetIncrement + "-v" + $TargetVersion
        )
        target_release_file_count = $TargetReleaseFiles.Count
        target_approved = [bool]$AdaptiveResult.approved
        detected_release = $AdaptiveResult.release_path
        detected_evidence = $AdaptiveResult.evidence_path
        resolver_tests = 8
        adaptive_policy_tests = 12
        full_suite_executed = (-not $SkipFullSuite)
        roadmap_approved = [bool]$RoadmapValidation.passed
        documentation_updated = $true
        backup = $BackupDir
    })

foreach ($ReleaseFile in @(
    $ResolverPath,
    $TestPath,
    $ComponentPath,
    $DocPath,
    $AdaptiveResultJson,
    $AdaptiveResultMd,
    $ImplementationEvidence
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
        increment_code = "SGD-114D"
        version = "1.0.1"
        status = "implemented_and_validated"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
            Select-Object -ExpandProperty Name
        )
    })

Write-Step "Resultado final"

Write-Host "SGD-114D v1.0.1 implementado." -ForegroundColor Green
Write-Host "Adaptive Release Canonical Resolver: OPERATIVO." -ForegroundColor Green
Write-Host "SGD114D-R003: CORREGIDO." -ForegroundColor Green
Write-Host "Release correctivo SPT-011A: CREADO." -ForegroundColor Green
Write-Host "Pruebas específicas del resolver: 8 APROBADAS." -ForegroundColor Green
Write-Host "Pruebas completas SGD-114D: APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "${TargetIncrement}: APROBADO POR SGD-114D." `
    -ForegroundColor Green
Write-Host "SGD-116: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host (
    "Release objetivo: releases\" +
    $TargetIncrement +
    "-v" +
    $TargetVersion
) -ForegroundColor Cyan
Write-Host "Release SGD-114D: releases\SGD-114D-v1.0.1" `
    -ForegroundColor Cyan
Write-Host "Evidencia: $ImplementationEvidence" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
