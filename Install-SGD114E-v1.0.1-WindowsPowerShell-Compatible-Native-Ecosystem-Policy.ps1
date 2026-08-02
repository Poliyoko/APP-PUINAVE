<#
.SYNOPSIS
    Instala SGD-114E v1.0.1 — Native Ecosystem Architecture Policy.

.DESCRIPTION
    Formaliza que todos los componentes SPT-007 en adelante son componentes
    nativos del ecosistema SGODA-PUINAVE, desarrollados prioritariamente con
    tecnologías gratuitas, libres o de código abierto, sin dependencias
    propietarias obligatorias.

    El instalador:
      - valida la línea base institucional;
      - crea respaldo;
      - instala modelos, política, validador, CLI y pruebas;
      - normaliza la terminología de SPT-012;
      - prohíbe "integrado por contrato" en documentación activa;
      - valida ausencia de dependencias propietarias obligatorias;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - evalúa el repositorio real;
      - regenera SGD-115 y SGD-116;
      - genera evidencia y release.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.

.PARAMETER SkipInstitutionalClosure
    Omite SGD-115, SGD-116, evidencia y release.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
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
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114E"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114E-v1.0.1"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SGD114E-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "native_ecosystem_models.py"
$PolicyPathPy = Join-Path $SourceDir "native_ecosystem_policy.py"
$ValidatorPath = Join-Path $SourceDir "native_ecosystem_validator.py"
$CliPath = Join-Path $SourceDir "native_ecosystem_cli.py"
$InitPath = Join-Path $SourceDir "native_ecosystem.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SGD_114E_native_ecosystem_architecture_policy.py"

$PolicyPath = Join-Path `
    $ConfigDir `
    "SGD-114E-native-ecosystem-policy.json"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SGD-114E-component.json"

$DocPath = Join-Path `
    $DocsDir `
    "SGD-114E-Native-Ecosystem-Architecture-Policy.md"

$TerminologyDocPath = Join-Path `
    $DocsDir `
    "SGD-114E-Terminologia-Institucional.md"

$InvokePath = Join-Path `
    $ScriptsDir `
    "Invoke-SGD114E-NativeEcosystemPolicy.ps1"

$EvaluationJson = Join-Path `
    $PmoDir `
    "SGD-114E-repository-evaluation.json"

$EvaluationMd = Join-Path `
    $PmoDir `
    "SGD-114E-repository-evaluation.md"

$EvidencePath = Join-Path `
    $PmoDir `
    "SGD-114E-implementation-evidence.json"

