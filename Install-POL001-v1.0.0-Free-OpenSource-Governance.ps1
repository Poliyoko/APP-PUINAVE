<#
.SYNOPSIS
    Instala POL-001 v1.0.0 — Uso Preferente de Tecnologías Gratuitas
    y de Código Abierto.

.DESCRIPTION
    Implementa el registro tecnológico institucional, motor de análisis,
    excepciones ADR, pruebas, documentación, evidencias y release.
    Compatible con Windows PowerShell 5.1.
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

function Write-Utf8 {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path
    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Require-Path {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Falta elemento requerido: $Path"
    }
}

function Invoke-Checked {
    param([string]$Description, [scriptblock]$Action)

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

if (-not (Test-Path -LiteralPath $env:PYTHONPATH -PathType Container)) {
    throw "No existe la carpeta src: $env:PYTHONPATH"
}

$SourceDir = Join-Path $ProjectRoot "src\sgoda\governance\free_technology_policy"
$TestsDir = Join-Path $ProjectRoot "tests\governance\free_technology_policy"
$ConfigDir = Join-Path $ProjectRoot "config\policies"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno\POL-001"
$ArtifactDir = Join-Path $ProjectRoot "artifacts\policy\POL-001-v1.0.0"
$ReleaseDir = Join-Path $ProjectRoot "releases\POL-001-v1.0.0"

foreach ($Directory in @(
    $SourceDir,
    $TestsDir,
    $ConfigDir,
    $DocsDir,
    $ArtifactDir,
    $ReleaseDir
)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

$Module = @'

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


APPROVED = "approved"
REVIEW = "review_required"
PROHIBITED = "prohibited"


@dataclass(frozen=True, slots=True)
class Finding:
    source: str
    technology: str
    classification: str
    reason: str
    adr_required: bool

    def to_dict(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "technology": self.technology,
            "classification": self.classification,
            "reason": self.reason,
            "adr_required": self.adr_required,
        }


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def normalize_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.casefold())


def technology_index(registry: dict[str, Any]) -> dict[str, dict[str, Any]]:
    index: dict[str, dict[str, Any]] = {}
    for item in registry.get("technologies", []):
        if not isinstance(item, dict):
            continue
        aliases = [item.get("name", ""), *item.get("aliases", [])]
        for alias in aliases:
            if str(alias).strip():
                index[normalize_name(str(alias))] = item
    return index


def classify(
    technology: str,
    registry: dict[str, Any],
) -> tuple[str, str, bool]:
    item = technology_index(registry).get(normalize_name(technology))
    if item is None:
        return (
            REVIEW,
            "Tecnología no registrada; requiere evaluación institucional.",
            True,
        )
    return (
        str(item.get("classification", REVIEW)),
        str(item.get("reason", "Clasificación institucional.")),
        bool(item.get("adr_required", False)),
    )


def requirement_names(path: Path) -> list[str]:
    names: list[str] = []
    for raw in path.read_text(
        encoding="utf-8-sig",
        errors="replace",
    ).splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith(("-", "--")):
            continue
        name = re.split(r"[<>=!~;\[\]\s]", line, maxsplit=1)[0].strip()
        if name:
            names.append(name)
    return names


def package_json_names(path: Path) -> list[str]:
    payload = load_json(path)
    names: list[str] = []
    if not isinstance(payload, dict):
        return names
    for section in ("dependencies", "devDependencies", "optionalDependencies"):
        value = payload.get(section, {})
        if isinstance(value, dict):
            names.extend(str(item) for item in value)
    return names


def compose_images(path: Path) -> list[str]:
    content = path.read_text(
        encoding="utf-8-sig",
        errors="replace",
    )
    return [
        value.strip().strip("'\"")
        for value in re.findall(
            r"(?im)^\s*image\s*:\s*([^\s#]+)",
            content,
        )
    ]


def workflow_node_types(path: Path) -> list[str]:
    payload = load_json(path)
    nodes = payload.get("nodes", []) if isinstance(payload, dict) else []
    return sorted(
        {
            str(node.get("type", "")).strip()
            for node in nodes
            if isinstance(node, dict) and str(node.get("type", "")).strip()
        }
    )


def adr_exceptions(root: Path) -> set[str]:
    approved: set[str] = set()
    adr_dir = root / "docs/03_ADR"
    if not adr_dir.is_dir():
        return approved

    for path in sorted(adr_dir.glob("*.md")):
        content = path.read_text(
            encoding="utf-8-sig",
            errors="replace",
        )
        if not re.search(
            r"(?im)^\s*(estado|status)\s*:\s*(aprobado|approved)\s*$",
            content,
        ):
            continue
        for match in re.findall(
            r"(?im)^\s*(?:tecnología|technology)\s*:\s*(.+?)\s*$",
            content,
        ):
            approved.add(normalize_name(match))
    return approved


def scan_repository(
    root_value: str | Path,
    registry_value: str | Path,
) -> dict[str, Any]:
    root = Path(root_value).resolve()
    registry_path = Path(registry_value)
    if not registry_path.is_absolute():
        registry_path = root / registry_path

    registry = load_json(registry_path)
    exceptions = adr_exceptions(root)
    findings: list[Finding] = []

    def add(source: Path, technology: str) -> None:
        classification, reason, adr_required = classify(
            technology,
            registry,
        )
        if (
            classification in {REVIEW, PROHIBITED}
            and normalize_name(technology) in exceptions
        ):
            classification = APPROVED
            reason = "Excepción aprobada mediante ADR institucional."
            adr_required = False

        findings.append(
            Finding(
                source=source.relative_to(root).as_posix(),
                technology=technology,
                classification=classification,
                reason=reason,
                adr_required=adr_required,
            )
        )

    for filename in ("requirements.txt", "requirements-dev.txt"):
        path = root / filename
        if path.is_file():
            for name in requirement_names(path):
                add(path, name)

    for path in sorted(root.rglob("package.json")):
        if any(part in {"node_modules", ".git", ".venv"} for part in path.parts):
            continue
        for name in package_json_names(path):
            add(path, name)

    for path in sorted(root.rglob("docker-compose*.yml")) + sorted(
        root.rglob("docker-compose*.yaml")
    ):
        if any(part in {".git", ".venv"} for part in path.parts):
            continue
        for image in compose_images(path):
            add(path, image.split("@", 1)[0].split(":", 1)[0])

    workflows = root / "automation/n8n/workflows"
    if workflows.is_dir():
        for path in sorted(workflows.glob("*.json")):
            for node_type in workflow_node_types(path):
                add(path, node_type)

    counts = {
        APPROVED: sum(item.classification == APPROVED for item in findings),
        REVIEW: sum(item.classification == REVIEW for item in findings),
        PROHIBITED: sum(item.classification == PROHIBITED for item in findings),
    }
    approved = counts[PROHIBITED] == 0 and counts[REVIEW] == 0

    return {
        "policy": "POL-001",
        "version": "1.0.0",
        "registry": registry_path.relative_to(root).as_posix(),
        "findings": [item.to_dict() for item in findings],
        "counts": counts,
        "approved": approved,
    }


def write_reports(
    report: dict[str, Any],
    output_dir_value: str | Path,
) -> None:
    output_dir = Path(output_dir_value)
    output_dir.mkdir(parents=True, exist_ok=True)

    (output_dir / "institutional-compliance.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    lines = [
        "# POL-001 — Informe de cumplimiento",
        "",
        f"- Aprobadas: {report['counts'][APPROVED]}",
        f"- Requieren revisión: {report['counts'][REVIEW]}",
        f"- Prohibidas: {report['counts'][PROHIBITED]}",
        f"- Resultado: {'APROBADO' if report['approved'] else 'NO APROBADO'}",
        "",
        "| Fuente | Tecnología | Clasificación | Motivo |",
        "|---|---|---|---|",
    ]
    for item in report["findings"]:
        lines.append(
            "| `{}` | `{}` | {} | {} |".format(
                item["source"],
                item["technology"],
                item["classification"],
                item["reason"].replace("|", "/"),
            )
        )

    (output_dir / "institutional-compliance.md").write_text(
        "\n".join(lines).rstrip() + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--registry", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()

    report = scan_repository(args.root, args.registry)
    write_reports(report, args.output_dir)
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["approved"] else 2

'@

$Tests = @'

from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.free_technology_policy import (
    APPROVED,
    PROHIBITED,
    REVIEW,
    classify,
    compose_images,
    normalize_name,
    package_json_names,
    requirement_names,
    scan_repository,
    technology_index,
    workflow_node_types,
    write_reports,
)


def registry() -> dict:
    return {
        "technologies": [
            {
                "name": "fastapi",
                "aliases": ["FastAPI"],
                "classification": APPROVED,
                "reason": "MIT",
                "adr_required": False,
            },
            {
                "name": "n8n-nodes-base.webhook",
                "aliases": [],
                "classification": REVIEW,
                "reason": "Fair-code",
                "adr_required": True,
            },
            {
                "name": "commercial-sdk",
                "aliases": [],
                "classification": PROHIBITED,
                "reason": "Pago obligatorio",
                "adr_required": True,
            },
        ]
    }


def write_registry(root: Path) -> Path:
    path = root / "config/policies/POL-001-technology-registry.json"
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps(registry()), encoding="utf-8")
    return path


def test_normalize_name() -> None:
    assert normalize_name("n8n-nodes-base.webhook") == "n8nnodesbasewebhook"


def test_technology_index_includes_aliases() -> None:
    index = technology_index(registry())
    assert "fastapi" in index


def test_approved_classification() -> None:
    assert classify("FastAPI", registry())[0] == APPROVED


def test_unknown_requires_review() -> None:
    assert classify("unknown", registry())[0] == REVIEW


def test_requirements_parser(tmp_path: Path) -> None:
    path = tmp_path / "requirements.txt"
    path.write_text("fastapi==1.0\n# comment\npytest>=8\n", encoding="utf-8")
    assert requirement_names(path) == ["fastapi", "pytest"]


def test_package_json_parser(tmp_path: Path) -> None:
    path = tmp_path / "package.json"
    path.write_text(
        json.dumps({"dependencies": {"axios": "1"}, "devDependencies": {"vitest": "1"}}),
        encoding="utf-8",
    )
    assert package_json_names(path) == ["axios", "vitest"]


def test_compose_parser(tmp_path: Path) -> None:
    path = tmp_path / "docker-compose.yml"
    path.write_text("services:\n  db:\n    image: postgres:16\n", encoding="utf-8")
    assert compose_images(path) == ["postgres:16"]


def test_workflow_nodes_parser(tmp_path: Path) -> None:
    path = tmp_path / "workflow.json"
    path.write_text(
        json.dumps({"nodes": [{"type": "n8n-nodes-base.webhook"}]}),
        encoding="utf-8",
    )
    assert workflow_node_types(path) == ["n8n-nodes-base.webhook"]


def test_scan_blocks_prohibited_dependency(tmp_path: Path) -> None:
    registry_path = write_registry(tmp_path)
    (tmp_path / "requirements.txt").write_text(
        "commercial-sdk==1.0\n", encoding="utf-8"
    )
    report = scan_repository(tmp_path, registry_path)
    assert report["counts"][PROHIBITED] == 1
    assert not report["approved"]


def test_approved_adr_exception(tmp_path: Path) -> None:
    registry_path = write_registry(tmp_path)
    (tmp_path / "requirements.txt").write_text(
        "commercial-sdk==1.0\n", encoding="utf-8"
    )
    adr = tmp_path / "docs/03_ADR"
    adr.mkdir(parents=True)
    (adr / "ADR-999.md").write_text(
        "Estado: Aprobado\nTecnología: commercial-sdk\n",
        encoding="utf-8",
    )
    report = scan_repository(tmp_path, registry_path)
    assert report["counts"][PROHIBITED] == 0
    assert report["approved"]


def test_reports_are_written(tmp_path: Path) -> None:
    report = {
        "counts": {APPROVED: 1, REVIEW: 0, PROHIBITED: 0},
        "approved": True,
        "findings": [
            {
                "source": "requirements.txt",
                "technology": "fastapi",
                "classification": APPROVED,
                "reason": "MIT",
            }
        ],
    }
    write_reports(report, tmp_path / "artifacts")
    assert (tmp_path / "artifacts/institutional-compliance.json").is_file()
    assert (tmp_path / "artifacts/institutional-compliance.md").is_file()

'@

$Registry = @'
{
  "policy": "POL-001",
  "version": "1.0.0",
  "classification_model": {
    "approved": "Gratuita y compatible con el proyecto.",
    "review_required": "Gratuita o comunitaria, pero con condiciones especiales.",
    "prohibited": "Requiere pago obligatorio o no tiene autorización institucional."
  },
  "technologies": [
    {
      "name": "python",
      "aliases": [
        "Python"
      ],
      "classification": "approved",
      "license": "Python Software Foundation License",
      "cost_model": "free",
      "reason": "Lenguaje gratuito y open source.",
      "adr_required": false
    },
    {
      "name": "fastapi",
      "aliases": [
        "FastAPI"
      ],
      "classification": "approved",
      "license": "MIT",
      "cost_model": "free",
      "reason": "Framework gratuito y de código abierto.",
      "adr_required": false
    },
    {
      "name": "pytest",
      "aliases": [],
      "classification": "approved",
      "license": "MIT",
      "cost_model": "free",
      "reason": "Herramienta de pruebas gratuita y open source.",
      "adr_required": false
    },
    {
      "name": "postgres",
      "aliases": [
        "postgresql"
      ],
      "classification": "approved",
      "license": "PostgreSQL License",
      "cost_model": "free",
      "reason": "Base de datos open source con licencia permisiva.",
      "adr_required": false
    },
    {
      "name": "n8nio/n8n",
      "aliases": [
        "n8n"
      ],
      "classification": "review_required",
      "license": "Sustainable Use License",
      "cost_model": "free-community-self-hosted",
      "reason": "Community Edition gratuita, pero con licencia fair-code y restricciones de uso.",
      "adr_required": true
    },
    {
      "name": "n8n-nodes-base.webhook",
      "aliases": [
        "n8n-nodes-base.set",
        "n8n-nodes-base.respondToWebhook"
      ],
      "classification": "review_required",
      "license": "Sustainable Use License",
      "cost_model": "free-community-self-hosted",
      "reason": "Nodo perteneciente a n8n Community; requiere aceptación institucional de su licencia.",
      "adr_required": true
    },
    {
      "name": "github-free",
      "aliases": [
        "github"
      ],
      "classification": "review_required",
      "license": "proprietary-service-free-tier",
      "cost_model": "free-tier",
      "reason": "Servicio gratuito con límites; no debe ser la única copia institucional.",
      "adr_required": true
    },
    {
      "name": "docker-desktop",
      "aliases": [],
      "classification": "review_required",
      "license": "Docker Subscription Service Agreement",
      "cost_model": "conditional-free",
      "reason": "La gratuidad depende del tipo de usuario y organización; preferir Docker Engine o Podman.",
      "adr_required": true
    },
    {
      "name": "docker-engine",
      "aliases": [
        "podman"
      ],
      "classification": "approved",
      "license": "open-source",
      "cost_model": "free",
      "reason": "Alternativa gratuita para contenedores.",
      "adr_required": false
    }
  ]
}
'@

$Component = @'
{
  "increment_code": "POL-001",
  "name": "Uso Preferente de Tecnologías Gratuitas y de Código Abierto",
  "version": "1.0.0",
  "status": "implemented_tested_and_candidate_for_closure",
  "phase": "Gobierno Tecnológico",
  "source": ["src/sgoda/governance/free_technology_policy"],
  "tests": ["tests/governance/free_technology_policy"],
  "documentation": ["docs/01_Gobierno/POL-001"],
  "artifacts": ["artifacts/policy/POL-001-v1.0.0"],
  "dependencies": ["SGD-117", "SPT-019", "PCI-001", "PCI-002"]
}
'@

$Policy = @'
{
  "policy_id": "POL-001-v1.0.0",
  "mandatory": true,
  "default_for_unknown_technology": "review_required",
  "paid_mandatory_dependency": "prohibited",
  "fair_code_dependency": "review_required",
  "approved_adr_can_override": true,
  "internet_required_for_execution": false,
  "commercial_api_required": false
}
'@

$Architecture = @'
# POL-001 — Arquitectura

POL-001 implementa un registro tecnológico versionado y un motor reproducible
que inspecciona dependencias Python, npm, imágenes Compose y workflows n8n.

Las tecnologías desconocidas no se aprueban automáticamente: quedan en estado
`review_required`. Las excepciones solo se aceptan mediante ADR con estado
Aprobado y una línea `Tecnología: <nombre>`.
'@

$Operations = @'
# POL-001 — Manual operativo

1. Mantener actualizado el registro tecnológico institucional.
2. Ejecutar el motor antes de liberar cualquier componente.
3. Resolver todo hallazgo `review_required`.
4. No aceptar dependencias `prohibited` sin ADR aprobado.
5. Conservar los informes JSON y Markdown como evidencia.
6. No interpretar este motor como asesoría jurídica.
'@

Write-Utf8 (Join-Path $SourceDir "__init__.py") $Module
Write-Utf8 (Join-Path $SourceDir "__main__.py") (
    "from . import main" +
    [Environment]::NewLine +
    "raise SystemExit(main())" +
    [Environment]::NewLine
)
Write-Utf8 (
    Join-Path $TestsDir "test_POL_001_free_technology_policy.py"
) $Tests
Write-Utf8 (
    Join-Path $ConfigDir "POL-001-technology-registry.json"
) $Registry
Write-Utf8 (
    Join-Path $ConfigDir "POL-001-component.json"
) $Component
Write-Utf8 (
    Join-Path $ConfigDir "POL-001-policy.json"
) $Policy
Write-Utf8 (
    Join-Path $DocsDir "POL-001-Arquitectura.md"
) $Architecture
Write-Utf8 (
    Join-Path $DocsDir "POL-001-Manual-Operativo.md"
) $Operations

Invoke-Checked "Validando sintaxis Python POL-001" {
    python -m py_compile `
        "src/sgoda/governance/free_technology_policy/__init__.py" `
        "src/sgoda/governance/free_technology_policy/__main__.py" `
        "tests/governance/free_technology_policy/test_POL_001_free_technology_policy.py"
}

Invoke-Checked "Ejecutando pruebas POL-001" {
    python -m pytest `
        "tests/governance/free_technology_policy/test_POL_001_free_technology_policy.py" `
        -q `
        --junitxml=(
            Join-Path $ArtifactDir "unit-tests.xml"
        )
}

Step "Ejecutando auditoría institucional POL-001"

python -m sgoda.governance.free_technology_policy `
    --root "$ProjectRoot" `
    --registry (
        Join-Path $ConfigDir "POL-001-technology-registry.json"
    ) `
    --output-dir "$ArtifactDir"

$AuditCode = $LASTEXITCODE
$global:LASTEXITCODE = 0

$CompliancePath = Join-Path `
    $ArtifactDir `
    "institutional-compliance.json"
Require-Path $CompliancePath

$Compliance = Get-Content `
    -LiteralPath $CompliancePath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$Certification = [ordered]@{
    component = "POL-001"
    version = "1.0.0"
    python_syntax = "approved"
    unit_tests = "approved"
    approved_findings = [int]$Compliance.counts.approved
    review_required = [int]$Compliance.counts.review_required
    prohibited = [int]$Compliance.counts.prohibited
    policy_gate = if ([bool]$Compliance.approved) {
        "approved"
    }
    else {
        "not_approved"
    }
    candidate_for_closure = [bool]$Compliance.approved
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
}

Write-Utf8 `
    (Join-Path $ArtifactDir "installer-certification.json") `
    (
        ($Certification | ConvertTo-Json -Depth 50) +
        [Environment]::NewLine
    )

$ReleaseFiles = @(
    "src\sgoda\governance\free_technology_policy",
    "tests\governance\free_technology_policy",
    "config\policies\POL-001-technology-registry.json",
    "config\policies\POL-001-component.json",
    "config\policies\POL-001-policy.json",
    "docs\01_Gobierno\POL-001",
    "artifacts\policy\POL-001-v1.0.0"
)

foreach ($RelativePath in $ReleaseFiles) {
    $Source = Join-Path $ProjectRoot $RelativePath
    Require-Path $Source

    Copy-Item `
        -LiteralPath $Source `
        -Destination $ReleaseDir `
        -Recurse `
        -Force
}

$Manifest = [ordered]@{
    component = "POL-001"
    version = "1.0.0"
    status = if ([bool]$Compliance.approved) {
        "candidate_for_closure"
    }
    else {
        "implemented_with_policy_findings"
    }
    approved_findings = [int]$Compliance.counts.approved
    review_required = [int]$Compliance.counts.review_required
    prohibited = [int]$Compliance.counts.prohibited
    internet_required = $false
    paid_service_required = $false
}

Write-Utf8 `
    (Join-Path $ReleaseDir "manifest.json") `
    (
        ($Manifest | ConvertTo-Json -Depth 50) +
        [Environment]::NewLine
    )

if ($AuditCode -ne 0) {
    Write-Host ""
    Write-Host "POL-001 fue implementado, pero el repositorio tiene hallazgos." `
        -ForegroundColor Yellow
    Write-Host (
        "Revisión requerida: " +
        [string]$Compliance.counts.review_required
    ) -ForegroundColor Yellow
    Write-Host (
        "Prohibidas: " +
        [string]$Compliance.counts.prohibited
    ) -ForegroundColor Yellow

    throw (
        "POL-001 no autoriza el cierre hasta resolver los hallazgos o " +
        "aprobar las excepciones mediante ADR."
    )
}

if ($Publish) {
    $Publisher = Join-Path `
        $ProjectRoot `
        "scripts\Invoke-SPB007-CanonicalPublish.ps1"
    Require-Path $Publisher

    Invoke-Checked "Publicando POL-001 mediante gate institucional" {
        & $Publisher `
            -Publish `
            -CommitMessage "feat(governance): implement POL-001 free technology policy" `
            -EvidenceCommitMessage "chore(governance): publish POL-001 evidence"
    }
}

Step "Resultado final"
Write-Host "POL-001 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Pruebas: APROBADAS." -ForegroundColor Green
Write-Host "Auditoría tecnológica: APROBADA." -ForegroundColor Green
Write-Host "Servicios de pago obligatorios: NO." -ForegroundColor Green
Write-Host "Release: releases\POL-001-v1.0.0" -ForegroundColor Cyan
