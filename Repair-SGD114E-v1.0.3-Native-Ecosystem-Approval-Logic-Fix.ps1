<#
.SYNOPSIS
    Aplica SGD-114E v1.0.3 — Native Ecosystem Approval Logic Fix.

.DESCRIPTION
    Corrige la lógica institucional de aprobación de SGD-114E cuando:
      - existen componentes nativos;
      - no existen términos prohibidos;
      - no existen dependencias propietarias obligatorias;
      - no existen errores estructurales.

    El parche:
      - mantiene intacta la política nativa;
      - corrige el algoritmo de decisión;
      - agrega explicación de criterios;
      - reejecuta pruebas específicas con SGD-114F;
      - ejecuta la suite completa;
      - vuelve a evaluar SPT-016A;
      - genera evidencia y release;
      - regenera SGD-115 y SGD-116;
      - publica mediante SPB-007 solo si todo aprueba.
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
        -Content (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
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

    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        $Relative = $Source.Replace($Root, "")
        $Relative = $Relative.TrimStart(
            [char[]]@([char]92, [char]47)
        )
        $Relative = $Relative.Replace(
            [string][char]92,
            "__"
        ).Replace("/", "__")

        Copy-Item `
            -LiteralPath $Source `
            -Destination (Join-Path $BackupDirectory $Relative) `
            -Force
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$GovernanceDir = Join-Path $ProjectRoot "src\sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E-v1.0.3"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114E-v1.0.3"
$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SGD114E-v1.0.3-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ValidatorPath = Join-Path $GovernanceDir "native_ecosystem_validator.py"
$CliPath = Join-Path $GovernanceDir "native_ecosystem_cli.py"
$PolicyPath = Join-Path $GovernanceDir "native_ecosystem_policy.py"
$ModelsPath = Join-Path $GovernanceDir "native_ecosystem_models.py"

$ExistingTestPath = Join-Path `
    $TestsDir `
    "test_SGD_114E_native_ecosystem_architecture_policy.py"

$PatchTestPath = Join-Path `
    $TestsDir `
    "test_SGD_114E_v1_0_3_approval_logic_fix.py"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SGD-114E-v1.0.3-component.json"

$PatchDoc = Join-Path `
    $DocsDir `
    "SGD-114E-v1.0.3-Native-Ecosystem-Approval-Logic-Fix.md"

$SpecificXml = Join-Path $ReportsDir "SGD-114E-v1.0.3-specific.xml"
$SpecificJson = Join-Path $ReportsDir "SGD-114E-v1.0.3-specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "SGD-114E-v1.0.3-specific-summary.md"
$FullXml = Join-Path $ReportsDir "SGD-114E-v1.0.3-full-suite.xml"
$FullJson = Join-Path $ReportsDir "SGD-114E-v1.0.3-full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "SGD-114E-v1.0.3-full-suite-summary.md"

$EvidencePath = Join-Path `
    $PmoDir `
    "SGD-114E-v1.0.3-implementation-evidence.json"

$EvidenceMd = Join-Path `
    $PmoDir `
    "SGD-114E-v1.0.3-implementation-evidence.md"

$SelfJson = Join-Path $PmoDir "SGD-114E-v1.0.3-self-validation.json"
$SelfMd = Join-Path $PmoDir "SGD-114E-v1.0.3-self-validation.md"
$Spt016AJson = Join-Path $PmoDir "SPT-016A-native-validation.json"
$Spt016AMd = Join-Path $PmoDir "SPT-016A-native-validation.md"

Step "Validando línea base institucional"

foreach ($Required in @(
    $ValidatorPath,
    $CliPath,
    $PolicyPath,
    $ModelsPath,
    $ExistingTestPath,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "config\learning_analytics\SPT-016A-component.json")
)) {
    Require-File $Required
}

Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Affected in @(
    $ValidatorPath,
    $CliPath,
    $PatchTestPath,
    $ComponentPath,
    $PatchDoc
)) {
    Backup-File $Affected $BackupDir $ProjectRoot
}

$Validator = @'
"""Validador de arquitectura nativa SGD-114E v1.0.3."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


_FORBIDDEN_TERMS = (
    "integrado por contrato",
    "integrada por contrato",
    "integrados por contrato",
    "integradas por contrato",
    "contract-based integration",
    "contract integration",
)


def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(
            path.read_text(encoding="utf-8-sig")
        )
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None

    return payload if isinstance(payload, dict) else None


def _component_files(root: Path) -> tuple[Path, ...]:
    config = root / "config"

    if not config.exists():
        return ()

    return tuple(
        sorted(
            path
            for path in config.rglob("*.json")
            if (
                "component" in path.name.casefold()
                or "metadata" in path.name.casefold()
            )
        )
    )


def _contains_forbidden_term(
    path: Path,
) -> tuple[dict[str, str], ...]:
    try:
        text = path.read_text(
            encoding="utf-8-sig",
            errors="replace",
        ).casefold()
    except OSError:
        return ()

    findings = []

    for term in _FORBIDDEN_TERMS:
        if term in text:
            findings.append(
                {
                    "path": path.as_posix(),
                    "term": term,
                }
            )

    return tuple(findings)


def evaluate_native_ecosystem(
    root: str | Path,
) -> dict[str, Any]:
    project_root = Path(root).resolve()
    component_files = _component_files(project_root)

    native_components = []
    proprietary_dependencies = []
    structural_errors = []

    for path in component_files:
        payload = _read_json(path)

        if payload is None:
            structural_errors.append(
                {
                    "path": path.as_posix(),
                    "error": "invalid_or_unreadable_json",
                }
            )
            continue

        code = str(
            payload.get("increment_code")
            or payload.get("component")
            or path.stem
        )

        native_flag = payload.get("native_ecosystem")

        if native_flag is True:
            native_components.append(code)

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
            continue

        for dependency in dependencies:
            text = str(dependency).strip()

            if text:
                proprietary_dependencies.append(
                    {
                        "component": code,
                        "dependency": text,
                        "path": path.as_posix(),
                    }
                )

    forbidden_terms = []

    for base in (
        project_root / "config",
        project_root / "docs",
        project_root / "src",
    ):
        if not base.exists():
            continue

        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue

            if path.suffix.casefold() not in {
                ".json",
                ".md",
                ".py",
                ".ps1",
                ".txt",
                ".yaml",
                ".yml",
            }:
                continue

            forbidden_terms.extend(
                _contains_forbidden_term(path)
            )

    criteria = {
        "has_native_components": len(native_components) > 0,
        "no_forbidden_terms": len(forbidden_terms) == 0,
        "no_mandatory_proprietary_dependencies": (
            len(proprietary_dependencies) == 0
        ),
        "no_structural_errors": len(structural_errors) == 0,
    }

    approved = all(criteria.values())

    return {
        "policy": "SGD-114E",
        "version": "1.0.3",
        "approved": approved,
        "result": "APROBADO" if approved else "NO APROBADO",
        "criteria": criteria,
        "native_component_count": len(native_components),
        "native_components": sorted(set(native_components)),
        "forbidden_term_count": len(forbidden_terms),
        "forbidden_terms": forbidden_terms,
        "mandatory_proprietary_dependency_count": (
            len(proprietary_dependencies)
        ),
        "mandatory_proprietary_dependencies": (
            proprietary_dependencies
        ),
        "structural_error_count": len(structural_errors),
        "structural_errors": structural_errors,
        "decision_rule": (
            "approved = has_native_components AND "
            "no_forbidden_terms AND "
            "no_mandatory_proprietary_dependencies AND "
            "no_structural_errors"
        ),
    }
'@

$Cli = @'
"""CLI SGD-114E v1.0.3."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    result = evaluate_native_ecosystem(args.root)

    json_target = Path(args.output_json)
    md_target = Path(args.output_md)
    json_target.parent.mkdir(parents=True, exist_ok=True)
    md_target.parent.mkdir(parents=True, exist_ok=True)

    json_target.write_text(
        json.dumps(
            result,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    criteria = result["criteria"]

    md_target.write_text(
        "\n".join(
            [
                "# SGD-114E — Native Ecosystem Validation",
                "",
                f"- Versión: {result['version']}",
                f"- Resultado: {result['result']}",
                (
                    "- Componentes nativos: "
                    f"{result['native_component_count']}"
                ),
                (
                    "- Términos prohibidos: "
                    f"{result['forbidden_term_count']}"
                ),
                (
                    "- Dependencias propietarias obligatorias: "
                    f"{result['mandatory_proprietary_dependency_count']}"
                ),
                (
                    "- Errores estructurales: "
                    f"{result['structural_error_count']}"
                ),
                "",
                "## Criterios",
                "",
                (
                    "- Existen componentes nativos: "
                    f"{criteria['has_native_components']}"
                ),
                (
                    "- Sin términos prohibidos: "
                    f"{criteria['no_forbidden_terms']}"
                ),
                (
                    "- Sin dependencias propietarias obligatorias: "
                    f"{criteria['no_mandatory_proprietary_dependencies']}"
                ),
                (
                    "- Sin errores estructurales: "
                    f"{criteria['no_structural_errors']}"
                ),
                "",
                f"Regla: `{result['decision_rule']}`",
                "",
            ]
        ),
        encoding="utf-8",
    )

    print("SGD-114E ejecutado correctamente.")
    print(f"Resultado: {result['result']}")
    print(
        "Componentes nativos: "
        f"{result['native_component_count']}"
    )
    print(
        "Términos prohibidos: "
        f"{result['forbidden_term_count']}"
    )
    print(
        "Dependencias propietarias obligatorias: "
        f"{result['mandatory_proprietary_dependency_count']}"
    )
    print(
        "Errores estructurales: "
        f"{result['structural_error_count']}"
    )
    print(f"JSON: {json_target}")
    print(f"Markdown: {md_target}")

    return 0 if result["approved"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$PatchTests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def _write_component(
    root: Path,
    *,
    code: str = "SPT-016A",
    native: bool = True,
    dependencies: list[str] | None = None,
) -> None:
    target = root / "config" / "test"
    target.mkdir(parents=True, exist_ok=True)
    (target / "component.json").write_text(
        json.dumps(
            {
                "increment_code": code,
                "native_ecosystem": native,
                "mandatory_proprietary_dependencies": (
                    dependencies or []
                ),
            }
        ),
        encoding="utf-8",
    )


def test_approves_valid_native_ecosystem(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is True
    assert result["result"] == "APROBADO"


def test_rejects_without_native_components(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path, native=False)

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is False
    assert result["criteria"]["has_native_components"] is False


def test_rejects_proprietary_dependency(
    tmp_path: Path,
) -> None:
    _write_component(
        tmp_path,
        dependencies=["proprietary-service"],
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is False
    assert (
        result["mandatory_proprietary_dependency_count"]
        == 1
    )


def test_rejects_forbidden_term(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)
    docs = tmp_path / "docs"
    docs.mkdir(parents=True)
    (docs / "bad.md").write_text(
        "integrado por contrato",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is False
    assert result["forbidden_term_count"] == 1


def test_rejects_invalid_json(
    tmp_path: Path,
) -> None:
    target = tmp_path / "config" / "test"
    target.mkdir(parents=True)
    (target / "component.json").write_text(
        "{invalid",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is False
    assert result["structural_error_count"] == 1


def test_decision_rule_uses_all_criteria(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert all(result["criteria"].values())
    assert result["approved"] is True


def test_counts_native_components(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path, code="SPT-016A")

    second = tmp_path / "config" / "second"
    second.mkdir(parents=True)
    (second / "component.json").write_text(
        json.dumps(
            {
                "increment_code": "SPT-017",
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": [],
            }
        ),
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["native_component_count"] == 2


def test_returns_version_1_0_3(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert result["version"] == "1.0.3"


def test_empty_dependency_list_is_valid(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path, dependencies=[])

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is True


def test_none_dependency_list_is_valid(
    tmp_path: Path,
) -> None:
    target = tmp_path / "config" / "test"
    target.mkdir(parents=True)
    (target / "component.json").write_text(
        json.dumps(
            {
                "increment_code": "SPT-016A",
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": None,
            }
        ),
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is True
'@

$Component = @'
{
  "increment_code": "SGD-114E-v1.0.3",
  "name": "Native Ecosystem Approval Logic Fix",
  "component_type": "governance_logic_patch",
  "version": "1.0.3",
  "status": "implemented",
  "phase": "Gobierno Digital",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "SGD-114E",
    "SGD-114F",
    "SGD-115A",
    "SGD-116",
    "SPB-007"
  ],
  "scope": [
    "approval decision logic",
    "criteria transparency",
    "structural validation",
    "SPT-016A revalidation"
  ]
}
'@

$Documentation = @'
# SGD-114E v1.0.3 — Native Ecosystem Approval Logic Fix

## Problema

El validador podía informar simultáneamente:

- componentes nativos mayores que cero;
- cero términos prohibidos;
- cero dependencias propietarias obligatorias;

y aun así emitir `NO APROBADO`.

## Corrección

La versión 1.0.3 define una regla explícita y verificable:

`approved = has_native_components AND no_forbidden_terms AND
no_mandatory_proprietary_dependencies AND no_structural_errors`

Cada criterio queda registrado en JSON y Markdown.

## Alcance

El parche modifica únicamente la lógica de evaluación y la salida explicativa.
No altera la política institucional de ecosistema nativo.
'@

Step "Aplicando corrección SGD-114E v1.0.3"

Write-Utf8 -Path $ValidatorPath -Content $Validator
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $PatchTestPath -Content $PatchTests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $PatchDoc -Content $Documentation

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/native_ecosystem_validator.py" `
        "src/sgoda/governance/native_ecosystem_cli.py" `
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py" `
        "tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py"
}

