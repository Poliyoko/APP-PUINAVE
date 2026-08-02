<#
.SYNOPSIS
    Instala SGD-114 Policy Auditor para diagnosticar y cerrar errores del
    Quality Gate institucional.

.DESCRIPTION
    Crea un auditor independiente que:
      - carga la política SGD-114;
      - carga la evidencia generada por evidence_policy;
      - identifica reglas fallidas;
      - identifica listas no vacías de incumplimientos;
      - verifica rutas y evidencias requeridas;
      - inspecciona el componente SGD-116B;
      - genera un informe JSON y Markdown;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - vuelve a ejecutar el quality gate en modo diagnóstico.

    No modifica automáticamente la política ni falsifica evidencias.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio.

.PARAMETER Increment
    Incremento a auditar. Por defecto SGD-116B.

.PARAMETER SkipFullSuite
    Omite la suite completa.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$Increment = "SGD-116B",
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró: $Path"
    }
}

function Run-Checked([string]$Name, [scriptblock]$Action) {
    Step $Name
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Name terminó con errores. Código: $LASTEXITCODE"
    }
}

function Write-Utf8([string]$Path, [string]$Content) {
    $Parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$PolicyPath = Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"
$EvidencePolicyModule = Join-Path $ProjectRoot "src\sgoda\governance\evidence_policy.py"

Require-File $PolicyPath
Require-File $EvidencePolicyModule

$SourceDir = Join-Path $ProjectRoot "src\sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114-Policy-Auditor"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114-Policy-Auditor-v1.0.0"

$AuditorPath = Join-Path $SourceDir "policy_auditor.py"
$TestPath = Join-Path $TestsDir "test_SGD_114_policy_auditor.py"
$ConfigPath = Join-Path $ConfigDir "SGD-114-policy-auditor-component.json"
$DocPath = Join-Path $DocsDir "SGD-114-Policy-Auditor.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SGD114-PolicyAuditor.ps1"
$GateOutput = Join-Path $ArtifactsDir "$Increment-quality-gate.json"
$ReportJson = Join-Path $ArtifactsDir "$Increment-policy-audit.json"
$ReportMd = Join-Path $ArtifactsDir "$Increment-policy-audit.md"

Step "Creando respaldo"
$BackupDir = Join-Path $ArtifactsDir ("backups\" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Path in @($AuditorPath, $TestPath, $ConfigPath, $DocPath, $InvokePath)) {
    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination $BackupDir -Force
    }
}

