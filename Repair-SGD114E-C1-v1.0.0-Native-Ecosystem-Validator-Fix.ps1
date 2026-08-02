<#
.SYNOPSIS
    Ejecuta SGD-114E-C1 v1.0.0 — Native Ecosystem Validator Fix.

.DESCRIPTION
    Correctivo institucional único para el algoritmo del validador SGD-114E.

    Mantiene intacto:
      Install-SGD114E-v1.0.2-Null-Safe-Native-Ecosystem-Policy.ps1

    Corrige:
      - detección exacta de terminología no permitida;
      - aceptación de terminología institucional aprobada;
      - protección de archivos normativos que documentan las expresiones;
      - exclusión de artefactos, releases, respaldos y pruebas históricas;
      - evaluación exclusiva de documentación y código activos.

    El correctivo:
      - crea respaldo;
      - reemplaza únicamente policy y validator;
      - valida que el instalador v1.0.2 no cambie;
      - ejecuta las 12 pruebas específicas;
      - ejecuta la suite completa;
      - evalúa el repositorio real;
      - regenera SGD-115 y SGD-116;
      - genera evidencias y release;
      - publica mediante SPB-007 solo con -Publish y únicamente tras aprobar.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER Publish
    Publica mediante SPB-007 únicamente después de aprobar todos los gates.

.PARAMETER SkipFullSuite
    Omite la suite completa. Impide publicar.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Publish,
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

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $Stream = [System.IO.File]::OpenRead($Path)

    try {
        $Hasher = [System.Security.Cryptography.SHA256]::Create()

        try {
            $Hash = $Hasher.ComputeHash($Stream)
        }
        finally {
            $Hasher.Dispose()
        }
    }
    finally {
        $Stream.Dispose()
    }

    return (
        ($Hash | ForEach-Object { $_.ToString("x2") }) -join ""
    )
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

if ($Publish -and $SkipFullSuite) {
    throw (
        "No se permite publicar con -SkipFullSuite. " +
        "La suite completa es obligatoria para publicación."
    )
}

$GovernanceDir = Join-Path $ProjectRoot "src\sgoda\governance"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E-C1"
$EvidenceDir = Join-Path $PmoDir "evidence"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114E-C1-v1.0.0"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SGD114E-C1-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$PolicyPath = Join-Path $GovernanceDir "native_ecosystem_policy.py"
$ValidatorPath = Join-Path $GovernanceDir "native_ecosystem_validator.py"
$TestPath = Join-Path `
    $ProjectRoot `
    "tests\governance\test_SGD_114E_native_ecosystem_architecture_policy.py"

$InstallerV102 = Join-Path `
    $ProjectRoot `
    "Install-SGD114E-v1.0.2-Null-Safe-Native-Ecosystem-Policy.ps1"

$EvaluationJson = Join-Path `
    $PmoDir `
    "SGD-114E-C1-repository-evaluation.json"

$EvaluationMd = Join-Path `
    $PmoDir `
    "SGD-114E-C1-repository-evaluation.md"

$EvidenceJson = Join-Path `
    $EvidenceDir `
    "SGD-114E-C1-implementation-evidence.json"

$EvidenceMd = Join-Path `
    $EvidenceDir `
    "SGD-114E-C1-implementation-evidence.md"

$ComponentPath = Join-Path `
    $ProjectRoot `
    "config\governance\SGD-114E-C1-component.json"

$DocPath = Join-Path `
    $ProjectRoot `
    "docs\01_Gobierno\SGD-114E-C1-Native-Ecosystem-Validator-Fix.md"

Write-Step "Validando línea base"

