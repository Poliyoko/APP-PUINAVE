<#
.SYNOPSIS
    Instala SGD-114C v1.0.0 — Policy Governance Core.

.DESCRIPTION
    Implementa un núcleo único y normalizado de gobernanza para el
    ecosistema SGODA-PUINAVE.

    Incluye:
      - modelos normalizados de reglas y resultados;
      - contexto institucional verificable;
      - registro de reglas;
      - ejecutor determinista;
      - reglas de repositorio, pruebas, Roadmap, documentación, release
        y trazabilidad;
      - compatibilidad con SGD-114 v1.1.0;
      - evaluación real de SGD-116B;
      - evidencia JSON y Markdown;
      - pruebas específicas;
      - suite completa;
      - actualización SGD-115;
      - release SGD-114C-v1.0.0.

    No aprueba reglas mediante excepciones ni crea evidencias falsas.
    Cada regla se decide a partir de archivos y resultados reales.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER Increment
    Incremento evaluado después de instalar el núcleo.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado para cierre institucional.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$Increment = "SGD-116B",
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
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
    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path ($($Info.Length) bytes)" `
        -ForegroundColor Green
}

function Write-Json {
    param([string]$Path, [object]$Value)

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Checked {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    Write-Step $Description
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$GovernanceDir = Join-Path $ProjectRoot "src\sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114C"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114C-v1.0.0"

$ModelsPath = Join-Path $GovernanceDir "policy_models.py"
$ContextPath = Join-Path $GovernanceDir "policy_context.py"
$RulesPath = Join-Path $GovernanceDir "policy_rules.py"
$RegistryPath = Join-Path $GovernanceDir "policy_registry.py"
$EnginePath = Join-Path $GovernanceDir "policy_engine.py"
$ReportPath = Join-Path $GovernanceDir "policy_report.py"
$CliPath = Join-Path $GovernanceDir "policy_cli.py"

$TestPath = Join-Path $TestsDir "test_SGD_114C_policy_governance_core.py"
$PolicyPath = Join-Path $ConfigDir "SGD-114C-policy.json"
$ComponentPath = Join-Path $ConfigDir "SGD-114C-component.json"
$DocPath = Join-Path $DocsDir "SGD-114C-Policy-Governance-Core.md"
$MigrationDocPath = Join-Path $DocsDir "SGD-114C-Migracion-SGD-114.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SGD114C-PolicyGovernance.ps1"

$GateJson = Join-Path $ArtifactsDir "$Increment-policy-result.json"
$GateMd = Join-Path $ArtifactsDir "$Increment-policy-result.md"
$EvidencePath = Join-Path $ArtifactsDir "SGD-114C-implementation-evidence.json"
$BackupDir = Join-Path $ArtifactsDir (
    "backups\pre-SGD114C-" +
    [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
)

Write-Step "Validando línea base técnica"

foreach ($Path in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File -Path $Path
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Path in @(
    $ModelsPath,
    $ContextPath,
    $RulesPath,
    $RegistryPath,
    $EnginePath,
    $ReportPath,
    $CliPath,
    $TestPath,
    $PolicyPath,
    $ComponentPath,
    $DocPath,
    $MigrationDocPath,
    $InvokePath
)) {
    if (Test-Path -LiteralPath $Path) {
        Copy-Item `
            -LiteralPath $Path `
            -Destination (Join-Path $BackupDir (Split-Path $Path -Leaf)) `
            -Force
    }
}

$Models = @'
"""Modelos normalizados del Policy Governance Core SGD-114C."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any


class Severity(str, Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    BLOCKER = "BLOCKER"


class RuleStatus(str, Enum):
    PASSED = "PASSED"
    FAILED = "FAILED"
    NOT_APPLICABLE = "NOT_APPLICABLE"


@dataclass(frozen=True, slots=True)
class PolicyRule:
    code: str
    name: str
    description: str
    severity: Severity
    category: str


@dataclass(frozen=True, slots=True)
class RuleResult:
    rule: PolicyRule
    status: RuleStatus
    message: str
    evidence: tuple[str, ...] = ()
    remediation: str = ""
    details: dict[str, Any] = field(default_factory=dict)

    @property
    def passed(self) -> bool:
        return self.status in {
            RuleStatus.PASSED,
            RuleStatus.NOT_APPLICABLE,
        }

    @property
    def blocking(self) -> bool:
        return (
            self.rule.severity == Severity.BLOCKER
            and self.status == RuleStatus.FAILED
        )


@dataclass(frozen=True, slots=True)
class PolicyEvaluation:
    policy_code: str
    policy_version: str
    increment: str
    approved: bool
    results: tuple[RuleResult, ...]
    generated_at_utc: str

    @property
    def blocking_rules(self) -> tuple[RuleResult, ...]:
        return tuple(item for item in self.results if item.blocking)

    @property
    def failed_rules(self) -> tuple[RuleResult, ...]:
        return tuple(
            item
            for item in self.results
            if item.status == RuleStatus.FAILED
        )

    @property
    def exit_code(self) -> int:
        return 0 if self.approved else 2
'@

$Context = @'
"""Contexto verificable para SGD-114C."""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class PolicyContext:
    root: Path
    increment: str
    policy: dict[str, Any]

    def exists(self, relative_path: str) -> bool:
        return (self.root / relative_path).exists()

    def is_file(self, relative_path: str) -> bool:
        return (self.root / relative_path).is_file()

    def is_dir(self, relative_path: str) -> bool:
        return (self.root / relative_path).is_dir()

    def read_json(self, relative_path: str) -> dict[str, Any]:
        path = self.root / relative_path
        return json.loads(path.read_text(encoding="utf-8-sig"))

    def git_status(self) -> list[str]:
        completed = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=self.root,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        return [
            line
            for line in completed.stdout.splitlines()
            if line.strip()
        ]

    def component_descriptors(self) -> list[Path]:
        return sorted(
            self.root.glob(
                f"config/**/*{self.increment}*component*.json"
            )
        )

    def releases(self) -> list[Path]:
        return sorted(
            (self.root / "releases").glob(
                f"{self.increment}-v*"
            )
        )

    def roadmap_validation(self) -> dict[str, Any] | None:
        path = (
            self.root
            / "artifacts"
            / "roadmap"
            / "SGD-116"
            / "validation.json"
        )
        if not path.is_file():
            return None
        return json.loads(path.read_text(encoding="utf-8-sig"))
'@

$Rules = @'
"""Reglas institucionales verificables de SGD-114C."""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path

from .policy_context import PolicyContext
from .policy_models import (
    PolicyRule,
    RuleResult,
    RuleStatus,
    Severity,
)


RuleExecutor = Callable[[PolicyContext, PolicyRule], RuleResult]


def _passed(
    rule: PolicyRule,
    message: str,
    *evidence: str,
) -> RuleResult:
    return RuleResult(
        rule=rule,
        status=RuleStatus.PASSED,
        message=message,
        evidence=tuple(evidence),
    )


def _failed(
    rule: PolicyRule,
    message: str,
    remediation: str,
    *evidence: str,
    details: dict | None = None,
) -> RuleResult:
    return RuleResult(
        rule=rule,
        status=RuleStatus.FAILED,
        message=message,
        evidence=tuple(evidence),
        remediation=remediation,
        details=details or {},
    )


def repository_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    if (context.root / ".git").is_dir():
        return _passed(rule, "Repositorio Git detectado.", ".git/")

    return _failed(
        rule,
        "No se detectó el repositorio Git.",
        "Ejecute el núcleo desde la raíz del repositorio.",
        ".git/",
    )


def component_descriptor_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    descriptors = context.component_descriptors()

    if descriptors:
        evidence = tuple(
            item.relative_to(context.root).as_posix()
            for item in descriptors
        )
        return _passed(
            rule,
            "Descriptor institucional encontrado.",
            *evidence,
        )

    return _failed(
        rule,
        f"No existe descriptor institucional para {context.increment}.",
        (
            "Cree un descriptor component.json con código, versión, "
            "dependencias, fuentes, pruebas y documentación."
        ),
        "config/",
    )


def release_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    releases = context.releases()

    if releases:
        evidence = tuple(
            item.relative_to(context.root).as_posix()
            for item in releases
        )
        return _passed(
            rule,
            "Release técnico versionado encontrado.",
            *evidence,
        )

    return _failed(
        rule,
        f"No existe release versionado para {context.increment}.",
        "Genere el release técnico antes del cierre.",
        "releases/",
    )


def roadmap_approved(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    validation = context.roadmap_validation()

    if validation is None:
        return _failed(
            rule,
            "No existe validation.json del Roadmap Maestro.",
            "Regenerate SGD-116 antes de solicitar el cierre.",
            "artifacts/roadmap/SGD-116/validation.json",
        )

    counters = {
        "missing_dependencies": len(
            validation.get("missing_dependencies", [])
        ),
        "broken_paths": len(validation.get("broken_paths", [])),
        "dependency_cycles": len(
            validation.get("dependency_cycles", [])
        ),
        "duplicate_codes": len(
            validation.get("duplicate_codes", [])
        ),
        "missing_master_documents": len(
            validation.get("missing_master_documents", [])
        ),
    }

    passed = bool(validation.get("passed")) and all(
        value == 0 for value in counters.values()
    )

    if passed:
        return _passed(
            rule,
            "Roadmap Maestro aprobado y sin errores estructurales.",
            "artifacts/roadmap/SGD-116/validation.json",
        )

    return _failed(
        rule,
        "El Roadmap Maestro contiene incumplimientos.",
        "Corrija los contadores y regenere el Roadmap.",
        "artifacts/roadmap/SGD-116/validation.json",
        details=counters,
    )


def master_documents_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    required = tuple(
        context.policy.get(
            "required_master_documents",
            (
                "docs/00_INDICE_MAESTRO.md",
                "docs/00_ARQUITECTURA_MAESTRA.md",
                "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
                "docs/00_ROADMAP_MAESTRO.md",
                "docs/00_DEPENDENCIAS_MAESTRAS.md",
                "docs/00_TIMELINE_MAESTRO.md",
                "docs/00_METRICAS_ECOSISTEMA.md",
            ),
        )
    )

    missing = [
        path
        for path in required
        if not context.is_file(path)
    ]

    if not missing:
        return _passed(
            rule,
            "Documentos maestros presentes.",
            *required,
        )

    return _failed(
        rule,
        "Faltan documentos maestros obligatorios.",
        "Genere o restaure los documentos mediante SGD-115 y SGD-116.",
        *missing,
        details={"missing": missing},
    )


def tests_evidence_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    candidates = [
        context.root / "tests",
        context.root / "pytest.ini",
    ]

    if all(path.exists() for path in candidates):
        test_count = len(list((context.root / "tests").rglob("test*.py")))

        if test_count > 0:
            return _passed(
                rule,
                f"Infraestructura de pruebas disponible: {test_count} archivos.",
                "tests/",
                "pytest.ini",
            )

    return _failed(
        rule,
        "No se encontró infraestructura suficiente de pruebas.",
        "Restaure pytest.ini y las pruebas institucionales.",
        "tests/",
        "pytest.ini",
    )


def evidence_present(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    base = context.root / "artifacts" / "pmo" / context.increment

    if not base.is_dir():
        return _failed(
            rule,
            "No existe directorio de evidencias del incremento.",
            "Genere la evidencia técnica y de trazabilidad.",
            f"artifacts/pmo/{context.increment}/",
        )

    files = [item for item in base.rglob("*") if item.is_file()]

    if files:
        return _passed(
            rule,
            f"Evidencias encontradas: {len(files)}.",
            f"artifacts/pmo/{context.increment}/",
        )

    return _failed(
        rule,
        "El directorio de evidencias está vacío.",
        "Genere evidencia legítima antes del cierre.",
        f"artifacts/pmo/{context.increment}/",
    )


def legacy_policy_compatible(
    context: PolicyContext,
    rule: PolicyRule,
) -> RuleResult:
    legacy = (
        context.root
        / "config"
        / "governance"
        / "sgd-114-policy.json"
    )

    if not legacy.is_file():
        return _failed(
            rule,
            "No existe la política heredada SGD-114.",
            "Restaure config/governance/sgd-114-policy.json.",
            "config/governance/sgd-114-policy.json",
        )

    try:
        payload = json.loads(
            legacy.read_text(encoding="utf-8-sig")
        )
    except json.JSONDecodeError as error:
        return _failed(
            rule,
            "La política heredada no contiene JSON válido.",
            "Corrija el archivo sin eliminar su trazabilidad.",
            "config/governance/sgd-114-policy.json",
            details={"error": str(error)},
        )

    if isinstance(payload, dict):
        return _passed(
            rule,
            "Política heredada disponible para compatibilidad.",
            "config/governance/sgd-114-policy.json",
        )

    return _failed(
        rule,
        "La política heredada no es un objeto JSON.",
        "Convierta la política a un objeto JSON válido.",
        "config/governance/sgd-114-policy.json",
    )


BUILTIN_RULES: tuple[tuple[PolicyRule, RuleExecutor], ...] = (
    (
        PolicyRule(
            "SGD114C-R001",
            "Repositorio institucional",
            "Verifica que la ejecución ocurra en un repositorio Git.",
            Severity.BLOCKER,
            "repository",
        ),
        repository_present,
    ),
    (
        PolicyRule(
            "SGD114C-R002",
            "Descriptor del componente",
            "Exige descriptor institucional del incremento.",
            Severity.BLOCKER,
            "traceability",
        ),
        component_descriptor_present,
    ),
    (
        PolicyRule(
            "SGD114C-R003",
            "Release técnico",
            "Exige release técnico versionado.",
            Severity.BLOCKER,
            "release",
        ),
        release_present,
    ),
    (
        PolicyRule(
            "SGD114C-R004",
            "Roadmap Maestro",
            "Exige Roadmap aprobado y sin errores.",
            Severity.BLOCKER,
            "roadmap",
        ),
        roadmap_approved,
    ),
    (
        PolicyRule(
            "SGD114C-R005",
            "Documentación maestra",
            "Exige documentos maestros del ecosistema.",
            Severity.BLOCKER,
            "documentation",
        ),
        master_documents_present,
    ),
    (
        PolicyRule(
            "SGD114C-R006",
            "Infraestructura de pruebas",
            "Verifica que exista evidencia ejecutable de pruebas.",
            Severity.BLOCKER,
            "quality",
        ),
        tests_evidence_present,
    ),
    (
        PolicyRule(
            "SGD114C-R007",
            "Evidencia institucional",
            "Exige evidencia del incremento.",
            Severity.BLOCKER,
            "evidence",
        ),
        evidence_present,
    ),
    (
        PolicyRule(
            "SGD114C-R008",
            "Compatibilidad SGD-114",
            "Mantiene disponible la política heredada.",
            Severity.BLOCKER,
            "compatibility",
        ),
        legacy_policy_compatible,
    ),
)
'@

$Registry = @'
"""Registro de reglas SGD-114C."""

from __future__ import annotations

from dataclasses import dataclass, field

from .policy_models import PolicyRule
from .policy_rules import BUILTIN_RULES, RuleExecutor


@dataclass(slots=True)
class PolicyRegistry:
    _items: dict[str, tuple[PolicyRule, RuleExecutor]] = field(
        default_factory=dict
    )

    def register(
        self,
        rule: PolicyRule,
        executor: RuleExecutor,
    ) -> None:
        if rule.code in self._items:
            raise ValueError(f"Regla duplicada: {rule.code}")
        self._items[rule.code] = (rule, executor)

    def items(
        self,
    ) -> tuple[tuple[PolicyRule, RuleExecutor], ...]:
        return tuple(
            self._items[key]
            for key in sorted(self._items)
        )


def build_default_registry() -> PolicyRegistry:
    registry = PolicyRegistry()

    for rule, executor in BUILTIN_RULES:
        registry.register(rule, executor)

    return registry
'@

$Engine = @'
"""Motor determinista de políticas SGD-114C."""

from __future__ import annotations

from datetime import datetime, timezone

from .policy_context import PolicyContext
from .policy_models import PolicyEvaluation
from .policy_registry import PolicyRegistry


def evaluate_policy(
    context: PolicyContext,
    registry: PolicyRegistry,
) -> PolicyEvaluation:
    results = tuple(
        executor(context, rule)
        for rule, executor in registry.items()
    )

    approved = not any(item.blocking for item in results)

    return PolicyEvaluation(
        policy_code=str(
            context.policy.get("policy_code", "SGD-114C")
        ),
        policy_version=str(
            context.policy.get("version", "1.0.0")
        ),
        increment=context.increment,
        approved=approved,
        results=results,
        generated_at_utc=datetime.now(
            timezone.utc
        ).isoformat(),
    )
'@

$Report = @'
"""Serialización e informes de SGD-114C."""

from __future__ import annotations

import json
from pathlib import Path

from .policy_models import PolicyEvaluation


def evaluation_to_dict(
    evaluation: PolicyEvaluation,
) -> dict:
    results = []

    for item in evaluation.results:
        results.append(
            {
                "rule": item.rule.code,
                "name": item.rule.name,
                "category": item.rule.category,
                "severity": item.rule.severity.value,
                "status": item.status.value,
                "passed": item.passed,
                "blocking": item.blocking,
                "message": item.message,
                "evidence": list(item.evidence),
                "remediation": item.remediation,
                "details": item.details,
            }
        )

    return {
        "policy_code": evaluation.policy_code,
        "policy_version": evaluation.policy_version,
        "increment": evaluation.increment,
        "approved": evaluation.approved,
        "exit_code": evaluation.exit_code,
        "generated_at_utc": evaluation.generated_at_utc,
        "blocking_rules": [
            item.rule.code
            for item in evaluation.blocking_rules
        ],
        "failed_rules": [
            item.rule.code
            for item in evaluation.failed_rules
        ],
        "results": results,
    }


def write_reports(
    evaluation: PolicyEvaluation,
    json_path: str | Path,
    markdown_path: str | Path,
) -> None:
    payload = evaluation_to_dict(evaluation)

    json_target = Path(json_path)
    markdown_target = Path(markdown_path)

    json_target.parent.mkdir(parents=True, exist_ok=True)
    markdown_target.parent.mkdir(parents=True, exist_ok=True)

    json_target.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    lines = [
        f"# {evaluation.policy_code} — {evaluation.increment}",
        "",
        f"- Versión: {evaluation.policy_version}",
        f"- Resultado: {'APROBADO' if evaluation.approved else 'NO APROBADO'}",
        f"- Código de salida: {evaluation.exit_code}",
        f"- Generado: {evaluation.generated_at_utc}",
        "",
        "## Reglas",
        "",
    ]

    for item in evaluation.results:
        lines.extend(
            [
                f"### {item.rule.code} — {item.rule.name}",
                "",
                f"- Categoría: {item.rule.category}",
                f"- Severidad: {item.rule.severity.value}",
                f"- Estado: {item.status.value}",
                f"- Mensaje: {item.message}",
                f"- Evidencia: {', '.join(item.evidence) or 'N/A'}",
                f"- Corrección: {item.remediation or 'N/A'}",
                "",
            ]
        )

    markdown_target.write_text(
        "\n".join(lines).rstrip() + "\n",
        encoding="utf-8",
    )
'@

$Cli = @'
"""CLI institucional de SGD-114C."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .policy_context import PolicyContext
from .policy_engine import evaluate_policy
from .policy_registry import build_default_registry
from .policy_report import write_reports


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--policy", required=True)
    parser.add_argument("--increment", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    policy = json.loads(
        Path(args.policy).read_text(encoding="utf-8-sig")
    )

    context = PolicyContext(
        root=root,
        increment=args.increment,
        policy=policy,
    )

    evaluation = evaluate_policy(
        context,
        build_default_registry(),
    )

    write_reports(
        evaluation,
        args.output_json,
        args.output_md,
    )

    print("Policy Governance Core ejecutado.")
    print("Política:", evaluation.policy_code, evaluation.policy_version)
    print("Incremento:", evaluation.increment)
    print(
        "Resultado:",
        "APROBADO" if evaluation.approved else "NO APROBADO",
    )
    print("Código de salida:", evaluation.exit_code)
    print("Bloqueantes:", len(evaluation.blocking_rules))
    print("JSON:", args.output_json)
    print("Markdown:", args.output_md)

    return evaluation.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Tests = @'
import json
from pathlib import Path

from sgoda.governance.policy_context import PolicyContext
from sgoda.governance.policy_engine import evaluate_policy
from sgoda.governance.policy_models import (
    PolicyRule,
    RuleResult,
    RuleStatus,
    Severity,
)
from sgoda.governance.policy_registry import (
    PolicyRegistry,
    build_default_registry,
)
from sgoda.governance.policy_report import evaluation_to_dict


def _minimum_repository(root: Path, increment: str) -> None:
    (root / ".git").mkdir()
    (root / "tests").mkdir()
    (root / "tests/test_example.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )
    (root / "pytest.ini").write_text(
        "[pytest]\n",
        encoding="utf-8",
    )

    descriptor = (
        root
        / "config"
        / "roadmap"
        / f"{increment}-component.json"
    )
    descriptor.parent.mkdir(parents=True)
    descriptor.write_text("{}", encoding="utf-8")

    (root / "releases" / f"{increment}-v1.0.0").mkdir(
        parents=True
    )

    legacy = root / "config/governance/sgd-114-policy.json"
    legacy.parent.mkdir(parents=True, exist_ok=True)
    legacy.write_text("{}", encoding="utf-8")

    evidence = root / "artifacts/pmo" / increment
    evidence.mkdir(parents=True)
    (evidence / "evidence.json").write_text(
        "{}",
        encoding="utf-8",
    )

    validation = root / "artifacts/roadmap/SGD-116/validation.json"
    validation.parent.mkdir(parents=True)
    validation.write_text(
        json.dumps(
            {
                "passed": True,
                "missing_dependencies": [],
                "broken_paths": [],
                "dependency_cycles": [],
                "duplicate_codes": [],
                "missing_master_documents": [],
            }
        ),
        encoding="utf-8",
    )

    for name in (
        "00_INDICE_MAESTRO.md",
        "00_ARQUITECTURA_MAESTRA.md",
        "00_REGISTRO_MAESTRO_COMPONENTES.md",
        "00_ROADMAP_MAESTRO.md",
        "00_DEPENDENCIAS_MAESTRAS.md",
        "00_TIMELINE_MAESTRO.md",
        "00_METRICAS_ECOSISTEMA.md",
    ):
        path = root / "docs" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("# Documento\n", encoding="utf-8")


def test_SGD_114C_approves_complete_context(tmp_path: Path) -> None:
    _minimum_repository(tmp_path, "SGD-116B")
    context = PolicyContext(
        tmp_path,
        "SGD-116B",
        {"policy_code": "SGD-114C", "version": "1.0.0"},
    )

    result = evaluate_policy(
        context,
        build_default_registry(),
    )

    assert result.approved is True
    assert result.exit_code == 0
    assert result.blocking_rules == ()


def test_SGD_114C_blocks_missing_release(tmp_path: Path) -> None:
    _minimum_repository(tmp_path, "SGD-116B")
    release = tmp_path / "releases/SGD-116B-v1.0.0"
    release.rmdir()

    result = evaluate_policy(
        PolicyContext(tmp_path, "SGD-116B", {}),
        build_default_registry(),
    )

    assert result.approved is False
    assert "SGD114C-R003" in {
        item.rule.code for item in result.blocking_rules
    }


def test_SGD_114C_registry_rejects_duplicates() -> None:
    registry = PolicyRegistry()
    rule = PolicyRule(
        "R1",
        "Test",
        "Test",
        Severity.INFO,
        "test",
    )

    def executor(context, registered_rule):
        return RuleResult(
            registered_rule,
            RuleStatus.PASSED,
            "ok",
        )

    registry.register(rule, executor)

    try:
        registry.register(rule, executor)
    except ValueError:
        pass
    else:
        raise AssertionError("El registro aceptó una regla duplicada")


def test_SGD_114C_report_is_normalized(tmp_path: Path) -> None:
    _minimum_repository(tmp_path, "SGD-116B")

    result = evaluate_policy(
        PolicyContext(tmp_path, "SGD-116B", {}),
        build_default_registry(),
    )

    payload = evaluation_to_dict(result)

    assert payload["approved"] is True
    assert payload["exit_code"] == 0
    assert len(payload["results"]) == 8


def test_SGD_114C_roadmap_failure_is_blocking(tmp_path: Path) -> None:
    _minimum_repository(tmp_path, "SGD-116B")
    validation = tmp_path / "artifacts/roadmap/SGD-116/validation.json"
    validation.write_text(
        json.dumps(
            {
                "passed": False,
                "missing_dependencies": [{"target": "SGD-999"}],
                "broken_paths": [],
                "dependency_cycles": [],
                "duplicate_codes": [],
                "missing_master_documents": [],
            }
        ),
        encoding="utf-8",
    )

    result = evaluate_policy(
        PolicyContext(tmp_path, "SGD-116B", {}),
        build_default_registry(),
    )

    assert result.approved is False
    assert "SGD114C-R004" in {
        item.rule.code for item in result.blocking_rules
    }
'@

$Policy = @'
{
  "policy_code": "SGD-114C",
  "version": "1.0.0",
  "name": "Policy Governance Core",
  "legacy_policy": "SGD-114 v1.1.0",
  "default_severity": "BLOCKER",
  "exit_codes": {
    "approved": 0,
    "not_approved": 2
  },
  "required_master_documents": [
    "docs/00_INDICE_MAESTRO.md",
    "docs/00_ARQUITECTURA_MAESTRA.md",
    "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
    "docs/00_ROADMAP_MAESTRO.md",
    "docs/00_DEPENDENCIAS_MAESTRAS.md",
    "docs/00_TIMELINE_MAESTRO.md",
    "docs/00_METRICAS_ECOSISTEMA.md"
  ],
  "rules": [
    "SGD114C-R001",
    "SGD114C-R002",
    "SGD114C-R003",
    "SGD114C-R004",
    "SGD114C-R005",
    "SGD114C-R006",
    "SGD114C-R007",
    "SGD114C-R008"
  ]
}
'@

$Component = @'
{
  "increment_code": "SGD-114C",
  "name": "Policy Governance Core",
  "component_type": "institutional_policy_engine",
  "version": "1.0.0",
  "status": "implemented",
  "dependencies": [
    "SGD-114",
    "SGD-115",
    "SGD-116B",
    "SPB-007"
  ],
  "source": [
    "src/sgoda/governance/policy_models.py",
    "src/sgoda/governance/policy_context.py",
    "src/sgoda/governance/policy_rules.py",
    "src/sgoda/governance/policy_registry.py",
    "src/sgoda/governance/policy_engine.py",
    "src/sgoda/governance/policy_report.py",
    "src/sgoda/governance/policy_cli.py"
  ],
  "tests": [
    "tests/governance/test_SGD_114C_policy_governance_core.py"
  ],
  "documentation": [
    "docs/01_Gobierno/SGD-114C-Policy-Governance-Core.md",
    "docs/01_Gobierno/SGD-114C-Migracion-SGD-114.md"
  ]
}
'@

$Doc = @'
# SGD-114C v1.0.0 — Policy Governance Core

SGD-114C centraliza la evaluación de gobernanza del ecosistema.

## Propiedades

- reglas explícitas y versionadas;
- resultados normalizados;
- códigos de salida deterministas;
- evidencia por regla;
- corrección recomendada por incumplimiento;
- compatibilidad con SGD-114;
- sin aprobaciones simuladas.

## Código de salida

- `0`: aprobado;
- `2`: no aprobado.
'@

$Migration = @'
# Migración desde SGD-114 hacia SGD-114C

La política heredada se conserva para trazabilidad.

SGD-114C no elimina ni reescribe automáticamente
`config/governance/sgd-114-policy.json`.

La migración consiste en utilizar `policy_cli` como evaluador normalizado y
mantener SGD-114 como referencia histórica y política compatible.
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

$Output = "artifacts/pmo/SGD-114C"
New-Item -ItemType Directory -Path $Output -Force | Out-Null

& python -m sgoda.governance.policy_cli `
    --root "." `
    --policy "config/governance/SGD-114C-policy.json" `
    --increment $Increment `
    --output-json "$Output/$Increment-policy-result.json" `
    --output-md "$Output/$Increment-policy-result.md"

exit $LASTEXITCODE
'@

Write-Step "Instalando SGD-114C"

Write-Utf8 $ModelsPath $Models
Write-Utf8 $ContextPath $Context
Write-Utf8 $RulesPath $Rules
Write-Utf8 $RegistryPath $Registry
Write-Utf8 $EnginePath $Engine
Write-Utf8 $ReportPath $Report
Write-Utf8 $CliPath $Cli
Write-Utf8 $TestPath $Tests
Write-Utf8 $PolicyPath $Policy
Write-Utf8 $ComponentPath $Component
Write-Utf8 $DocPath $Doc
Write-Utf8 $MigrationDocPath $Migration
Write-Utf8 $InvokePath $Invoke

Invoke-Checked "Validando sintaxis" {
    python -m py_compile `
        "src/sgoda/governance/policy_models.py" `
        "src/sgoda/governance/policy_context.py" `
        "src/sgoda/governance/policy_rules.py" `
        "src/sgoda/governance/policy_registry.py" `
        "src/sgoda/governance/policy_engine.py" `
        "src/sgoda/governance/policy_report.py" `
        "src/sgoda/governance/policy_cli.py" `
        "tests/governance/test_SGD_114C_policy_governance_core.py"
}

Invoke-Checked "Ejecutando 5 pruebas específicas SGD-114C" {
    python -m pytest `
        "tests/governance/test_SGD_114C_policy_governance_core.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Evaluando incremento real con SGD-114C"

New-Item -ItemType Directory -Path $ArtifactsDir -Force | Out-Null

& python -m sgoda.governance.policy_cli `
    --root "$ProjectRoot" `
    --policy "$PolicyPath" `
    --increment "$Increment" `
    --output-json "$GateJson" `
    --output-md "$GateMd"

$PolicyExitCode = $LASTEXITCODE

Require-File $GateJson
Require-File $GateMd

$Gate = Get-Content `
    -LiteralPath $GateJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($PolicyExitCode -ne 0 -or -not $Gate.approved) {
    Write-Host ""
    Write-Host "Reglas bloqueantes:" -ForegroundColor Red
    @($Gate.results) |
        Where-Object { $_.blocking } |
        Format-Table rule, name, message, remediation -AutoSize

    throw "SGD-114C no aprobó $Increment. Revise $GateMd"
}

Write-Step "Generando evidencia de implementación"

Write-Json $EvidencePath ([ordered]@{
    increment_code = "SGD-114C"
    version = "1.0.0"
    status = "implemented"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    evaluated_increment = $Increment
    approved = [bool]$Gate.approved
    exit_code = $Gate.exit_code
    blocking_rules = @($Gate.blocking_rules)
    failed_rules = @($Gate.failed_rules)
    specific_tests = 5
    full_suite_executed = (-not $SkipFullSuite)
    backup = $BackupDir
})

Write-Step "Actualizando documentación maestra SGD-115"

Invoke-Checked "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Write-Step "Creando release técnico"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Path in @(
    $ModelsPath,
    $ContextPath,
    $RulesPath,
    $RegistryPath,
    $EnginePath,
    $ReportPath,
    $CliPath,
    $TestPath,
    $PolicyPath,
    $ComponentPath,
    $DocPath,
    $MigrationDocPath,
    $InvokePath,
    $GateJson,
    $GateMd,
    $EvidencePath
)) {
    Require-File $Path

    Copy-Item `
        -LiteralPath $Path `
        -Destination (Join-Path $ReleaseDir (Split-Path $Path -Leaf)) `
        -Force
}

Write-Step "Resultado final"

Write-Host "SGD-114C v1.0.0 implementado." -ForegroundColor Green
Write-Host "Policy Governance Core: OPERATIVO." -ForegroundColor Green
Write-Host "Pruebas específicas: 5 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Incremento evaluado: $Increment" -ForegroundColor Cyan
Write-Host "Resultado institucional: APROBADO." -ForegroundColor Green
Write-Host "Código de salida: 0." -ForegroundColor Green
Write-Host "Reglas bloqueantes: 0." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SGD-114C-v1.0.0" -ForegroundColor Cyan
Write-Host "Evidencia JSON: $GateJson" -ForegroundColor Cyan
Write-Host "Informe Markdown: $GateMd" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