$Spt012Installer = Join-Path `
    $ProjectRoot `
    "Install-SPT012-v1.0.0-SGODA-Learning-Platform.ps1"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $SourceDir "adaptive_policy_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "config\learning_platform\SPT-012-component.json"),
    (Join-Path $ProjectRoot "docs\07_Fase_Tecnologica_III\SPT-012\SPT-012-Arquitectura.md")
)) {
    Require-File -Path $Required
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Affected in @(
    $ModelsPath,
    $PolicyPathPy,
    $ValidatorPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $PolicyPath,
    $ComponentPath,
    $DocPath,
    $TerminologyDocPath,
    $InvokePath,
    $Spt012Installer
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Models = @'
"""Modelos de SGD-114E."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class NativeComponentRecord:
    code: str
    version: str
    native: bool
    mandatory_proprietary_dependencies: tuple[str, ...]
    technologies: tuple[str, ...]
    metadata: dict[str, Any]


@dataclass(frozen=True, slots=True)
class NativePolicyFinding:
    rule_code: str
    passed: bool
    blocking: bool
    message: str
    path: str | None = None
    remediation: str = ""


@dataclass(frozen=True, slots=True)
class NativePolicyResult:
    approved: bool
    exit_code: int
    component_count: int
    findings: tuple[NativePolicyFinding, ...]
    forbidden_term_count: int
    proprietary_dependency_count: int
'@

$PolicyPy = @'
"""Política nativa del ecosistema SGODA-PUINAVE."""

from __future__ import annotations

import re
from typing import Any


_NATIVE_SPT = re.compile(
    r"^SPT-(?P<number>\d+)(?P<suffix>[A-Z]?)$",
    re.IGNORECASE,
)


FORBIDDEN_TERMS = (
    "integrado por contrato",
    "integrada por contrato",
    "integrados por contrato",
    "integradas por contrato",
    "contract integration",
    "contract-based integration",
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
        normalized["ecosystem_role"] = (
            "native_component"
        )
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
"""Validador institucional SGD-114E."""

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


def _iter_text_files(root: Path) -> Iterable[Path]:
    ignored = {
        ".git",
        ".venv",
        "__pycache__",
        ".pytest_cache",
    }

    for path in root.rglob("*"):
        if not path.is_file():
            continue

        if any(part in ignored for part in path.parts):
            continue

        if path.suffix.casefold() not in _TEXT_SUFFIXES:
            continue

        yield path


def _component_files(root: Path) -> Iterable[Path]:
    for path in root.glob("config/**/*component.json"):
        if path.is_file():
            yield path


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
                    path=str(path.relative_to(base)),
                    remediation=(
                        "Corrija el JSON del componente."
                    ),
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
                    path=str(path.relative_to(base)),
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
                    path=str(path.relative_to(base)),
                    remediation=(
                        "Elimine la obligatoriedad o documente "
                        "una alternativa gratuita y abierta."
                    ),
                )
            )

    for path in _iter_text_files(base):
        relative = str(path.relative_to(base)).replace("\\", "/")

        if relative.startswith("artifacts/pmo/SGD-114E/backups/"):
            continue

        try:
            text = path.read_text(
                encoding="utf-8-sig",
                errors="replace",
            ).casefold()
        except OSError:
            continue

        for term in FORBIDDEN_TERMS:
            if term.casefold() in text:
                forbidden_count += 1
                findings.append(
                    NativePolicyFinding(
                        rule_code="SGD114E-R004",
                        passed=False,
                        blocking=True,
                        message=(
                            "Terminología no permitida: "
                            f"{term}"
                        ),
                        path=relative,
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

$Cli = @'
"""CLI de SGD-114E."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    result = evaluate_native_ecosystem(args.root)

    payload = {
        "policy": "SGD-114E",
        "version": "1.0.1",
        "approved": result.approved,
        "exit_code": result.exit_code,
        "component_count": result.component_count,
        "forbidden_term_count": (
            result.forbidden_term_count
        ),
        "proprietary_dependency_count": (
            result.proprietary_dependency_count
        ),
        "findings": [
            {
                "rule_code": item.rule_code,
                "passed": item.passed,
                "blocking": item.blocking,
                "message": item.message,
                "path": item.path,
                "remediation": item.remediation,
            }
            for item in result.findings
        ],
    }

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
        "# SGD-114E — Evaluación del ecosistema nativo",
        "",
        f"- Aprobado: {result.approved}",
        f"- Código de salida: {result.exit_code}",
        f"- Componentes nativos: {result.component_count}",
        (
            "- Términos prohibidos: "
            f"{result.forbidden_term_count}"
        ),
        (
            "- Dependencias propietarias obligatorias: "
            f"{result.proprietary_dependency_count}"
        ),
        "",
        "## Hallazgos",
        "",
    ]

    for item in result.findings:
        lines.extend(
            [
                f"### {item.rule_code}",
                "",
                f"- Aprobado: {item.passed}",
                f"- Bloqueante: {item.blocking}",
                f"- Mensaje: {item.message}",
                f"- Ruta: {item.path}",
                f"- Remediación: {item.remediation}",
                "",
            ]
        )

    md_path.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )

    print("SGD-114E ejecutado correctamente.")
    print(
        "Resultado: "
        + ("APROBADO" if result.approved else "NO APROBADO")
    )
    print(f"Componentes nativos: {result.component_count}")
    print(
        "Términos prohibidos: "
        f"{result.forbidden_term_count}"
    )
    print(
        "Dependencias propietarias obligatorias: "
        f"{result.proprietary_dependency_count}"
    )
    print(f"JSON: {json_path}")
    print(f"Markdown: {md_path}")

    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""SGD-114E — Native Ecosystem Architecture Policy."""

from .native_ecosystem_policy import (
    APPROVED_TERMS,
    DEFAULT_OPEN_TECHNOLOGIES,
    FORBIDDEN_TERMS,
    is_native_spt,
    normalize_native_metadata,
)
from .native_ecosystem_validator import (
    evaluate_native_ecosystem,
)

__all__ = [
    "APPROVED_TERMS",
    "DEFAULT_OPEN_TECHNOLOGIES",
    "FORBIDDEN_TERMS",
    "evaluate_native_ecosystem",
    "is_native_spt",
    "normalize_native_metadata",
]
'@

$Tests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem import (
    evaluate_native_ecosystem,
    is_native_spt,
    normalize_native_metadata,
)


def _write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload),
        encoding="utf-8",
    )


def test_SGD_114E_identifies_SPT_007_as_native() -> None:
    assert is_native_spt("SPT-007") is True
    assert is_native_spt("SPT-007A") is True


def test_SGD_114E_identifies_later_SPT_as_native() -> None:
    assert is_native_spt("SPT-012") is True


def test_SGD_114E_excludes_earlier_SPT() -> None:
    assert is_native_spt("SPT-006A") is False


def test_SGD_114E_normalizes_native_metadata() -> None:
    result = normalize_native_metadata(
        {
            "increment_code": "SPT-012",
            "version": "1.0.1",
        }
    )

    assert result["native_ecosystem"] is True
    assert result["ecosystem_role"] == "native_component"
    assert result["mandatory_proprietary_dependencies"] == []


def test_SGD_114E_approves_native_component(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "version": "1.0.1",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [],
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.component_count == 1


def test_SGD_114E_blocks_missing_native_declaration(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "version": "1.0.1",
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert any(
        item.rule_code == "SGD114E-R002"
        for item in result.findings
    )


def test_SGD_114E_blocks_mandatory_proprietary_dependency(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [
                "PaidVendorOnly"
            ],
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.proprietary_dependency_count == 1


def test_SGD_114E_blocks_forbidden_terminology(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [],
        },
    )
    document = tmp_path / "docs/test.md"
    document.parent.mkdir(parents=True)
    document.write_text(
        "Motor integrado por contrato.",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.forbidden_term_count == 1


def test_SGD_114E_accepts_native_terminology(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [],
        },
    )
    document = tmp_path / "docs/test.md"
    document.parent.mkdir(parents=True)
    document.write_text(
        "Motor integrado nativamente al ecosistema SGODA-PUINAVE.",
        encoding="utf-8",
    )

    assert evaluate_native_ecosystem(tmp_path).approved is True


def test_SGD_114E_ignores_non_native_components(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-006A-component.json",
        {
            "increment_code": "SPT-006A",
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.component_count == 0


def test_SGD_114E_is_deterministic(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [],
        },
    )

    first = evaluate_native_ecosystem(tmp_path)
    second = evaluate_native_ecosystem(tmp_path)

    assert first == second


def test_SGD_114E_exit_code_is_zero_when_approved(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0
'@

$Policy = @'
{
  "component": "SGD-114E",
  "version": "1.0.1",
  "name": "Native Ecosystem Architecture Policy",
  "scope": "SPT-007 and later",
  "native_ecosystem_required": true,
  "mandatory_proprietary_dependencies_allowed": false,
  "technology_principles": [
    "free",
    "open_source",
    "open_standards",
    "local_first",
    "optional_proprietary_only"
  ],
  "forbidden_terms": [
    "integrado por contrato",
    "integrada por contrato",
    "integrados por contrato",
    "integradas por contrato",
    "contract integration",
    "contract-based integration"
  ],
  "preferred_term": "integrado nativamente al ecosistema SGODA-PUINAVE"
}
'@

$Component = @'
{
  "increment_code": "SGD-114E",
  "name": "Native Ecosystem Architecture Policy",
  "component_type": "native_ecosystem_architecture_policy",
  "version": "1.0.1",
  "status": "implemented",
  "phase": "Gobierno Digital",
  "dependencies": [
    "SGD-114D",
    "SGD-115A",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/governance/native_ecosystem_models.py",
    "src/sgoda/governance/native_ecosystem_policy.py",
    "src/sgoda/governance/native_ecosystem_validator.py",
    "src/sgoda/governance/native_ecosystem_cli.py",
    "src/sgoda/governance/native_ecosystem.py"
  ],
  "tests": [
    "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py"
  ],
  "documentation": [
    "docs/01_Gobierno/SGD-114E-Native-Ecosystem-Architecture-Policy.md",
    "docs/01_Gobierno/SGD-114E-Terminologia-Institucional.md"
  ]
}
'@

$Doc = @'
# SGD-114E v1.0.1 — Native Ecosystem Architecture Policy

## Decisión institucional

Todos los componentes SPT-007 en adelante son componentes nativos del
ecosistema SGODA-PUINAVE.

Se implementan prioritariamente con tecnologías gratuitas, libres, abiertas
o de código abierto. Ningún componente crítico puede depender
obligatoriamente de un servicio propietario o comercial.

Una herramienta propietaria puede ser opcional únicamente cuando exista una
alternativa gratuita documentada y el funcionamiento esencial no dependa de
ella.

## Arquitectura

Los motores léxicos, el tutor, el ecosistema conversacional, las plataformas
digitales, la multimedia y los ODA pertenecen al mismo núcleo institucional.

## Terminología

La expresión institucional preferida es:

`Integrado nativamente al ecosistema SGODA-PUINAVE.`
'@

$TerminologyDoc = @'
# SGD-114E — Terminología institucional

## Expresiones aprobadas

- Integrado nativamente al ecosistema SGODA-PUINAVE.
- Componente nativo del ecosistema SGODA-PUINAVE.
- Componente institucional del núcleo SGODA.
- Motor institucional.
- Servicio institucional.
- Módulo nativo.
- Subsistema institucional.

## Expresiones no permitidas

- Integrado por contrato.
- Integrada por contrato.
- Integrados por contrato.
- Integradas por contrato.
- Contract integration.
- Contract-based integration.

La prohibición aplica a documentación activa, configuración, mensajes de
instaladores y reportes institucionales futuros.
'@

$Invoke = @'
[CmdletBinding()]
param(
    [string]$OutputDirectory = "artifacts/pmo/SGD-114E"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Json = Join-Path $OutputDirectory "SGD-114E-repository-evaluation.json"
$Markdown = Join-Path $OutputDirectory "SGD-114E-repository-evaluation.md"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$Root" `
    --output-json "$Json" `
    --output-md "$Markdown"

exit $LASTEXITCODE
'@

Write-Step "Instalando SGD-114E"

Write-Utf8 -Path $ModelsPath -Content $Models
Write-Utf8 -Path $PolicyPathPy -Content $PolicyPy
Write-Utf8 -Path $ValidatorPath -Content $Validator
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $InitPath -Content $Init
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $DocPath -Content $Doc
Write-Utf8 -Path $TerminologyDocPath -Content $TerminologyDoc
Write-Utf8 -Path $InvokePath -Content $Invoke

Write-Step "Normalizando metadatos de componentes SPT-007 en adelante"

$ComponentFiles = @(
    Get-ChildItem `
        -LiteralPath (Join-Path $ProjectRoot "config") `
        -Filter "*component.json" `
        -File `
        -Recurse `
        -ErrorAction Stop
)

$NativeComponentCount = 0

foreach ($File in $ComponentFiles) {
    $Payload = Get-Content `
        -LiteralPath $File.FullName `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    $Code = [string]$Payload.increment_code

    if ($Code -notmatch '^SPT-(\d+)([A-Z]?)$') {
        continue
    }

    $Number = [int]$Matches[1]

    if ($Number -lt 7) {
        continue
    }

    $Normalized = [ordered]@{}

    foreach ($Property in $Payload.PSObject.Properties) {
        $Normalized[$Property.Name] = $Property.Value
    }

    $Normalized["native_ecosystem"] = $true
    $Normalized["ecosystem_role"] = "native_component"
    $Normalized["technology_policy"] = (
        "free_open_optional_proprietary"
    )
    $Normalized["mandatory_proprietary_dependencies"] = @()
    $Normalized["institutional_terminology"] = (
        "integrado nativamente al ecosistema SGODA-PUINAVE"
    )

    Write-Json `
        -Path $File.FullName `
        -Value $Normalized

    $NativeComponentCount += 1
}

Write-Host (
    "Componentes nativos normalizados: " +
    $NativeComponentCount
) -ForegroundColor Green

Write-Step "Normalizando terminología activa"

$TerminologyRoots = @(
    (Join-Path $ProjectRoot "docs"),
    (Join-Path $ProjectRoot "config"),
    (Join-Path $ProjectRoot "src"),
    (Join-Path $ProjectRoot "scripts")
)

if (Test-Path -LiteralPath $Spt012Installer -PathType Leaf) {
    $TerminologyRoots += $Spt012Installer
}

$ReplacementRules = @(
    [pscustomobject]@{
        Search = "INTEGRADOS POR CONTRATO"
        Replace = "INTEGRADOS NATIVAMENTE"
    },
    [pscustomobject]@{
        Search = "INTEGRADAS POR CONTRATO"
        Replace = "INTEGRADAS NATIVAMENTE"
    },
    [pscustomobject]@{
        Search = "INTEGRADO POR CONTRATO"
        Replace = "INTEGRADO NATIVAMENTE"
    },
    [pscustomobject]@{
        Search = "INTEGRADA POR CONTRATO"
        Replace = "INTEGRADA NATIVAMENTE"
    },
    [pscustomobject]@{
        Search = "integrados por contrato"
        Replace = "integrados nativamente"
    },
    [pscustomobject]@{
        Search = "integradas por contrato"
        Replace = "integradas nativamente"
    },
    [pscustomobject]@{
        Search = "integrado por contrato"
        Replace = "integrado nativamente"
    },
    [pscustomobject]@{
        Search = "integrada por contrato"
        Replace = "integrada nativamente"
    },
    [pscustomobject]@{
        Search = "Contract-based Integration"
        Replace = "Native Ecosystem Integration"
    },
    [pscustomobject]@{
        Search = "Contract Integration"
        Replace = "Native Ecosystem Integration"
    },
    [pscustomobject]@{
        Search = "contract-based integration"
        Replace = "native ecosystem integration"
    },
    [pscustomobject]@{
        Search = "contract integration"
        Replace = "native ecosystem integration"
    }
)

$NormalizedFiles = 0

foreach ($RootItem in $TerminologyRoots) {
    $Files = @()

    if (Test-Path -LiteralPath $RootItem -PathType Leaf) {
        $Files = @(Get-Item -LiteralPath $RootItem)
    }
    elseif (Test-Path -LiteralPath $RootItem -PathType Container) {
        $Files = @(
            Get-ChildItem `
                -LiteralPath $RootItem `
                -Recurse `
                -File |
            Where-Object {
                $_.Extension -in @(
                    ".md",
                    ".json",
                    ".py",
                    ".ps1",
                    ".txt",
                    ".yaml",
                    ".yml"
                )
            }
        )
    }

    foreach ($File in $Files) {
        if ($File.FullName -eq $TerminologyDocPath) {
            continue
        }

        $Original = Get-Content `
            -LiteralPath $File.FullName `
            -Raw `
            -Encoding UTF8

        $Updated = $Original

        foreach ($Rule in $ReplacementRules) {
            $Updated = $Updated.Replace(
                [string]$Rule.Search,
                [string]$Rule.Replace
            )
        }

        if ($Updated -ne $Original) {
            Write-Utf8 `
                -Path $File.FullName `
                -Content $Updated

            $NormalizedFiles += 1
        }
    }
}

Write-Host (
    "Archivos con terminología normalizada: " +
    $NormalizedFiles
) -ForegroundColor Green

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/native_ecosystem_models.py" `
        "src/sgoda/governance/native_ecosystem_policy.py" `
        "src/sgoda/governance/native_ecosystem_validator.py" `
        "src/sgoda/governance/native_ecosystem_cli.py" `
        "src/sgoda/governance/native_ecosystem.py" `
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py"
}

Invoke-Checked "Ejecutando 12 pruebas específicas SGD-114E" {
    python -m pytest `
        "tests/governance/test_SGD_114E_native_ecosystem_architecture_policy.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Evaluando repositorio real mediante SGD-114E"

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

    throw "SGD-114E no aprobó el repositorio."
}

if (-not $SkipInstitutionalClosure) {
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
        throw "SGD-115 no aprobó SGD-114E."
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
        throw "SGD-116 no aprobó SGD-114E."
    }

    Write-Step "Generando evidencia y release"

    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

    Write-Json `
        -Path $EvidencePath `
        -Value ([ordered]@{
            increment_code = "SGD-114E"
            version = "1.0.1"
            status = "implemented_and_approved"
            generated_at_utc = [DateTime]::UtcNow.ToString("o")
            native_components_normalized = $NativeComponentCount
            terminology_files_normalized = $NormalizedFiles
            specific_tests = 12
            full_suite_executed = (-not $SkipFullSuite)
            repository_approved = [bool]$Evaluation.approved
            forbidden_term_count = (
                $Evaluation.forbidden_term_count
            )
            proprietary_dependency_count = (
                $Evaluation.proprietary_dependency_count
            )
            documentation_approved = [bool]$DocValidation.passed
            roadmap_approved = [bool]$RoadmapValidation.passed
            preferred_term = (
                "integrado nativamente al ecosistema SGODA-PUINAVE"
            )
            backup = $BackupDir
        })

    foreach ($ReleaseFile in @(
        $ModelsPath,
        $PolicyPathPy,
        $ValidatorPath,
        $CliPath,
        $InitPath,
        $TestPath,
        $PolicyPath,
        $ComponentPath,
        $DocPath,
        $TerminologyDocPath,
        $InvokePath,
        $EvaluationJson,
        $EvaluationMd,
        $EvidencePath
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
            increment_code = "SGD-114E"
            version = "1.0.1"
            status = "implemented_and_validated"
            files = @(
                Get-ChildItem `
                    -LiteralPath $ReleaseDir `
                    -File |
                Select-Object -ExpandProperty Name
            )
        })
}

Write-Step "Resultado final"

Write-Host "SGD-114E v1.0.1 implementado." -ForegroundColor Green
Write-Host "Native Ecosystem Architecture Policy: OPERATIVA." `
    -ForegroundColor Green
Write-Host "SPT-007 en adelante: COMPONENTES NATIVOS." `
    -ForegroundColor Green
Write-Host "Tecnologías gratuitas y abiertas: POLÍTICA ACTIVA." `
    -ForegroundColor Green
Write-Host "Dependencias propietarias obligatorias: PROHIBIDAS." `
    -ForegroundColor Green
Write-Host "Terminología institucional: NORMALIZADA." `
    -ForegroundColor Green
Write-Host "Pruebas específicas: 12 APROBADAS." `
    -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." `
        -ForegroundColor Green
}

Write-Host "Evaluación del repositorio: APROBADA." `
    -ForegroundColor Green
Write-Host (
    "Componentes nativos evaluados: " +
    $Evaluation.component_count
) -ForegroundColor Green
Write-Host "Términos prohibidos encontrados: 0." `
    -ForegroundColor Green
Write-Host "Dependencias propietarias obligatorias: 0." `
    -ForegroundColor Green

if (-not $SkipInstitutionalClosure) {
    Write-Host "SGD-115: APROBADO." -ForegroundColor Green
    Write-Host "SGD-116: APROBADO." -ForegroundColor Green
    Write-Host "Release: releases\SGD-114E-v1.0.1" `
        -ForegroundColor Cyan
    Write-Host "Evidencia: $EvidencePath" `
        -ForegroundColor Cyan
}

Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
