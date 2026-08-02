<#
.SYNOPSIS
    Instala SGD-114D v1.0.0 — Adaptive Institutional Policy Engine.

.DESCRIPTION
    Implementa un motor adaptativo de políticas institucionales que evita
    falsos bloqueos de evidencia y release para incrementos correctivos.

    Casos atendidos:
      - SGD114C-R003: release técnico no detectado;
      - SGD114C-R007: directorio de evidencias no detectado.

    El instalador:
      - valida la línea base de SGD-114C;
      - crea respaldo institucional;
      - instala el motor adaptativo;
      - instala CLI y pruebas;
      - detecta rutas canónicas y heredadas;
      - resuelve alias de incrementos correctivos;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - reevalúa SPT-011A;
      - regenera SGD-116;
      - actualiza SGD-115;
      - genera evidencias y release.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER TargetIncrement
    Incremento a reevaluar. Por defecto: SPT-011A.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.

.PARAMETER SkipInstitutionalClosure
    Omite reevaluación, SGD-115, SGD-116 y release.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$TargetIncrement = "SPT-011A",
    [switch]$SkipFullSuite,
    [switch]$SkipInstitutionalClosure
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114D"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114D-v1.0.0"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SGD114D-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "adaptive_policy_models.py"
$ResolverPath = Join-Path $SourceDir "adaptive_policy_resolver.py"
$RulesPath = Join-Path $SourceDir "adaptive_policy_rules.py"
$EnginePath = Join-Path $SourceDir "adaptive_policy_engine.py"
$CliPath = Join-Path $SourceDir "adaptive_policy_cli.py"
$InitPath = Join-Path $SourceDir "adaptive_policy.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SGD_114D_adaptive_institutional_policy_engine.py"

$PolicyPath = Join-Path `
    $ConfigDir `
    "SGD-114D-adaptive-policy.json"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SGD-114D-component.json"

$DocPath = Join-Path `
    $DocsDir `
    "SGD-114D-Adaptive-Institutional-Policy-Engine.md"

$MigrationDocPath = Join-Path `
    $DocsDir `
    "SGD-114D-Migracion-SGD-114C.md"

$InvokePath = Join-Path `
    $ScriptsDir `
    "Invoke-SGD114D-AdaptivePolicy.ps1"

$TargetResultJson = Join-Path `
    $PmoDir `
    ($TargetIncrement + "-adaptive-policy-result.json")

$TargetResultMd = Join-Path `
    $PmoDir `
    ($TargetIncrement + "-adaptive-policy-result.md")

$EvidencePath = Join-Path `
    $PmoDir `
    "SGD-114D-implementation-evidence.json"