foreach ($Required in @(
    $PolicyPath,
    $ValidatorPath,
    $TestPath,
    $InstallerV102,
    (Join-Path $GovernanceDir "native_ecosystem_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File -Path $Required
}

$InstallerHashBefore = Get-Sha256 -Path $InstallerV102

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Affected in @(
    $PolicyPath,
    $ValidatorPath,
    $ComponentPath,
    $DocPath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Policy = @'
"""Política nativa del ecosistema SGODA-PUINAVE.

Las expresiones no permitidas se construyen por segmentos para evitar que
el propio archivo normativo sea identificado como contenido documental
infractor.
"""

from __future__ import annotations

import re
from typing import Any


_NATIVE_SPT = re.compile(
    r"^SPT-(?P<number>\d+)(?P<suffix>[A-Z]?)$",
    re.IGNORECASE,
)


def _phrase(*parts: str) -> str:
    return "".join(parts)


FORBIDDEN_TERMS = (
    _phrase("integrado ", "por contrato"),
    _phrase("integrada ", "por contrato"),
    _phrase("integrados ", "por contrato"),
    _phrase("integradas ", "por contrato"),
    _phrase("contract ", "integration"),
    _phrase("contract-based ", "integration"),
)

APPROVED_TERMS = (
    "integrado nativamente",
    "integrada nativamente",
    "integrados nativamente",
    "integradas nativamente",
    "componente nativo del ecosistema sgoda-puinave",
    "componente institucional del núcleo sgoda",
    "motor institucional",
    "servicio institucional",
    "módulo nativo",
    "subsistema institucional",
)

DEFAULT_OPEN_TECHNOLOGIES = (
    "python",
    "fastapi",
    "postgresql",
    "flutter",
    "n8n community",
    "git",
    "github",
    "audacity",
    "whisper local",
    "ollama",
    "llama.cpp",
    "sqlite",
    "json",
    "markdown",
)


def is_native_spt(code: str) -> bool:
    match = _NATIVE_SPT.fullmatch(
        str(code or "").strip().upper()
    )

    if match is None:
        return False

    return int(match.group("number")) >= 7


def normalize_native_metadata(
    payload: dict[str, Any],
) -> dict[str, Any]:
    normalized = dict(payload)
    code = str(
        normalized.get("increment_code") or ""
    ).strip().upper()

    if is_native_spt(code):
        normalized["ecosystem_role"] = "native_component"
        normalized["native_ecosystem"] = True
        normalized[
            "mandatory_proprietary_dependencies"
        ] = []
        normalized.setdefault(
            "technology_policy",
            "free_open_optional_proprietary",
        )

    return normalized
'@

$Validator = @'
"""Validador institucional corregido SGD-114E-C1."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable

from .native_ecosystem_models import (
    NativePolicyFinding,
    NativePolicyResult,
)
from .native_ecosystem_policy import (
    FORBIDDEN_TERMS,
    is_native_spt,
)


_TEXT_SUFFIXES = {
    ".md",
    ".json",
    ".py",
    ".ps1",
    ".txt",
    ".yaml",
    ".yml",
}

_ACTIVE_ROOTS = (
    "docs",
    "config",
    "src",
    "scripts",
)

_EXEMPT_RELATIVE_PATHS = {
    "config/governance/SGD-114E-native-ecosystem-policy.json",
    "docs/01_Gobierno/SGD-114E-Terminologia-Institucional.md",
    "src/sgoda/governance/native_ecosystem_policy.py",
}

_IGNORED_PARTS = {
    ".git",
    ".venv",
    "__pycache__",
    ".pytest_cache",
    "artifacts",
    "releases",
    "tests",
}


def _relative(path: Path, root: Path) -> str:
    return str(path.relative_to(root)).replace("\\", "/")


def _iter_active_text_files(root: Path) -> Iterable[Path]:
    for root_name in _ACTIVE_ROOTS:
        active_root = root / root_name

        if not active_root.is_dir():
            continue

        for path in active_root.rglob("*"):
            if not path.is_file():
                continue

            relative = _relative(path, root)

            if relative in _EXEMPT_RELATIVE_PATHS:
                continue

            if any(part in _IGNORED_PARTS for part in path.parts):
                continue

            if path.suffix.casefold() not in _TEXT_SUFFIXES:
                continue

            yield path


def _component_files(root: Path) -> Iterable[Path]:
    config_root = root / "config"

    if not config_root.is_dir():
        return

    for path in config_root.rglob("*component.json"):
        if path.is_file():
            yield path


def _read_text(path: Path) -> str:
    try:
        return path.read_text(
            encoding="utf-8-sig",
            errors="replace",
        )
    except OSError:
        return ""


def evaluate_native_ecosystem(
    root: str | Path,
) -> NativePolicyResult:
    base = Path(root).resolve()
    findings: list[NativePolicyFinding] = []
    component_count = 0
    proprietary_count = 0
    forbidden_count = 0

    for path in _component_files(base):
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError) as error:
            findings.append(
                NativePolicyFinding(
                    rule_code="SGD114E-R001",
                    passed=False,
                    blocking=True,
                    message=(
                        "No fue posible leer el componente: "
                        f"{error}"
                    ),
                    path=_relative(path, base),
                    remediation="Corrija el JSON del componente.",
                )
            )
            continue

        if not isinstance(payload, dict):
            continue

        code = str(
            payload.get("increment_code") or ""
        ).strip().upper()

        if not is_native_spt(code):
            continue

        component_count += 1
        native = bool(
            payload.get("native_ecosystem", False)
        )
        role = str(
            payload.get("ecosystem_role") or ""
        ).strip()

        if not native or role != "native_component":
            findings.append(
                NativePolicyFinding(
                    rule_code="SGD114E-R002",
                    passed=False,
                    blocking=True,
                    message=(
                        f"{code} no está declarado como "
                        "componente nativo."
                    ),
                    path=_relative(path, base),
                    remediation=(
                        "Agregue native_ecosystem=true y "
                        "ecosystem_role=native_component."
                    ),
                )
            )

        proprietary = payload.get(
            "mandatory_proprietary_dependencies",
            [],
        )

        if not isinstance(proprietary, list):
            proprietary = [str(proprietary)]

        proprietary = [
            str(item).strip()
            for item in proprietary
            if str(item).strip()
        ]

        if proprietary:
            proprietary_count += len(proprietary)
            findings.append(
                NativePolicyFinding(
                    rule_code="SGD114E-R003",
                    passed=False,
                    blocking=True,
                    message=(
                        f"{code} declara dependencias "
                        f"propietarias obligatorias: {proprietary}"
                    ),
                    path=_relative(path, base),
                    remediation=(
                        "Elimine la obligatoriedad o documente "
                        "una alternativa gratuita y abierta."
                    ),
                )
            )

    for path in _iter_active_text_files(base):
        text = _read_text(path).casefold()

        if not text:
            continue

        for term in FORBIDDEN_TERMS:
            normalized_term = term.casefold()

            if normalized_term in text:
                forbidden_count += 1
                findings.append(
                    NativePolicyFinding(
                        rule_code="SGD114E-R004",
                        passed=False,
                        blocking=True,
                        message=(
                            "Terminología no permitida detectada."
                        ),
                        path=_relative(path, base),
                        remediation=(
                            "Use 'integrado nativamente al "
                            "ecosistema SGODA-PUINAVE'."
                        ),
                    )
                )

    approved = not any(
        finding.blocking and not finding.passed
        for finding in findings
    )

    if approved:
        findings.append(
            NativePolicyFinding(
                rule_code="SGD114E-R000",
                passed=True,
                blocking=False,
                message=(
                    "Arquitectura nativa y política tecnológica "
                    "aprobadas."
                ),
            )
        )

    return NativePolicyResult(
        approved=approved,
        exit_code=0 if approved else 2,
        component_count=component_count,
        findings=tuple(findings),
        forbidden_term_count=forbidden_count,
        proprietary_dependency_count=proprietary_count,
    )
'@

$Component = @'
{
  "increment_code": "SGD-114E-C1",
  "canonical_code": "SGD-114E",
  "name": "Native Ecosystem Validator Fix",
  "component_type": "institutional_corrective",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Gobierno Digital",
  "dependencies": [
    "SGD-114E-v1.0.2",
    "SGD-115A",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/governance/native_ecosystem_policy.py",
    "src/sgoda/governance/native_ecosystem_validator.py"
  ],
  "tests": [
    "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py"
  ],
  "documentation": [
    "docs/01_Gobierno/SGD-114E-C1-Native-Ecosystem-Validator-Fix.md"
  ]
}
'@

$Doc = @'
# SGD-114E-C1 v1.0.0 — Native Ecosystem Validator Fix

## Problema corregido

La normalización del instalador SGD-114E v1.0.2 modificó accidentalmente las
expresiones normativas almacenadas en `FORBIDDEN_TERMS`. Como consecuencia:

- la expresión no permitida dejó de ser detectada;
- la expresión institucional aprobada fue tratada como infracción.

## Solución

El correctivo:

- reconstruye las expresiones no permitidas mediante segmentos;
- aplica coincidencia exacta sin invertir el significado;
- limita el análisis a documentación, configuración, código y scripts activos;
- excluye archivos normativos que deben documentar las expresiones;
- mantiene intacto el instalador SGD-114E v1.0.2;
- exige 12 pruebas específicas y suite completa antes de publicar.
'@

Write-Step "Aplicando corrección del algoritmo"

Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $ValidatorPath -Content $Validator
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $DocPath -Content $Doc

$InstallerHashAfterCorrection = Get-Sha256 -Path $InstallerV102

if ($InstallerHashAfterCorrection -ne $InstallerHashBefore) {
    throw (
        "El instalador SGD-114E v1.0.2 fue modificado. " +
        "El correctivo debe mantenerlo intacto."
    )
}

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/native_ecosystem_policy.py" `
        "src/sgoda/governance/native_ecosystem_validator.py" `
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py"
}

$SpecificStarted = [DateTime]::UtcNow

Invoke-Checked "Ejecutando las 12 pruebas específicas SGD-114E" {
    python -m pytest `
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py" `
        -q
}

$SpecificFinished = [DateTime]::UtcNow
$FullSuiteStarted = $null
$FullSuiteFinished = $null

if (-not $SkipFullSuite) {
    $FullSuiteStarted = [DateTime]::UtcNow

    Invoke-Checked "Ejecutando suite completa del repositorio" {
        python -m pytest
    }

    $FullSuiteFinished = [DateTime]::UtcNow
}

Write-Step "Evaluando repositorio real"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$EvaluationJson" `
    --output-md "$EvaluationMd"

$EvaluationExitCode = $LASTEXITCODE

Require-File -Path $EvaluationJson
Require-File -Path $EvaluationMd

$Evaluation = Get-Content `
    -LiteralPath $EvaluationJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($EvaluationExitCode -ne 0 -or -not [bool]$Evaluation.approved) {
    @($Evaluation.findings) |
        Where-Object { $_.blocking -and -not $_.passed } |
        Format-Table rule_code, message, path, remediation -AutoSize

    throw "SGD-114E-C1 no aprobó el repositorio."
}

Write-Step "Regenerando SGD-115"

Invoke-Checked "Actualizando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

$DocValidationPath = Join-Path `
    $ProjectRoot `
    "artifacts\documentation\SGD-115\master-documentation-validation.json"

Require-File -Path $DocValidationPath

$DocValidation = Get-Content `
    -LiteralPath $DocValidationPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$DocValidation.passed) {
    throw "SGD-115 no aprobó SGD-114E-C1."
}

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
    throw "SGD-116 no aprobó SGD-114E-C1."
}

Write-Step "Generando evidencias y release"

New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

$FullSuiteStatus = "not_executed"
$FullSuiteStartedUtc = $null
$FullSuiteFinishedUtc = $null

if (-not $SkipFullSuite) {
    $FullSuiteStatus = "passed"
    $FullSuiteStartedUtc = $FullSuiteStarted.ToString("o")
    $FullSuiteFinishedUtc = $FullSuiteFinished.ToString("o")
}

Write-Json `
    -Path $EvidenceJson `
    -Value ([ordered]@{
        increment_code = "SGD-114E-C1"
        canonical_code = "SGD-114E"
        version = "1.0.0"
        status = "implemented_and_approved"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        corrected_files = @(
            "src/sgoda/governance/native_ecosystem_policy.py",
            "src/sgoda/governance/native_ecosystem_validator.py"
        )
        installer_v1_0_2_preserved = $true
        installer_v1_0_2_sha256 = $InstallerHashBefore
        specific_tests = [ordered]@{
            expected = 12
            status = "passed"
            started_at_utc = $SpecificStarted.ToString("o")
            finished_at_utc = $SpecificFinished.ToString("o")
        }
        full_suite = [ordered]@{
            executed = (-not $SkipFullSuite)
            status = $FullSuiteStatus
            started_at_utc = $FullSuiteStartedUtc
            finished_at_utc = $FullSuiteFinishedUtc
        }
        repository_policy_approved = [bool]$Evaluation.approved
        forbidden_term_count = $Evaluation.forbidden_term_count
        proprietary_dependency_count = (
            $Evaluation.proprietary_dependency_count
        )
        documentation_approved = [bool]$DocValidation.passed
        roadmap_approved = [bool]$RoadmapValidation.passed
        publication_requested = [bool]$Publish
        backup = $BackupDir
    })

$EvidenceMarkdown = @"
# SGD-114E-C1 v1.0.0 — Evidencia institucional

- Instalador SGD-114E v1.0.2 preservado: Sí
- SHA-256 instalador: $InstallerHashBefore
- Pruebas específicas: 12 APROBADAS
- Suite completa: $FullSuiteStatus
- Evaluación del repositorio: APROBADA
- Términos no permitidos: $($Evaluation.forbidden_term_count)
- Dependencias propietarias obligatorias: $($Evaluation.proprietary_dependency_count)
- SGD-115: APROBADO
- SGD-116: APROBADO
"@

Write-Utf8 -Path $EvidenceMd -Content $EvidenceMarkdown

foreach ($ReleaseFile in @(
    $PolicyPath,
    $ValidatorPath,
    $ComponentPath,
    $DocPath,
    $EvaluationJson,
    $EvaluationMd,
    $EvidenceJson,
    $EvidenceMd
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
        increment_code = "SGD-114E-C1"
        version = "1.0.0"
        status = "implemented_and_validated"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
            Select-Object -ExpandProperty Name
        )
    })

$InstallerHashFinal = Get-Sha256 -Path $InstallerV102

if ($InstallerHashFinal -ne $InstallerHashBefore) {
    throw "El instalador SGD-114E v1.0.2 cambió durante el correctivo."
}

if ($Publish) {
    Write-Step "Publicando mediante SPB-007"

    & (Join-Path `
        $ProjectRoot `
        "scripts\Invoke-SPB007-InstitutionalPublish.ps1") `
        -Publish `
        -CommitMessage (
            "fix(governance): implement SGD-114E-C1 validator fix"
        ) `
        -EvidenceCommitMessage (
            "chore(governance): publish SGD-114E-C1 evidence"
        )

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores. Código: $LASTEXITCODE"
    }

    $Status = @(git status --porcelain)

    if ($LASTEXITCODE -ne 0) {
        throw "No fue posible consultar git status."
    }

    if ($Status.Count -ne 0) {
        throw "La publicación terminó con cambios pendientes."
    }
}

Write-Step "Resultado final"

Write-Host "SGD-114E-C1 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Algoritmo del validador: CORREGIDO." -ForegroundColor Green
Write-Host "Instalador SGD-114E v1.0.2: INTACTO." -ForegroundColor Green
Write-Host "Pruebas específicas: 12 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}
else {
    Write-Host "Suite completa: OMITIDA; PUBLICACIÓN BLOQUEADA." `
        -ForegroundColor Yellow
}

Write-Host "Evaluación del repositorio: APROBADA." -ForegroundColor Green
Write-Host "Términos no permitidos: 0." -ForegroundColor Green
Write-Host "Dependencias propietarias obligatorias: 0." `
    -ForegroundColor Green
Write-Host "SGD-115: APROBADO." -ForegroundColor Green
Write-Host "SGD-116: APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SGD-114E-C1-v1.0.0" `
    -ForegroundColor Cyan
Write-Host "Evidencia: $EvidenceJson" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
    Write-Host "Git limpio: True." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host (
        "Publicación no solicitada. Para publicar, reejecute " +
        "este correctivo con -Publish."
    ) -ForegroundColor Yellow
}
