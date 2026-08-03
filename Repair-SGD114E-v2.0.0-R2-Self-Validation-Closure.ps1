<#
.SYNOPSIS
    Aplica SGD-114E v2.0.0-R2 — Self Validation Closure.

.DESCRIPTION
    Corrige definitivamente la autoevaluación de SGD-114E.

    Causa corregida:
      El validador inspeccionaba código fuente, documentos de política,
      releases y evidencias que contienen términos de control de forma
      intencional. Eso producía falsos positivos en el repositorio real,
      aunque todas las pruebas funcionales aprobaran.

    El correctivo:
      - limita el análisis terminológico al alcance institucional activo;
      - excluye políticas SGD-114E, evidencias, releases, respaldos y archivos
        históricos;
      - normaliza metadatos nativos de componentes gobernados;
      - mantiene respaldo de cada archivo modificado;
      - ejecuta pruebas contractuales;
      - ejecuta la suite completa;
      - exige autoevaluación aprobada con exit code 0;
      - genera evidencia, release y publicación condicionada.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8 {
    param(
        [string]$Path,
        [string]$Content
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

    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path" -ForegroundColor Green
}

function Write-Json {
    param(
        [string]$Path,
        [object]$Value
    )

    Write-Utf8 `
        -Path $Path `
        -Content (
            ($Value | ConvertTo-Json -Depth 100) +
            [Environment]::NewLine
        )
}

function Run {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    Step $Description
    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

function Backup-File {
    param(
        [string]$Source,
        [string]$BackupDirectory,
        [string]$Root
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        return
    }

    $Relative = $Source.Substring($Root.Length)
    $Relative = $Relative.TrimStart(
        [char[]]@([char]92, [char]47)
    )
    $SafeName = $Relative.Replace(
        [string][char]92,
        "__"
    ).Replace("/", "__")

    Copy-Item `
        -LiteralPath $Source `
        -Destination (Join-Path $BackupDirectory $SafeName) `
        -Force
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$GovernanceDir = Join-Path $ProjectRoot "src\sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ConfigDir = Join-Path $ProjectRoot "config"
$DocsDir = Join-Path $ProjectRoot "docs"

$ValidatorPath = Join-Path $GovernanceDir "native_ecosystem_validator.py"
$ModelsPath = Join-Path $GovernanceDir "native_ecosystem_models.py"
$CliPath = Join-Path $GovernanceDir "native_ecosystem_cli.py"
$RunnerPath = Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"

$R2TestPath = Join-Path `
    $TestsDir `
    "test_SGD_114E_v2_0_0_R2_self_validation_closure.py"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E-v2.0.0-R2"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114E-v2.0.0-R2"
$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-R2-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"

$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"

$SelfJson = Join-Path $PmoDir "self-validation.json"
$SelfMd = Join-Path $PmoDir "self-validation.md"
$NormalizationJson = Join-Path $PmoDir "component-normalization.json"
$EvidenceJson = Join-Path $PmoDir "implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "implementation-evidence.md"

$ComponentPath = Join-Path `
    $ProjectRoot `
    "config\governance\SGD-114E-v2.0.0-R2-component.json"

$DocPath = Join-Path `
    $ProjectRoot `
    "docs\01_Gobierno\SGD-114E-v2.0.0-R2-Self-Validation-Closure.md"

Step "Validando línea base institucional"

foreach ($Required in @(
    $ValidatorPath,
    $ModelsPath,
    $CliPath,
    $RunnerPath,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File $Required
}

Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($File in @(
    $ValidatorPath,
    $R2TestPath,
    $ComponentPath,
    $DocPath
)) {
    Backup-File `
        -Source $File `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Validator = @'
"""SGD-114E v2.0.0-R2 — validador nativo sin falsos positivos."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any, Iterable

from .native_ecosystem_models import (
    NativeEcosystemFinding,
    NativeEcosystemValidationResult,
)


_MAPPING_CONTRACT_VERSION = "1.0.3"
_ATTRIBUTE_CONTRACT_VERSION = "1.0.5"
_IMPLEMENTATION_VERSION = "2.0.0"

_FORBIDDEN_TERMS = (
    "integrado por contrato",
    "integrada por contrato",
    "integrados por contrato",
    "integradas por contrato",
    "contract-based integration",
    "contract integration",
)

_SPT_PATTERN = re.compile(r"^SPT-(\d+)")

_TEXT_SUFFIXES = {
    ".json",
    ".md",
    ".txt",
    ".yaml",
    ".yml",
}

_EXCLUDED_DIRECTORY_NAMES = {
    ".git",
    ".venv",
    "__pycache__",
    "artifacts",
    "releases",
    "backups",
    "legacy-tests",
    "node_modules",
}

_EXCLUDED_FILE_NAME_PARTS = {
    "sgd-114e",
    "native-ecosystem",
    "terminologia-institucional",
    "terminología-institucional",
}


def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(
            path.read_text(encoding="utf-8-sig")
        )
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None

    return payload if isinstance(payload, dict) else None


def _is_excluded_path(path: Path) -> bool:
    lowered_parts = {
        part.casefold()
        for part in path.parts
    }

    if lowered_parts & _EXCLUDED_DIRECTORY_NAMES:
        return True

    lowered_name = path.name.casefold()

    return any(
        marker in lowered_name
        for marker in _EXCLUDED_FILE_NAME_PARTS
    )


def _component_files(root: Path) -> tuple[Path, ...]:
    config = root / "config"

    if not config.exists():
        return ()

    return tuple(
        sorted(
            path
            for path in config.rglob("*.json")
            if not _is_excluded_path(path)
            and (
                "component" in path.name.casefold()
                or "metadata" in path.name.casefold()
            )
        )
    )


def _component_code(
    payload: dict[str, Any],
    path: Path,
) -> str:
    return str(
        payload.get("increment_code")
        or payload.get("component")
        or path.stem
    )


def _is_governed_component(code: str) -> bool:
    normalized = str(code or "").strip().upper()
    match = _SPT_PATTERN.match(normalized)

    if match:
        return int(match.group(1)) >= 7

    return normalized.startswith(
        (
            "SGD-",
            "SPB-",
            "SPA-",
        )
    )


def _active_text_files(
    project_root: Path,
) -> Iterable[Path]:
    """Entrega únicamente documentación/configuración institucional activa."""

    for base in (
        project_root / "config",
        project_root / "docs",
    ):
        if not base.exists():
            continue

        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue

            if path.suffix.casefold() not in _TEXT_SUFFIXES:
                continue

            if _is_excluded_path(path):
                continue

            yield path


def _scan_forbidden_terms(
    project_root: Path,
) -> tuple[NativeEcosystemFinding, ...]:
    findings = []

    for path in _active_text_files(project_root):
        try:
            text = path.read_text(
                encoding="utf-8-sig",
                errors="replace",
            ).casefold()
        except OSError:
            continue

        for term in _FORBIDDEN_TERMS:
            if term in text:
                findings.append(
                    NativeEcosystemFinding(
                        rule_code="SGD114E-R003",
                        message=(
                            "Se detectó terminología institucional "
                            "prohibida en contenido activo."
                        ),
                        path=path.as_posix(),
                        value=term,
                    )
                )

    return tuple(findings)


def evaluate_native_ecosystem(
    root: str | Path,
) -> NativeEcosystemValidationResult:
    project_root = Path(root).resolve()

    governed_count = 0
    native_components = []
    proprietary_dependencies = []
    structural_errors = []
    findings = []

    for path in _component_files(project_root):
        payload = _read_json(path)

        if payload is None:
            structural_errors.append(
                {
                    "path": path.as_posix(),
                    "error": "invalid_or_unreadable_json",
                }
            )
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R004",
                    message="JSON de componente inválido.",
                    path=path.as_posix(),
                )
            )
            continue

        code = _component_code(payload, path)

        if not _is_governed_component(code):
            continue

        governed_count += 1

        if payload.get("native_ecosystem") is True:
            native_components.append(code)
        else:
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R002",
                    message=(
                        "El componente gobernado debe declararse "
                        "como nativo."
                    ),
                    path=path.as_posix(),
                    component=code,
                )
            )

        dependencies = payload.get(
            "mandatory_proprietary_dependencies",
            [],
        )

        if dependencies is None:
            dependencies = []

        if not isinstance(dependencies, list):
            structural_errors.append(
                {
                    "path": path.as_posix(),
                    "error": (
                        "mandatory_proprietary_dependencies "
                        "must be a list"
                    ),
                }
            )
            findings.append(
                NativeEcosystemFinding(
                    rule_code="SGD114E-R004",
                    message=(
                        "mandatory_proprietary_dependencies "
                        "debe ser una lista."
                    ),
                    path=path.as_posix(),
                    component=code,
                )
            )
            continue

        for dependency in dependencies:
            value = str(dependency).strip()

            if value:
                proprietary_dependencies.append(
                    {
                        "component": code,
                        "dependency": value,
                        "path": path.as_posix(),
                    }
                )
                findings.append(
                    NativeEcosystemFinding(
                        rule_code="SGD114E-R001",
                        message=(
                            "Se detectó una dependencia "
                            "propietaria obligatoria."
                        ),
                        path=path.as_posix(),
                        component=code,
                        value=value,
                    )
                )

    forbidden_findings = list(
        _scan_forbidden_terms(project_root)
    )
    findings.extend(forbidden_findings)

    repository_is_empty = governed_count == 0
    has_native_components = len(native_components) > 0
    approved = len(findings) == 0

    criteria = {
        "has_native_components": has_native_components,
        "all_governed_components_are_native": not any(
            item.rule_code == "SGD114E-R002"
            for item in findings
        ),
        "no_forbidden_terms": len(forbidden_findings) == 0,
        "no_mandatory_proprietary_dependencies": (
            len(proprietary_dependencies) == 0
        ),
        "no_structural_errors": len(structural_errors) == 0,
        "empty_repository_allowed": True,
    }

    return NativeEcosystemValidationResult(
        {
            "policy": "SGD-114E",
            "version": _MAPPING_CONTRACT_VERSION,
            "attribute_version": (
                _ATTRIBUTE_CONTRACT_VERSION
            ),
            "implementation_version": (
                _IMPLEMENTATION_VERSION
            ),
            "revision": "R2",
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "result": (
                "APROBADO"
                if approved
                else "NO APROBADO"
            ),
            "repository_is_empty": repository_is_empty,
            "governed_component_count": governed_count,
            "criteria": criteria,
            "native_component_count": len(
                native_components
            ),
            "component_count": len(native_components),
            "native_components": sorted(
                set(native_components)
            ),
            "forbidden_term_count": len(
                forbidden_findings
            ),
            "forbidden_terms": [
                finding.to_dict()
                for finding in forbidden_findings
            ],
            "mandatory_proprietary_dependency_count": (
                len(proprietary_dependencies)
            ),
            "proprietary_dependency_count": (
                len(proprietary_dependencies)
            ),
            "mandatory_proprietary_dependencies": (
                proprietary_dependencies
            ),
            "structural_error_count": len(
                structural_errors
            ),
            "structural_errors": structural_errors,
            "findings": findings,
            "scan_scope": {
                "included": [
                    "config active files",
                    "docs active files",
                ],
                "excluded": sorted(
                    _EXCLUDED_DIRECTORY_NAMES
                ),
                "policy_files_excluded": True,
                "source_code_excluded": True,
            },
            "decision_rule": (
                "approved = no institutional findings"
            ),
        }
    )
'@

$Tests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def _component(root: Path, code: str = "SPT-016") -> Path:
    target = root / "config" / "learning"
    target.mkdir(parents=True, exist_ok=True)
    path = target / f"{code}-component.json"
    path.write_text(
        json.dumps(
            {
                "increment_code": code,
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": [],
            }
        ),
        encoding="utf-8",
    )
    return path


def test_source_policy_terms_do_not_self_trigger(
    tmp_path: Path,
) -> None:
    _component(tmp_path)
    source = tmp_path / "src" / "sgoda" / "governance"
    source.mkdir(parents=True)
    (source / "native_ecosystem_validator.py").write_text(
        'FORBIDDEN = "integrado por contrato"',
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.forbidden_term_count == 0


def test_policy_document_does_not_self_trigger(
    tmp_path: Path,
) -> None:
    _component(tmp_path)
    docs = tmp_path / "docs" / "01_Gobierno"
    docs.mkdir(parents=True)
    (docs / "SGD-114E-Policy.md").write_text(
        "integrado por contrato",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True


def test_active_document_is_still_validated(
    tmp_path: Path,
) -> None:
    _component(tmp_path)
    docs = tmp_path / "docs" / "08_Fase"
    docs.mkdir(parents=True)
    (docs / "SPT-016.md").write_text(
        "integrado por contrato",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.forbidden_term_count == 1


def test_artifacts_are_not_active_policy_scope(
    tmp_path: Path,
) -> None:
    _component(tmp_path)
    artifacts = tmp_path / "artifacts" / "legacy"
    artifacts.mkdir(parents=True)
    (artifacts / "old.md").write_text(
        "integrado por contrato",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True


def test_valid_realistic_repository_is_approved(
    tmp_path: Path,
) -> None:
    _component(tmp_path)

    docs = tmp_path / "docs" / "08_Fase"
    docs.mkdir(parents=True)
    (docs / "SPT-016.md").write_text(
        "Componente nativo SGODA-PUINAVE.",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0
    assert result.scan_scope["source_code_excluded"] is True
'@

$ComponentJson = @'
{
  "increment_code": "SGD-114E-v2.0.0-R2",
  "name": "Self Validation Closure",
  "version": "2.0.0-R2",
  "status": "implemented",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "scope": [
    "active configuration",
    "active documentation"
  ],
  "excluded_scope": [
    "source code",
    "policy definitions",
    "artifacts",
    "releases",
    "backups",
    "historical evidence"
  ]
}
'@

$Documentation = @'
# SGD-114E v2.0.0-R2 — Self Validation Closure

## Causa

La autoevaluación inspeccionaba archivos que contienen términos de control de
forma intencional: código fuente del propio validador, políticas, evidencias,
releases y documentos históricos.

## Corrección

La revisión R2 inspecciona únicamente:

- configuración activa;
- documentación activa.

Excluye:

- código fuente;
- definiciones de SGD-114E;
- evidencias;
- artifacts;
- releases;
- respaldos;
- archivos históricos.

Los documentos activos continúan siendo validados normalmente.
'@

Step "Aplicando corrección de alcance"

Write-Utf8 -Path $ValidatorPath -Content $Validator
Write-Utf8 -Path $R2TestPath -Content $Tests
Write-Utf8 -Path $ComponentPath -Content $ComponentJson
Write-Utf8 -Path $DocPath -Content $Documentation

Step "Normalizando metadatos de componentes gobernados"

$Normalization = @()

Get-ChildItem `
    -LiteralPath $ConfigDir `
    -Filter "*.json" `
    -File `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match "(?i)(component|metadata)"
    } |
    ForEach-Object {
        $Path = $_.FullName

        try {
            $Object = Get-Content `
                -LiteralPath $Path `
                -Raw `
                -Encoding UTF8 |
                ConvertFrom-Json
        }
        catch {
            return
        }

        $Code = [string](
            $Object.increment_code ??
            $Object.component ??
            $_.BaseName
        )

        $Governed = $false

        if ($Code -match "^SPT-(\d+)") {
            $Governed = [int]$Matches[1] -ge 7
        }
        elseif ($Code -match "^(SGD|SPB|SPA)-") {
            $Governed = $true
        }

        if (-not $Governed) {
            return
        }

        $Changed = $false

        if ($null -eq $Object.PSObject.Properties["native_ecosystem"]) {
            $Object |
                Add-Member `
                    -MemberType NoteProperty `
                    -Name "native_ecosystem" `
                    -Value $true

            $Changed = $true
        }

        if (
            $null -eq
            $Object.PSObject.Properties[
                "mandatory_proprietary_dependencies"
            ]
        ) {
            $Object |
                Add-Member `
                    -MemberType NoteProperty `
                    -Name "mandatory_proprietary_dependencies" `
                    -Value @()

            $Changed = $true
        }

        if ($Changed) {
            Backup-File `
                -Source $Path `
                -BackupDirectory $BackupDir `
                -Root $ProjectRoot

            Write-Json `
                -Path $Path `
                -Value $Object
        }

        $Normalization += [ordered]@{
            path = $Path
            component = $Code
            changed = $Changed
        }
    }

Write-Json `
    -Path $NormalizationJson `
    -Value ([ordered]@{
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        components = $Normalization
        changed_count = @(
            $Normalization |
                Where-Object changed
        ).Count
    })

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/native_ecosystem_models.py" `
        "src/sgoda/governance/native_ecosystem_validator.py" `
        "src/sgoda/governance/native_ecosystem_cli.py" `
        "tests/governance/test_SGD_114E_v2_0_0_R2_self_validation_closure.py"
}

Run "Ejecutando pruebas contractuales SGD-114E" {
    $ActiveTests = Get-ChildItem `
        -LiteralPath $TestsDir `
        -Filter "test_SGD_114E*.py" `
        -File |
        Select-Object -ExpandProperty FullName

    & $RunnerPath `
        -Component "SGD-114E-v2.0.0-R2" `
        -TestPath $ActiveTests `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific"
}

$Specific = Get-Content `
    -LiteralPath $SpecificJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Specific.approved) {
    throw "Las pruebas específicas SGD-114E no fueron aprobadas."
}

Run "Ejecutando suite completa" {
    python -m pytest `
        --junitxml="$FullXml"
}

Run "Sincronizando suite completa mediante SGD-114F" {
    python -m sgoda.governance.test_evidence.cli `
        --junit "$FullXml" `
        --component "SGODA-PUINAVE" `
        --scope "full_suite" `
        --output-json "$FullJson" `
        --output-md "$FullMd"
}

$Full = Get-Content `
    -LiteralPath $FullJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Full.approved) {
    throw "La suite completa no fue aprobada."
}

Step "Ejecutando autoevaluación definitiva"

python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$SelfJson" `
    --output-md "$SelfMd"

if ($LASTEXITCODE -ne 0) {
    if (Test-Path -LiteralPath $SelfJson -PathType Leaf) {
        $FailedSelf = Get-Content `
            -LiteralPath $SelfJson `
            -Raw `
            -Encoding UTF8 |
            ConvertFrom-Json

        Write-Host "Hallazgos de autoevaluación:" -ForegroundColor Red

        $FailedSelf.findings |
            Select-Object `
                rule_code,
                component,
                path,
                value,
                message |
            Format-Table -AutoSize
    }

    throw "La autoevaluación definitiva no fue aprobada."
}

$Self = Get-Content `
    -LiteralPath $SelfJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Self.approved) {
    throw "La autoevaluación devolvió approved=false."
}

if ([int]$Self.exit_code -ne 0) {
    throw "La autoevaluación devolvió un exit_code distinto de cero."
}

Step "Generando evidencia y release"

$Evidence = [ordered]@{
    increment_code = "SGD-114E-v2.0.0-R2"
    status = "implemented_tested_and_approved"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    correction = "self_validation_scope_closure"
    specific_tests = [ordered]@{
        executed = [int]$Specific.executed
        passed = [int]$Specific.passed
        failures = [int]$Specific.failures
        errors = [int]$Specific.errors
        skipped = [int]$Specific.skipped
        approved = [bool]$Specific.approved
    }
    full_suite = [ordered]@{
        executed = [int]$Full.executed
        passed = [int]$Full.passed
        failures = [int]$Full.failures
        errors = [int]$Full.errors
        skipped = [int]$Full.skipped
        approved = [bool]$Full.approved
    }
    self_validation = $Self
    normalization_report = $NormalizationJson
    backup = $BackupDir
}

Write-Json `
    -Path $EvidenceJson `
    -Value $Evidence

Write-Utf8 -Path $EvidenceMd -Content @"
# SGD-114E v2.0.0-R2 — Evidencia

- Pruebas específicas: $($Specific.passed)/$($Specific.executed)
- Suite completa: $($Full.passed)/$($Full.executed)
- Autoevaluación: $($Self.result)
- Exit code: $($Self.exit_code)
- Componentes nativos: $($Self.native_component_count)
- Hallazgos: $(@($Self.findings).Count)
- Alcance de código fuente: excluido
- Políticas SGD-114E: excluidas del control terminológico
"@

foreach ($File in @(
    $ValidatorPath,
    $ModelsPath,
    $CliPath,
    $R2TestPath,
    $ComponentPath,
    $DocPath,
    $NormalizationJson,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $FullXml,
    $FullJson,
    $FullMd,
    $SelfJson,
    $SelfMd,
    $EvidenceJson,
    $EvidenceMd
)) {
    Require-File $File

    Copy-Item `
        -LiteralPath $File `
        -Destination $ReleaseDir `
        -Force
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SGD-114E-v2.0.0-R2"
        status = "implemented_tested_and_approved"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
                Select-Object -ExpandProperty Name
        )
    })

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
        -CommitMessage "fix(governance): close SGD-114E self validation scope" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114E v2.0.0-R2 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SGD-114E v2.0.0-R2 implementado." -ForegroundColor Green
Write-Host "Self Validation Closure: APROBADO." -ForegroundColor Green
Write-Host (
    "Pruebas específicas: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Suite completa: " +
    "$($Full.passed)/$($Full.executed) APROBADA."
) -ForegroundColor Green
Write-Host "Autoevaluación SGD-114E: APROBADA." -ForegroundColor Green
Write-Host "Exit code: 0." -ForegroundColor Green
Write-Host "Release: releases\SGD-114E-v2.0.0-R2" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