Run "Ejecutando pruebas específicas SGD-114E mediante SGD-114F" {
    & (Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1") `
        -Component "SGD-114E-v1.0.3" `
        -TestPath "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py tests/governance/test_SGD_114E_v1_0_3_approval_logic_fix.py" `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific"
}

$SpecificSummary = Get-Content `
    -LiteralPath $SpecificJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$SpecificSummary.approved) {
    throw "Las pruebas específicas SGD-114E no fueron aprobadas."
}

if (-not $SkipFullSuite) {
    Run "Ejecutando suite completa con evidencia JUnit" {
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

    $FullSummary = Get-Content `
        -LiteralPath $FullJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$FullSummary.approved) {
        throw "La suite completa no fue aprobada."
    }
}

Step "Autoevaluando SGD-114E v1.0.3"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$SelfJson" `
    --output-md "$SelfMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E v1.0.3 no aprobó su autoevaluación."
}

$SelfResult = Get-Content `
    -LiteralPath $SelfJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$SelfResult.approved) {
    throw "La autoevaluación SGD-114E no fue aprobada."
}

Step "Reevaluando SPT-016A"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$Spt016AJson" `
    --output-md "$Spt016AMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E v1.0.3 no aprobó SPT-016A."
}

$Spt016AResult = Get-Content `
    -LiteralPath $Spt016AJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Spt016AResult.approved) {
    throw "SPT-016A continúa sin aprobación nativa."
}

Step "Generando evidencia y release"

$FullSuiteEvidence = $null

if (-not $SkipFullSuite) {
    $FullSuiteEvidence = [ordered]@{
        executed = [int]$FullSummary.executed
        passed = [int]$FullSummary.passed
        failures = [int]$FullSummary.failures
        errors = [int]$FullSummary.errors
        skipped = [int]$FullSummary.skipped
        duration_seconds = [double]$FullSummary.duration_seconds
        approved = [bool]$FullSummary.approved
        source_report = [string]$FullSummary.source_report
    }
}

$Evidence = [ordered]@{
    increment_code = "SGD-114E-v1.0.3"
    target_component = "SGD-114E"
    version = "1.0.3"
    status = "implemented_tested_and_approved"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    patch_type = "approval_logic_fix"
    specific_tests = [ordered]@{
        executed = [int]$SpecificSummary.executed
        passed = [int]$SpecificSummary.passed
        failures = [int]$SpecificSummary.failures
        errors = [int]$SpecificSummary.errors
        skipped = [int]$SpecificSummary.skipped
        duration_seconds = [double]$SpecificSummary.duration_seconds
        approved = [bool]$SpecificSummary.approved
        source_report = [string]$SpecificSummary.source_report
    }
    full_suite = $FullSuiteEvidence
    self_validation = [ordered]@{
        approved = [bool]$SelfResult.approved
        native_components = [int]$SelfResult.native_component_count
        forbidden_terms = [int]$SelfResult.forbidden_term_count
        proprietary_dependencies = (
            [int]$SelfResult.mandatory_proprietary_dependency_count
        )
        structural_errors = [int]$SelfResult.structural_error_count
        decision_rule = [string]$SelfResult.decision_rule
    }
    spt_016a_revalidation = [ordered]@{
        approved = [bool]$Spt016AResult.approved
        result = [string]$Spt016AResult.result
    }
    backup = $BackupDir
}

Write-Json -Path $EvidencePath -Value $Evidence

$EvidenceMarkdown = @"
# SGD-114E v1.0.3 — Evidencia institucional

- Resultado: APROBADO
- Tipo de parche: approval_logic_fix
- Pruebas específicas: $($SpecificSummary.passed)/$($SpecificSummary.executed)
- Componentes nativos: $($SelfResult.native_component_count)
- Términos prohibidos: $($SelfResult.forbidden_term_count)
- Dependencias propietarias obligatorias: $($SelfResult.mandatory_proprietary_dependency_count)
- Errores estructurales: $($SelfResult.structural_error_count)
- SPT-016A reevaluado: $($Spt016AResult.result)
- Regla: $($SelfResult.decision_rule)
"@

if (-not $SkipFullSuite) {
    $EvidenceMarkdown += @"

- Suite completa: $($FullSummary.passed)/$($FullSummary.executed)
- Fallos: $($FullSummary.failures)
- Errores: $($FullSummary.errors)
- Omitidas: $($FullSummary.skipped)
"@
}

Write-Utf8 -Path $EvidenceMd -Content $EvidenceMarkdown

foreach ($ReleaseFile in @(
    $ValidatorPath,
    $CliPath,
    $PolicyPath,
    $ModelsPath,
    $ExistingTestPath,
    $PatchTestPath,
    $ComponentPath,
    $PatchDoc,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $SelfJson,
    $SelfMd,
    $Spt016AJson,
    $Spt016AMd,
    $EvidencePath,
    $EvidenceMd
)) {
    Require-File $ReleaseFile
    Copy-Item -LiteralPath $ReleaseFile -Destination $ReleaseDir -Force
}

if (-not $SkipFullSuite) {
    foreach ($FullFile in @(
        $FullXml,
        $FullJson,
        $FullMd
    )) {
        Require-File $FullFile
        Copy-Item -LiteralPath $FullFile -Destination $ReleaseDir -Force
    }
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SGD-114E-v1.0.3"
        version = "1.0.3"
        status = "implemented_tested_and_approved"
        files = @(
            Get-ChildItem -LiteralPath $ReleaseDir -File |
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
        -CommitMessage "fix(governance): implement SGD-114E v1.0.3 approval logic fix" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114E v1.0.3 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SGD-114E v1.0.3 implementado." -ForegroundColor Green
Write-Host "Native Ecosystem Approval Logic Fix: APLICADO." `
    -ForegroundColor Green
Write-Host (
    "Pruebas específicas: " +
    "$($SpecificSummary.passed)/$($SpecificSummary.executed) APROBADAS."
) -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host (
        "Suite completa: " +
        "$($FullSummary.passed)/$($FullSummary.executed) APROBADAS."
    ) -ForegroundColor Green
}

Write-Host "Autoevaluación SGD-114E: APROBADA." -ForegroundColor Green
Write-Host "SPT-016A: APROBADO POR SGD-114E." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SGD-114E-v1.0.3" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Publicación no solicitada. Reejecute con -Publish." `
        -ForegroundColor Yellow
}