$Auditor = @'
"""Auditor institucional de políticas SGD-114."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PASS_KEYS = {
    "passed",
    "approved",
    "compliant",
    "authorized",
    "valid",
    "exists",
    "present",
    "clean",
}

FAIL_LIST_HINTS = {
    "missing",
    "failed",
    "broken",
    "violations",
    "errors",
    "warnings",
    "unmet",
    "unauthorized",
    "invalid",
}


@dataclass(slots=True)
class Finding:
    severity: str
    code: str
    path: str
    message: str
    value: Any
    recommendation: str


@dataclass(slots=True)
class AuditResult:
    increment: str
    passed: bool
    finding_count: int
    blocking_count: int
    findings: list[Finding]
    generated_at_utc: str


def _key_tokens(path: str) -> set[str]:
    normalized = path.replace("[", ".").replace("]", "")
    return {
        token.lower()
        for token in normalized.replace("-", "_").split(".")
        if token
    }


def _walk(value: Any, path: str = "$"):
    yield path, value

    if isinstance(value, dict):
        for key, child in value.items():
            yield from _walk(child, f"{path}.{key}")

    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from _walk(child, f"{path}[{index}]")


def _looks_blocking_boolean(path: str, value: bool) -> bool:
    if value is not False:
        return False

    tokens = _key_tokens(path)
    return bool(tokens & PASS_KEYS)


def _looks_failure_list(path: str, value: list[Any]) -> bool:
    if not value:
        return False

    tokens = _key_tokens(path)
    return any(
        any(hint in token for hint in FAIL_LIST_HINTS)
        for token in tokens
    )


def _path_candidates(payload: Any) -> list[str]:
    candidates: list[str] = []

    for path, value in _walk(payload):
        if not isinstance(value, str):
            continue

        lower_path = path.lower()
        if any(
            hint in lower_path
            for hint in (
                "path",
                "file",
                "document",
                "evidence",
                "artifact",
                "release",
                "source",
                "test",
            )
        ):
            candidates.append(value)

    return sorted(set(candidates))


def audit_policy_gate(
    root: str | Path,
    policy: dict[str, Any],
    gate: dict[str, Any],
    increment: str,
) -> AuditResult:
    repository = Path(root)
    findings: list[Finding] = []

    for path, value in _walk(gate):
        if isinstance(value, bool) and _looks_blocking_boolean(path, value):
            findings.append(
                Finding(
                    severity="blocking",
                    code="BOOLEAN_RULE_FAILED",
                    path=path,
                    message="La regla booleana institucional no fue aprobada.",
                    value=value,
                    recommendation=(
                        "Revise la regla, la evidencia asociada y el estado "
                        "institucional del incremento."
                    ),
                )
            )

        elif isinstance(value, list) and _looks_failure_list(path, value):
            findings.append(
                Finding(
                    severity="blocking",
                    code="NON_EMPTY_FAILURE_LIST",
                    path=path,
                    message="La colección de incumplimientos no está vacía.",
                    value=value,
                    recommendation=(
                        "Resuelva cada elemento listado y regenere la evidencia."
                    ),
                )
            )

    for candidate in _path_candidates(policy) + _path_candidates(gate):
        clean = candidate.strip().replace("\\", "/")

        if not clean:
            continue

        if "://" in clean:
            continue

        absolute = repository / clean.rstrip("/")

        if not absolute.exists():
            findings.append(
                Finding(
                    severity="blocking",
                    code="MISSING_REFERENCED_PATH",
                    path=clean,
                    message="La ruta referenciada no existe en el repositorio.",
                    value=clean,
                    recommendation=(
                        "Cree la evidencia legítima o corrija la referencia "
                        "en el descriptor correspondiente."
                    ),
                )
            )

    component_descriptors = sorted(
        repository.glob(f"config/**/*{increment}*component*.json")
    )

    if not component_descriptors:
        findings.append(
            Finding(
                severity="blocking",
                code="COMPONENT_DESCRIPTOR_MISSING",
                path="config/**",
                message=f"No se encontró descriptor para {increment}.",
                value=increment,
                recommendation=(
                    "Cree un descriptor institucional del componente con "
                    "código, versión, dependencias, fuentes, pruebas y documentos."
                ),
            )
        )

    release_matches = sorted(
        (repository / "releases").glob(f"{increment}-v*")
    )

    if not release_matches:
        findings.append(
            Finding(
                severity="blocking",
                code="RELEASE_MISSING",
                path="releases/",
                message=f"No se encontró release versionado para {increment}.",
                value=increment,
                recommendation=(
                    "Genere el release técnico antes de solicitar cierre."
                ),
            )
        )

    blocking = [
        item
        for item in findings
        if item.severity == "blocking"
    ]

    return AuditResult(
        increment=increment,
        passed=not blocking,
        finding_count=len(findings),
        blocking_count=len(blocking),
        findings=findings,
        generated_at_utc=datetime.now(timezone.utc).isoformat(),
    )


def write_reports(
    result: AuditResult,
    json_path: str | Path,
    markdown_path: str | Path,
) -> None:
    json_target = Path(json_path)
    md_target = Path(markdown_path)

    json_target.parent.mkdir(parents=True, exist_ok=True)
    md_target.parent.mkdir(parents=True, exist_ok=True)

    payload = asdict(result)
    json_target.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    lines = [
        f"# Auditoría de Política SGD-114 — {result.increment}",
        "",
        f"- Resultado: {'APROBADO' if result.passed else 'NO APROBADO'}",
        f"- Hallazgos: {result.finding_count}",
        f"- Bloqueantes: {result.blocking_count}",
        f"- Generado: {result.generated_at_utc}",
        "",
        "## Hallazgos",
        "",
    ]

    if not result.findings:
        lines.append("No se encontraron incumplimientos.")

    for index, finding in enumerate(result.findings, start=1):
        lines.extend(
            [
                f"### {index}. {finding.code}",
                "",
                f"- Severidad: {finding.severity}",
                f"- Ruta: `{finding.path}`",
                f"- Mensaje: {finding.message}",
                f"- Valor: `{finding.value!r}`",
                f"- Recomendación: {finding.recommendation}",
                "",
            ]
        )

    md_target.write_text(
        "\n".join(lines).rstrip() + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--policy", required=True)
    parser.add_argument("--gate", required=True)
    parser.add_argument("--increment", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    policy = json.loads(
        Path(args.policy).read_text(encoding="utf-8-sig")
    )
    gate = json.loads(
        Path(args.gate).read_text(encoding="utf-8-sig")
    )

    result = audit_policy_gate(
        args.root,
        policy,
        gate,
        args.increment,
    )

    write_reports(
        result,
        args.output_json,
        args.output_md,
    )

    print("SGD-114 Policy Auditor completado.")
    print("Resultado:", "APROBADO" if result.passed else "NO APROBADO")
    print("Hallazgos:", result.finding_count)
    print("Bloqueantes:", result.blocking_count)
    print("JSON:", args.output_json)
    print("Markdown:", args.output_md)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Tests = @'
from pathlib import Path

from sgoda.governance.policy_auditor import audit_policy_gate


def test_policy_auditor_detects_failed_boolean(tmp_path: Path) -> None:
    result = audit_policy_gate(
        tmp_path,
        {},
        {"passed": False},
        "SGD-116B",
    )

    assert result.passed is False
    assert any(
        item.code == "BOOLEAN_RULE_FAILED"
        for item in result.findings
    )


def test_policy_auditor_detects_failure_list(tmp_path: Path) -> None:
    result = audit_policy_gate(
        tmp_path,
        {},
        {"missing_evidence": ["docs/x.md"]},
        "SGD-116B",
    )

    assert result.passed is False
    assert any(
        item.code == "NON_EMPTY_FAILURE_LIST"
        for item in result.findings
    )


def test_policy_auditor_detects_missing_path(tmp_path: Path) -> None:
    result = audit_policy_gate(
        tmp_path,
        {"required_document": "docs/x.md"},
        {},
        "SGD-116B",
    )

    assert any(
        item.code == "MISSING_REFERENCED_PATH"
        for item in result.findings
    )


def test_policy_auditor_approves_complete_minimum(tmp_path: Path) -> None:
    descriptor = (
        tmp_path
        / "config"
        / "roadmap"
        / "SGD-116B-component.json"
    )
    descriptor.parent.mkdir(parents=True)
    descriptor.write_text("{}", encoding="utf-8")

    release = tmp_path / "releases" / "SGD-116B-v3.0.0"
    release.mkdir(parents=True)

    result = audit_policy_gate(
        tmp_path,
        {},
        {"passed": True},
        "SGD-116B",
    )

    assert result.passed is True
    assert result.blocking_count == 0
'@

$Component = @'
{
  "increment_code": "SGD-114-PA",
  "name": "SGD-114 Policy Auditor",
  "component_type": "governance_policy_auditor",
  "version": "1.0.0",
  "status": "implemented",
  "dependencies": [
    "SGD-114",
    "SGD-115",
    "SGD-116B"
  ],
  "source": [
    "src/sgoda/governance/policy_auditor.py"
  ],
  "tests": [
    "tests/governance/test_SGD_114_policy_auditor.py"
  ],
  "documentation": [
    "docs/01_Gobierno/SGD-114-Policy-Auditor.md"
  ]
}
'@

$Doc = @'
# SGD-114 Policy Auditor

Componente institucional de diagnóstico para quality gates SGD-114.

## Funciones

- inspecciona la política;
- inspecciona la evidencia del gate;
- identifica reglas booleanas fallidas;
- identifica colecciones de incumplimientos;
- verifica rutas referenciadas;
- verifica descriptor y release del incremento;
- genera informe JSON y Markdown.

El auditor no modifica la política ni crea evidencias falsas.
'@

$Invoke = @'
[CmdletBinding()]
param(
    [string]$Increment = "SGD-116B"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Policy = "config/governance/sgd-114-policy.json"
$OutputDir = "artifacts/pmo/SGD-114-Policy-Auditor"
$Gate = Join-Path $OutputDir "$Increment-quality-gate.json"
$Json = Join-Path $OutputDir "$Increment-policy-audit.json"
$Markdown = Join-Path $OutputDir "$Increment-policy-audit.md"

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

& python -m sgoda.governance.evidence_policy `
    --root "." `
    --policy $Policy `
    --increment $Increment `
    --status "technically_completed" `
    --output $Gate

$GateExitCode = $LASTEXITCODE

if (-not (Test-Path -LiteralPath $Gate)) {
    throw "El motor evidence_policy no produjo evidencia."
}

& python -m sgoda.governance.policy_auditor `
    --root "." `
    --policy $Policy `
    --gate $Gate `
    --increment $Increment `
    --output-json $Json `
    --output-md $Markdown

if ($LASTEXITCODE -ne 0) {
    throw "El Policy Auditor terminó con errores."
}

Write-Host ""
Write-Host "Quality gate exit code: $GateExitCode" -ForegroundColor Cyan
Write-Host "Informe JSON: $Json" -ForegroundColor Cyan
Write-Host "Informe Markdown: $Markdown" -ForegroundColor Cyan
'@

Write-Utf8 $AuditorPath $Auditor
Write-Utf8 $TestPath $Tests
Write-Utf8 $ConfigPath $Component
Write-Utf8 $DocPath $Doc
Write-Utf8 $InvokePath $Invoke

Run-Checked "Validando sintaxis" {
    python -m py_compile `
        "src/sgoda/governance/policy_auditor.py" `
        "tests/governance/test_SGD_114_policy_auditor.py"
}

Run-Checked "Ejecutando pruebas específicas" {
    python -m pytest `
        "tests/governance/test_SGD_114_policy_auditor.py" `
        -q
}

if (-not $SkipFullSuite) {
    Run-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Step "Ejecutando quality gate en modo diagnóstico"
New-Item -ItemType Directory -Path $ArtifactsDir -Force | Out-Null

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "$PolicyPath" `
    --increment "$Increment" `
    --status "technically_completed" `
    --output "$GateOutput"

$GateExitCode = $LASTEXITCODE

if (-not (Test-Path -LiteralPath $GateOutput)) {
    throw "evidence_policy no produjo el archivo de evidencia."
}

Run-Checked "Generando auditoría detallada" {
    python -m sgoda.governance.policy_auditor `
        --root "$ProjectRoot" `
        --policy "$PolicyPath" `
        --gate "$GateOutput" `
        --increment "$Increment" `
        --output-json "$ReportJson" `
        --output-md "$ReportMd"
}

Step "Creando release"
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
foreach ($Path in @($AuditorPath, $TestPath, $ConfigPath, $DocPath, $InvokePath, $GateOutput, $ReportJson, $ReportMd)) {
    Copy-Item -LiteralPath $Path -Destination (Join-Path $ReleaseDir (Split-Path $Path -Leaf)) -Force
}

Step "Resultado final"
Write-Host "SGD-114 Policy Auditor implementado." -ForegroundColor Green
Write-Host "Pruebas específicas: APROBADAS." -ForegroundColor Green
if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}
Write-Host "Quality gate original exit code: $GateExitCode" -ForegroundColor Cyan
Write-Host "Informe JSON: $ReportJson" -ForegroundColor Cyan
Write-Host "Informe Markdown: $ReportMd" -ForegroundColor Cyan
Write-Host "Release: releases\SGD-114-Policy-Auditor-v1.0.0" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise el informe Markdown para aplicar la corrección exacta." -ForegroundColor Yellow