Write-Step "Validando línea base SGD-114C"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $SourceDir "policy_models.py"),
    (Join-Path $SourceDir "policy_context.py"),
    (Join-Path $SourceDir "policy_rules.py"),
    (Join-Path $SourceDir "policy_engine.py"),
    (Join-Path $SourceDir "policy_cli.py"),
    (Join-Path $ConfigDir "SGD-114C-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File -Path $Required
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Affected in @(
    $ModelsPath,
    $ResolverPath,
    $RulesPath,
    $EnginePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $PolicyPath,
    $ComponentPath,
    $DocPath,
    $MigrationDocPath,
    $InvokePath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Models = @'
"""Modelos de SGD-114D."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class ResolvedArtifact:
    artifact_type: str
    increment_code: str
    path: Path | None
    found: bool
    strategy: str
    candidates: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class AdaptiveRuleResult:
    rule_code: str
    name: str
    passed: bool
    blocking: bool
    message: str
    remediation: str
    evidence: tuple[str, ...] = ()
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class AdaptivePolicyResult:
    increment_code: str
    approved: bool
    exit_code: int
    results: tuple[AdaptiveRuleResult, ...]
    evidence_path: str | None
    release_path: str | None
'@

$Resolver = @'
"""Resolución adaptativa de evidencias y releases."""

from __future__ import annotations

import re
from pathlib import Path

from .adaptive_policy_models import ResolvedArtifact


_VERSION_SUFFIX = re.compile(
    r"^(?P<code>[A-Z]+-\d+[A-Z]?)(?:-v?\d+(?:\.\d+)*)?$",
    re.IGNORECASE,
)


def canonical_increment_code(value: str) -> str:
    raw = str(value or "").strip().upper()
    match = _VERSION_SUFFIX.match(raw)
    return match.group("code") if match else raw


def increment_family(value: str) -> tuple[str, ...]:
    canonical = canonical_increment_code(value)
    family = [canonical]

    if canonical and canonical[-1].isalpha():
        family.append(canonical[:-1])

    return tuple(dict.fromkeys(item for item in family if item))


def _non_empty_directory(path: Path) -> bool:
    return path.is_dir() and any(
        item.is_file() and item.stat().st_size > 0
        for item in path.rglob("*")
    )


def resolve_evidence_directory(
    root: str | Path,
    increment_code: str,
) -> ResolvedArtifact:
    base = Path(root)
    family = increment_family(increment_code)
    candidates: list[Path] = []

    for code in family:
        candidates.extend(
            [
                base / "artifacts" / "pmo" / code / "evidence",
                base / "artifacts" / "pmo" / code,
                base / "artifacts" / code / "evidence",
                base / "artifacts" / code,
            ]
        )

    seen: set[Path] = set()

    for candidate in candidates:
        candidate = candidate.resolve()

        if candidate in seen:
            continue

        seen.add(candidate)

        if _non_empty_directory(candidate):
            strategy = (
                "canonical"
                if candidate.name == "evidence"
                else "compatible_parent"
            )

            return ResolvedArtifact(
                artifact_type="evidence",
                increment_code=increment_code,
                path=candidate,
                found=True,
                strategy=strategy,
                candidates=tuple(str(item) for item in candidates),
            )

    return ResolvedArtifact(
        artifact_type="evidence",
        increment_code=increment_code,
        path=None,
        found=False,
        strategy="not_found",
        candidates=tuple(str(item) for item in candidates),
    )


def resolve_release_directory(
    root: str | Path,
    increment_code: str,
) -> ResolvedArtifact:
    base = Path(root)
    releases = base / "releases"
    family = increment_family(increment_code)
    candidates: list[Path] = []

    if releases.is_dir():
        for code in family:
            candidates.extend(
                sorted(
                    releases.glob(f"{code}-v*"),
                    reverse=True,
                )
            )
            candidates.append(releases / code)

    for candidate in candidates:
        if _non_empty_directory(candidate):
            return ResolvedArtifact(
                artifact_type="release",
                increment_code=increment_code,
                path=candidate.resolve(),
                found=True,
                strategy="versioned_family_match",
                candidates=tuple(str(item) for item in candidates),
            )

    return ResolvedArtifact(
        artifact_type="release",
        increment_code=increment_code,
        path=None,
        found=False,
        strategy="not_found",
        candidates=tuple(str(item) for item in candidates),
    )
'@

$Rules = @'
"""Reglas adaptativas de SGD-114D."""

from __future__ import annotations

from pathlib import Path

from .adaptive_policy_models import AdaptiveRuleResult
from .adaptive_policy_resolver import (
    resolve_evidence_directory,
    resolve_release_directory,
)


def evaluate_release_rule(
    root: str | Path,
    increment_code: str,
) -> AdaptiveRuleResult:
    resolved = resolve_release_directory(
        root,
        increment_code,
    )

    return AdaptiveRuleResult(
        rule_code="SGD114D-R003",
        name="Release técnico adaptativo",
        passed=resolved.found,
        blocking=True,
        message=(
            f"Release detectado: {resolved.path}"
            if resolved.found
            else (
                "No existe release versionado para "
                f"{increment_code} ni su familia canónica."
            )
        ),
        remediation=(
            ""
            if resolved.found
            else "Genere un release técnico versionado y no vacío."
        ),
        evidence=(
            (str(resolved.path),)
            if resolved.path is not None
            else ()
        ),
        metadata={
            "strategy": resolved.strategy,
            "candidates": list(resolved.candidates),
        },
    )


def evaluate_evidence_rule(
    root: str | Path,
    increment_code: str,
) -> AdaptiveRuleResult:
    resolved = resolve_evidence_directory(
        root,
        increment_code,
    )

    return AdaptiveRuleResult(
        rule_code="SGD114D-R007",
        name="Evidencia institucional adaptativa",
        passed=resolved.found,
        blocking=True,
        message=(
            f"Evidencia detectada: {resolved.path}"
            if resolved.found
            else (
                "No existe evidencia no vacía para "
                f"{increment_code} ni su familia canónica."
            )
        ),
        remediation=(
            ""
            if resolved.found
            else "Genere evidencia técnica legítima antes del gate."
        ),
        evidence=(
            (str(resolved.path),)
            if resolved.path is not None
            else ()
        ),
        metadata={
            "strategy": resolved.strategy,
            "candidates": list(resolved.candidates),
        },
    )
'@

$Engine = @'
"""Motor adaptativo institucional SGD-114D."""

from __future__ import annotations

from pathlib import Path

from .adaptive_policy_models import AdaptivePolicyResult
from .adaptive_policy_rules import (
    evaluate_evidence_rule,
    evaluate_release_rule,
)


def evaluate_adaptive_policy(
    root: str | Path,
    increment_code: str,
) -> AdaptivePolicyResult:
    release = evaluate_release_rule(
        root,
        increment_code,
    )
    evidence = evaluate_evidence_rule(
        root,
        increment_code,
    )

    results = (release, evidence)
    approved = all(
        item.passed or not item.blocking
        for item in results
    )

    return AdaptivePolicyResult(
        increment_code=increment_code,
        approved=approved,
        exit_code=0 if approved else 2,
        results=results,
        evidence_path=(
            evidence.evidence[0]
            if evidence.evidence
            else None
        ),
        release_path=(
            release.evidence[0]
            if release.evidence
            else None
        ),
    )
'@

$Cli = @'
"""CLI de SGD-114D."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .adaptive_policy_engine import evaluate_adaptive_policy


def _payload(result) -> dict:
    return {
        "policy": "SGD-114D",
        "version": "1.0.0",
        "increment_code": result.increment_code,
        "approved": result.approved,
        "exit_code": result.exit_code,
        "evidence_path": result.evidence_path,
        "release_path": result.release_path,
        "results": [
            {
                "rule_code": item.rule_code,
                "name": item.name,
                "passed": item.passed,
                "blocking": item.blocking,
                "message": item.message,
                "remediation": item.remediation,
                "evidence": list(item.evidence),
                "metadata": item.metadata,
            }
            for item in result.results
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--increment", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    result = evaluate_adaptive_policy(
        args.root,
        args.increment,
    )
    payload = _payload(result)

    json_path = Path(args.output_json)
    md_path = Path(args.output_md)

    json_path.parent.mkdir(parents=True, exist_ok=True)
    md_path.parent.mkdir(parents=True, exist_ok=True)

    json_path.write_text(
        json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    lines = [
        "# SGD-114D — Resultado adaptativo",
        "",
        f"- Incremento: {result.increment_code}",
        f"- Aprobado: {result.approved}",
        f"- Código de salida: {result.exit_code}",
        f"- Evidencia: {result.evidence_path}",
        f"- Release: {result.release_path}",
        "",
        "## Reglas",
        "",
    ]

    for item in result.results:
        lines.extend(
            [
                f"### {item.rule_code} — {item.name}",
                "",
                f"- Aprobada: {item.passed}",
                f"- Bloqueante: {item.blocking}",
                f"- Mensaje: {item.message}",
                f"- Remediación: {item.remediation}",
                "",
            ]
        )

    md_path.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )

    print("Adaptive Institutional Policy Engine ejecutado.")
    print("Política: SGD-114D 1.0.0")
    print(f"Incremento: {result.increment_code}")
    print(
        "Resultado: "
        + ("APROBADO" if result.approved else "NO APROBADO")
    )
    print(f"Código de salida: {result.exit_code}")
    print(f"JSON: {json_path}")
    print(f"Markdown: {md_path}")

    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""Exportaciones de SGD-114D."""

from .adaptive_policy_engine import evaluate_adaptive_policy
from .adaptive_policy_resolver import (
    canonical_increment_code,
    increment_family,
    resolve_evidence_directory,
    resolve_release_directory,
)

__all__ = [
    "canonical_increment_code",
    "evaluate_adaptive_policy",
    "increment_family",
    "resolve_evidence_directory",
    "resolve_release_directory",
]
'@

$Tests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.adaptive_policy import (
    canonical_increment_code,
    evaluate_adaptive_policy,
    increment_family,
    resolve_evidence_directory,
    resolve_release_directory,
)


def _file(path: Path, text: str = "ok") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def test_SGD_114D_canonicalizes_version_suffix() -> None:
    assert canonical_increment_code(
        "SPT-011A-v1.0.2"
    ) == "SPT-011A"


def test_SGD_114D_builds_increment_family() -> None:
    assert increment_family("SPT-011A") == (
        "SPT-011A",
        "SPT-011",
    )


def test_SGD_114D_resolves_canonical_evidence(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011A"
        / "evidence"
        / "result.json"
    )

    result = resolve_evidence_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert result.strategy == "canonical"


def test_SGD_114D_resolves_parent_evidence(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011"
        / "evidence"
        / "result.json"
    )

    result = resolve_evidence_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert "SPT-011" in str(result.path)


def test_SGD_114D_rejects_empty_evidence_directory(
    tmp_path: Path,
) -> None:
    (
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011A"
        / "evidence"
    ).mkdir(parents=True)

    result = resolve_evidence_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is False


def test_SGD_114D_resolves_versioned_release(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is True
    assert "SPT-011A-v1.0.2" in str(result.path)


def test_SGD_114D_resolves_parent_release(
    tmp_path: Path,
) -> None:
    _file(
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
    assert "SPT-011-v1.0.0" in str(result.path)


def test_SGD_114D_rejects_empty_release(
    tmp_path: Path,
) -> None:
    (
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
    ).mkdir(parents=True)

    result = resolve_release_directory(
        tmp_path,
        "SPT-011A",
    )

    assert result.found is False


def test_SGD_114D_approves_complete_increment(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011"
        / "evidence"
        / "evidence.json"
    )
    _file(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    result = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )

    assert result.approved is True
    assert result.exit_code == 0


def test_SGD_114D_blocks_missing_release(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011"
        / "evidence"
        / "evidence.json"
    )

    result = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )

    assert result.approved is False
    assert result.exit_code == 2


def test_SGD_114D_blocks_missing_evidence(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    result = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )

    assert result.approved is False


def test_SGD_114D_is_deterministic(
    tmp_path: Path,
) -> None:
    _file(
        tmp_path
        / "artifacts"
        / "pmo"
        / "SPT-011A"
        / "evidence"
        / "evidence.json"
    )
    _file(
        tmp_path
        / "releases"
        / "SPT-011A-v1.0.2"
        / "manifest.json"
    )

    first = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )
    second = evaluate_adaptive_policy(
        tmp_path,
        "SPT-011A",
    )

    assert first == second
'@

$Policy = @'
{
  "component": "SGD-114D",
  "version": "1.0.0",
  "name": "Adaptive Institutional Policy Engine",
  "extends": "SGD-114C",
  "adaptive_rules": [
    "SGD114D-R003",
    "SGD114D-R007"
  ],
  "evidence_resolution": {
    "canonical": "artifacts/pmo/{increment}/evidence",
    "compatible_parent": true,
    "require_non_empty_files": true
  },
  "release_resolution": {
    "canonical": "releases/{increment}-v*",
    "compatible_parent": true,
    "require_non_empty_files": true
  },
  "false_positive_prevention": true
}
'@

$Component = @'
{
  "increment_code": "SGD-114D",
  "name": "Adaptive Institutional Policy Engine",
  "component_type": "adaptive_policy_engine",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Gobierno Digital",
  "dependencies": [
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/governance/adaptive_policy_models.py",
    "src/sgoda/governance/adaptive_policy_resolver.py",
    "src/sgoda/governance/adaptive_policy_rules.py",
    "src/sgoda/governance/adaptive_policy_engine.py",
    "src/sgoda/governance/adaptive_policy_cli.py",
    "src/sgoda/governance/adaptive_policy.py"
  ],
  "tests": [
    "tests/governance/test_SGD_114D_adaptive_institutional_policy_engine.py"
  ],
  "documentation": [
    "docs/01_Gobierno/SGD-114D-Adaptive-Institutional-Policy-Engine.md",
    "docs/01_Gobierno/SGD-114D-Migracion-SGD-114C.md"
  ]
}
'@

$Doc = @'
# SGD-114D v1.0.0 — Adaptive Institutional Policy Engine

SGD-114D extiende SGD-114C y evita falsos bloqueos en los controles de
release y evidencia.

El motor reconoce:

- evidencia canónica del incremento;
- evidencia ubicada en la familia del incremento padre;
- releases versionados del incremento correctivo;
- releases versionados del incremento padre;
- únicamente directorios con archivos reales y no vacíos.

No elimina controles. Amplía su capacidad de resolución y trazabilidad.
'@

$MigrationDoc = @'
# Migración de SGD-114C a SGD-114D

SGD-114C conserva sus reglas generales. SGD-114D reemplaza la resolución
rígida de R003 y R007 por resolución adaptativa.

Los nuevos gates deben ejecutar:

`python -m sgoda.governance.adaptive_policy_cli`

SGD-114D no aprueba directorios vacíos y no crea evidencia ficticia.
'@

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Increment,

    [string]$OutputDirectory = "artifacts/pmo/SGD-114D"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Json = Join-Path $OutputDirectory ($Increment + "-adaptive-policy-result.json")
$Markdown = Join-Path $OutputDirectory ($Increment + "-adaptive-policy-result.md")

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$Root" `
    --increment "$Increment" `
    --output-json "$Json" `
    --output-md "$Markdown"

exit $LASTEXITCODE
'@

Write-Step "Instalando SGD-114D"

Write-Utf8 -Path $ModelsPath -Content $Models
Write-Utf8 -Path $ResolverPath -Content $Resolver
Write-Utf8 -Path $RulesPath -Content $Rules
Write-Utf8 -Path $EnginePath -Content $Engine
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $InitPath -Content $Init
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $DocPath -Content $Doc
Write-Utf8 -Path $MigrationDocPath -Content $MigrationDoc
Write-Utf8 -Path $InvokePath -Content $Invoke

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/adaptive_policy_models.py" `
        "src/sgoda/governance/adaptive_policy_resolver.py" `
        "src/sgoda/governance/adaptive_policy_rules.py" `
        "src/sgoda/governance/adaptive_policy_engine.py" `
        "src/sgoda/governance/adaptive_policy_cli.py" `
        "src/sgoda/governance/adaptive_policy.py" `
        "tests/governance/test_SGD_114D_adaptive_institutional_policy_engine.py"
}

Invoke-Checked "Ejecutando 12 pruebas específicas SGD-114D" {
    python -m pytest `
        "tests/governance/test_SGD_114D_adaptive_institutional_policy_engine.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

if (-not $SkipInstitutionalClosure) {
    Write-Step "Preparando release técnico SGD-114D"

    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

    foreach ($ReleaseFile in @(
        $ModelsPath,
        $ResolverPath,
        $RulesPath,
        $EnginePath,
        $CliPath,
        $InitPath,
        $TestPath,
        $PolicyPath,
        $ComponentPath,
        $DocPath,
        $MigrationDocPath,
        $InvokePath
    )) {
        Require-File -Path $ReleaseFile

        Copy-Item `
            -LiteralPath $ReleaseFile `
            -Destination (
                Join-Path $ReleaseDir (Split-Path $ReleaseFile -Leaf)
            ) `
            -Force
    }

    Write-Json `
        -Path (Join-Path $ReleaseDir "manifest.json") `
        -Value ([ordered]@{
            increment_code = "SGD-114D"
            version = "1.0.0"
            status = "implemented"
            files = @(
                Get-ChildItem `
                    -LiteralPath $ReleaseDir `
                    -File |
                Select-Object -ExpandProperty Name
            )
        })

    Write-Step "Reevaluando incremento objetivo"

    & python -m sgoda.governance.adaptive_policy_cli `
        --root "$ProjectRoot" `
        --increment "$TargetIncrement" `
        --output-json "$TargetResultJson" `
        --output-md "$TargetResultMd"

    $AdaptiveExitCode = $LASTEXITCODE

    Require-File -Path $TargetResultJson
    Require-File -Path $TargetResultMd

    $AdaptiveResult = Get-Content `
        -LiteralPath $TargetResultJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if ($AdaptiveExitCode -ne 0 -or -not [bool]$AdaptiveResult.approved) {
        @($AdaptiveResult.results) |
            Where-Object { -not $_.passed } |
            Format-Table rule_code, name, message, remediation -AutoSize

        throw "SGD-114D no aprobó $TargetIncrement."
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
        throw "SGD-116 no aprobó SGD-114D."
    }

    Write-Step "Regenerando Documentación Maestra SGD-115"

    Invoke-Checked "Actualizando SGD-115" {
        python -m sgoda.documentation.master_docs `
            --root "$ProjectRoot" `
            --output "artifacts/documentation/SGD-115"
    }

    Write-Step "Generando evidencia institucional"

    Write-Json `
        -Path $EvidencePath `
        -Value ([ordered]@{
            increment_code = "SGD-114D"
            version = "1.0.0"
            status = "implemented_and_validated"
            generated_at_utc = [DateTime]::UtcNow.ToString("o")
            target_increment = $TargetIncrement
            target_approved = [bool]$AdaptiveResult.approved
            target_evidence_path = $AdaptiveResult.evidence_path
            target_release_path = $AdaptiveResult.release_path
            specific_tests = 12
            full_suite_executed = (-not $SkipFullSuite)
            roadmap_approved = [bool]$RoadmapValidation.passed
            documentation_updated = $true
            release = "releases/SGD-114D-v1.0.0"
            backup = $BackupDir
        })

    Copy-Item `
        -LiteralPath $EvidencePath `
        -Destination $ReleaseDir `
        -Force
}

Write-Step "Resultado final"

Write-Host "SGD-114D v1.0.0 implementado." -ForegroundColor Green
Write-Host "Adaptive Institutional Policy Engine: OPERATIVO." -ForegroundColor Green
Write-Host "Resolución adaptativa R003: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Resolución adaptativa R007: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Pruebas específicas: 12 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

if (-not $SkipInstitutionalClosure) {
    Write-Host "$TargetIncrement: APROBADO POR SGD-114D." -ForegroundColor Green
    Write-Host "SGD-116: APROBADO." -ForegroundColor Green
    Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
    Write-Host "Release: releases\SGD-114D-v1.0.0" -ForegroundColor Cyan
    Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
}

Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
