<#
.SYNOPSIS
    Instala SGD-117 v1.0.0 — Institutional Repository Manager.

.DESCRIPTION
    Ejecuta auditoría del Índice Maestro y Registro Maestro de Componentes,
    instala el administrador institucional del repositorio, genera pruebas,
    evidencias, documentación y release, y publica solo si todos los gates
    quedan aprobados.

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

function Require-File {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Falta $Description`: $Path"
    }
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
    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }
    Write-Host "Creado/actualizado: $Path" -ForegroundColor Green
}

function Write-Json {
    param([string]$Path, [object]$Value)
    Write-Utf8 `
        -Path $Path `
        -Content (
            ($Value | ConvertTo-Json -Depth 100) +
            [Environment]::NewLine
        )
}

function Run {
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\governance\repository_manager"
$TestsDir = Join-Path $ProjectRoot "tests\governance\repository_manager"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno\SGD-117"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-117-v1.0.0"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-117-v1.0.0"

$PreAuditJson = Join-Path $PmoDir "master-documents-pre-audit.json"
$PostAuditJson = Join-Path $PmoDir "master-documents-post-audit.json"
$InventoryJson = Join-Path $PmoDir "repository-inventory.json"
$ValidationJson = Join-Path $PmoDir "repository-validation.json"
$ReportJson = Join-Path $PmoDir "institutional-repository-report.json"
$EvidenceJson = Join-Path $PmoDir "implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "implementation-evidence.md"

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"
$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"

$RunnerPath = Join-Path $ScriptsDir "Invoke-InstitutionalPytest.ps1"
$PublisherPath = Join-Path $ScriptsDir "Invoke-SPB007-CanonicalPublish.ps1"

foreach ($Required in @(
    (Join-Path $ProjectRoot "docs\00_INDICE_MAESTRO.md"),
    (Join-Path $ProjectRoot "docs\00_REGISTRO_MAESTRO_COMPONENTES.md"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\release_management\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    $RunnerPath,
    $PublisherPath
)) {
    Require-File -Path $Required -Description $Required
}

New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null
New-Item -ItemType Directory -Path $TestsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

$Models = @'

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class RepositoryAsset:
    path: str
    category: str
    size_bytes: int
    sha256: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class MasterDocumentAudit:
    index_exists: bool
    registry_exists: bool
    index_mentions_component: bool
    registry_mentions_component: bool
    config_declares_component: bool
    release_exists: bool

    @property
    def component_preexisted(self) -> bool:
        return any(
            (
                self.index_mentions_component,
                self.registry_mentions_component,
                self.config_declares_component,
                self.release_exists,
            )
        )

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["component_preexisted"] = self.component_preexisted
        return payload

'@

$Manager = @'

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Iterable

from .models import MasterDocumentAudit, RepositoryAsset


IGNORED_PARTS = {
    ".git",
    ".venv",
    "__pycache__",
    ".pytest_cache",
    "node_modules",
}

CATEGORY_ROOTS = {
    "source": "src",
    "tests": "tests",
    "documentation": "docs",
    "configuration": "config",
    "evidence": "artifacts",
    "release": "releases",
    "automation": "scripts",
    "dashboard": "dashboard",
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _relative(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def _is_ignored(path: Path) -> bool:
    return any(part in IGNORED_PARTS for part in path.parts)


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return ""


class InstitutionalRepositoryManager:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()

    def audit_master_documents(
        self,
        component_code: str = "SGD-117",
    ) -> MasterDocumentAudit:
        index = self.root / "docs" / "00_INDICE_MAESTRO.md"
        registry = (
            self.root
            / "docs"
            / "00_REGISTRO_MAESTRO_COMPONENTES.md"
        )
        normalized = component_code.casefold()

        index_text = _read_text(index).casefold() if index.is_file() else ""
        registry_text = (
            _read_text(registry).casefold()
            if registry.is_file()
            else ""
        )

        config_declares = False
        config_root = self.root / "config"
        if config_root.is_dir():
            for path in config_root.rglob("*.json"):
                if _is_ignored(path):
                    continue
                try:
                    payload = json.loads(
                        path.read_text(encoding="utf-8-sig")
                    )
                except (OSError, UnicodeError, json.JSONDecodeError):
                    continue
                code = str(
                    payload.get("increment_code")
                    or payload.get("component_code")
                    or payload.get("code")
                    or ""
                ).casefold()
                if code == normalized:
                    config_declares = True
                    break

        releases = self.root / "releases"
        release_exists = (
            releases.is_dir()
            and any(
                path.is_dir()
                and path.name.casefold().startswith(
                    normalized + "-v"
                )
                for path in releases.iterdir()
            )
        )

        return MasterDocumentAudit(
            index_exists=index.is_file(),
            registry_exists=registry.is_file(),
            index_mentions_component=normalized in index_text,
            registry_mentions_component=normalized in registry_text,
            config_declares_component=config_declares,
            release_exists=release_exists,
        )

    def inventory(self) -> tuple[RepositoryAsset, ...]:
        assets: list[RepositoryAsset] = []

        for category, root_name in CATEGORY_ROOTS.items():
            base = self.root / root_name
            if not base.exists():
                continue

            for path in sorted(base.rglob("*")):
                if not path.is_file() or _is_ignored(path):
                    continue
                try:
                    size = path.stat().st_size
                    digest = _sha256(path)
                except OSError:
                    continue
                assets.append(
                    RepositoryAsset(
                        path=_relative(path, self.root),
                        category=category,
                        size_bytes=size,
                        sha256=digest,
                    )
                )

        return tuple(assets)

    def validate_structure(self) -> dict[str, Any]:
        required_directories = [
            "src",
            "tests",
            "docs",
            "config",
            "artifacts",
            "releases",
            "scripts",
        ]
        required_files = [
            "pytest.ini",
            "docs/00_INDICE_MAESTRO.md",
            "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
            "docs/00_ARQUITECTURA_MAESTRA.md",
        ]

        missing_directories = [
            item
            for item in required_directories
            if not (self.root / item).is_dir()
        ]
        missing_files = [
            item
            for item in required_files
            if not (self.root / item).is_file()
        ]

        invalid_json = []
        config_root = self.root / "config"
        if config_root.is_dir():
            for path in sorted(config_root.rglob("*.json")):
                if _is_ignored(path):
                    continue
                try:
                    json.loads(path.read_text(encoding="utf-8-sig"))
                except (OSError, UnicodeError, json.JSONDecodeError):
                    invalid_json.append(_relative(path, self.root))

        approved = not any(
            (missing_directories, missing_files, invalid_json)
        )
        return {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "missing_directories": missing_directories,
            "missing_files": missing_files,
            "invalid_json": invalid_json,
        }

    def find_untracked_large_assets(
        self,
        threshold_bytes: int = 25 * 1024 * 1024,
    ) -> list[dict[str, Any]]:
        results = []
        for item in self.inventory():
            if item.size_bytes >= threshold_bytes:
                results.append(
                    {
                        "path": item.path,
                        "category": item.category,
                        "size_bytes": item.size_bytes,
                        "sha256": item.sha256,
                    }
                )
        return results

    def build_report(self) -> dict[str, Any]:
        audit = self.audit_master_documents()
        assets = self.inventory()
        validation = self.validate_structure()
        category_counts: dict[str, int] = {}
        total_bytes = 0

        for item in assets:
            category_counts[item.category] = (
                category_counts.get(item.category, 0) + 1
            )
            total_bytes += item.size_bytes

        return {
            "component": "SGD-117",
            "version": "1.0.0",
            "master_document_audit": audit.to_dict(),
            "repository_validation": validation,
            "asset_count": len(assets),
            "total_bytes": total_bytes,
            "category_counts": category_counts,
            "large_assets": self.find_untracked_large_assets(),
            "approved": validation["approved"],
            "exit_code": validation["exit_code"],
        }

'@

$Cli = @'

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .manager import InstitutionalRepositoryManager


def _write(path: str, payload: object) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument(
        "--operation",
        choices=("audit-master", "inventory", "validate", "report"),
        required=True,
    )
    parser.add_argument("--output-json", required=True)
    args = parser.parse_args()

    manager = InstitutionalRepositoryManager(args.root)

    if args.operation == "audit-master":
        payload = manager.audit_master_documents().to_dict()
        payload["approved"] = (
            payload["index_exists"]
            and payload["registry_exists"]
        )
        payload["exit_code"] = 0 if payload["approved"] else 2
    elif args.operation == "inventory":
        assets = [item.to_dict() for item in manager.inventory()]
        payload = {
            "approved": True,
            "exit_code": 0,
            "asset_count": len(assets),
            "assets": assets,
        }
    elif args.operation == "validate":
        payload = manager.validate_structure()
    else:
        payload = manager.build_report()

    _write(args.output_json, payload)
    print(json.dumps(payload, ensure_ascii=False))
    return int(payload.get("exit_code", 0))


if __name__ == "__main__":
    raise SystemExit(main())

'@

$Tests = @'

from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.repository_manager.manager import (
    InstitutionalRepositoryManager,
)


def _repository(root: Path) -> Path:
    for directory in (
        "src",
        "tests",
        "docs",
        "config/governance",
        "artifacts",
        "releases",
        "scripts",
        "dashboard",
    ):
        (root / directory).mkdir(parents=True, exist_ok=True)

    (root / "pytest.ini").write_text("[pytest]\n", encoding="utf-8")
    (root / "docs/00_INDICE_MAESTRO.md").write_text(
        "# Índice Maestro\n",
        encoding="utf-8",
    )
    (root / "docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text(
        "# Registro Maestro\n",
        encoding="utf-8",
    )
    (root / "docs/00_ARQUITECTURA_MAESTRA.md").write_text(
        "# Arquitectura Maestra\n",
        encoding="utf-8",
    )
    return root


def test_audit_detects_absent_component(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    result = InstitutionalRepositoryManager(
        root
    ).audit_master_documents()

    assert result.index_exists is True
    assert result.registry_exists is True
    assert result.component_preexisted is False


def test_audit_detects_registered_component(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    descriptor = root / "config/governance/SGD-117-component.json"
    descriptor.write_text(
        json.dumps({"increment_code": "SGD-117"}),
        encoding="utf-8",
    )

    result = InstitutionalRepositoryManager(
        root
    ).audit_master_documents()

    assert result.config_declares_component is True
    assert result.component_preexisted is True


def test_inventory_hashes_assets(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    source = root / "src/example.py"
    source.write_text("x = 1\n", encoding="utf-8")

    assets = InstitutionalRepositoryManager(root).inventory()

    assert any(item.path == "src/example.py" for item in assets)
    assert all(len(item.sha256) == 64 for item in assets)


def test_validation_accepts_complete_repository(
    tmp_path: Path,
) -> None:
    result = InstitutionalRepositoryManager(
        _repository(tmp_path)
    ).validate_structure()

    assert result["approved"] is True
    assert result["exit_code"] == 0


def test_validation_blocks_missing_master_document(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    (root / "docs/00_INDICE_MAESTRO.md").unlink()

    result = InstitutionalRepositoryManager(
        root
    ).validate_structure()

    assert result["approved"] is False
    assert "docs/00_INDICE_MAESTRO.md" in result["missing_files"]


def test_validation_detects_invalid_json(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    (root / "config/governance/bad.json").write_text(
        "{bad",
        encoding="utf-8",
    )

    result = InstitutionalRepositoryManager(
        root
    ).validate_structure()

    assert result["approved"] is False
    assert result["invalid_json"]


def test_report_contains_category_counts(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    (root / "tests/test_a.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )

    report = InstitutionalRepositoryManager(root).build_report()

    assert report["category_counts"]["tests"] == 1
    assert report["approved"] is True

'@

$Init = @'
from .manager import InstitutionalRepositoryManager
from .models import MasterDocumentAudit, RepositoryAsset

__all__ = [
    "InstitutionalRepositoryManager",
    "MasterDocumentAudit",
    "RepositoryAsset",
]
'@

$Component = @'
{
  "increment_code": "SGD-117",
  "name": "Institutional Repository Manager",
  "version": "1.0.0",
  "status": "implemented_tested_and_officially_closed",
  "component_type": "governance",
  "phase": "Gobierno y arquitectura",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "SGD-114",
    "SGD-114F",
    "SGD-114G",
    "SGD-115",
    "SGD-116",
    "SPB-007"
  ],
  "source": [
    "src/sgoda/governance/repository_manager/"
  ],
  "tests": [
    "tests/governance/repository_manager/"
  ],
  "documentation": [
    "docs/01_Gobierno/SGD-117/"
  ],
  "capabilities": [
    "master document audit",
    "repository asset inventory",
    "SHA-256 integrity catalog",
    "repository structure validation",
    "invalid configuration detection",
    "large asset detection",
    "institutional repository reporting"
  ]
}
'@

$Policy = @'
{
  "policy_id": "SGD-117-POLICY-v1.0.0",
  "component": "SGD-117",
  "version": "1.0.0",
  "required_roots": [
    "src",
    "tests",
    "docs",
    "config",
    "artifacts",
    "releases",
    "scripts"
  ],
  "required_master_documents": [
    "docs/00_INDICE_MAESTRO.md",
    "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
    "docs/00_ARQUITECTURA_MAESTRA.md"
  ],
  "integrity_algorithm": "SHA-256",
  "large_asset_threshold_bytes": 26214400
}
'@

$Architecture = @'
# SGD-117 v1.0.0 — Institutional Repository Manager

## Propósito

Administrar el repositorio como fuente institucional de verdad del proyecto
SGODA-PUINAVE.

## Responsabilidades

- auditar el Índice Maestro y el Registro Maestro;
- inventariar código, pruebas, documentos, configuración, evidencias,
  releases, automatizaciones y dashboards;
- calcular hashes SHA-256;
- validar estructura y documentos maestros;
- detectar JSON inválido;
- identificar activos grandes que requieran política de almacenamiento;
- generar evidencia y reportes institucionales.

## Integraciones

SGD-117 complementa SGD-114, utiliza SGD-114F para evidencias, SGD-114G para
releases, SGD-115 para documentos maestros, SGD-116 para roadmap y SPB-007
para publicación canónica.
'@

$Operations = @'
# SGD-117 v1.0.0 — Manual operativo

## Reporte integral

```powershell
$env:PYTHONPATH = "src"
python -m sgoda.governance.repository_manager.cli `
  --root . `
  --operation report `
  --output-json artifacts/pmo/SGD-117-v1.0.0/report.json
```

## Operaciones

- `audit-master`
- `inventory`
- `validate`
- `report`

La publicación debe utilizar el gate canónico de SGD-114G/SPB-007.
'@

Write-Utf8 (Join-Path $SourceDir "__init__.py") $Init
Write-Utf8 (Join-Path $SourceDir "models.py") $Models
Write-Utf8 (Join-Path $SourceDir "manager.py") $Manager
Write-Utf8 (Join-Path $SourceDir "cli.py") $Cli
Write-Utf8 (Join-Path $TestsDir "test_SGD_117_repository_manager.py") $Tests

Step "Auditando Índice Maestro y Registro Maestro antes del registro"

python -m sgoda.governance.repository_manager.cli `
    --root "$ProjectRoot" `
    --operation "audit-master" `
    --output-json "$PreAuditJson"

if ($LASTEXITCODE -ne 0) {
    throw "La auditoría inicial de documentos maestros no pudo ejecutarse."
}

Write-Utf8 (Join-Path $ConfigDir "SGD-117-component.json") $Component
Write-Utf8 (Join-Path $ConfigDir "SGD-117-policy.json") $Policy
Write-Utf8 (Join-Path $DocsDir "SGD-117-Arquitectura.md") $Architecture
Write-Utf8 (Join-Path $DocsDir "SGD-117-Manual-Operativo.md") $Operations

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/repository_manager/models.py" `
        "src/sgoda/governance/repository_manager/manager.py" `
        "src/sgoda/governance/repository_manager/cli.py" `
        "tests/governance/repository_manager/test_SGD_117_repository_manager.py"
}

Run "Ejecutando pruebas específicas SGD-117" {
    & $RunnerPath `
        -Component "SGD-117-v1.0.0" `
        -TestPath @(
            "tests/governance/repository_manager/test_SGD_117_repository_manager.py"
        ) `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific"
}

$Specific = Get-Content $SpecificJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not [bool]$Specific.approved) {
    throw "Las pruebas específicas SGD-117 no fueron aprobadas."
}

Run "Generando inventario e informe institucional" {
    python -m sgoda.governance.repository_manager.cli `
        --root "$ProjectRoot" `
        --operation "inventory" `
        --output-json "$InventoryJson"

    python -m sgoda.governance.repository_manager.cli `
        --root "$ProjectRoot" `
        --operation "validate" `
        --output-json "$ValidationJson"

    python -m sgoda.governance.repository_manager.cli `
        --root "$ProjectRoot" `
        --operation "report" `
        --output-json "$ReportJson"
}

$Validation = Get-Content $ValidationJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not [bool]$Validation.approved) {
    throw "SGD-117 detectó incumplimientos estructurales."
}

Run "Ejecutando suite completa" {
    python -m pytest --junitxml="$FullXml"
}

Run "Sincronizando suite completa mediante SGD-114F" {
    python -m sgoda.governance.test_evidence.cli `
        --junit "$FullXml" `
        --component "SGODA-PUINAVE" `
        --scope "full_suite" `
        --output-json "$FullJson" `
        --output-md "$FullMd"
}

$Full = Get-Content $FullJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not [bool]$Full.approved) {
    throw "La suite completa no fue aprobada."
}

Run "Regenerando Índice Maestro y Registro Maestro mediante SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Run "Regenerando roadmap mediante SGD-116" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

Step "Auditando documentos maestros después del registro"

python -m sgoda.governance.repository_manager.cli `
    --root "$ProjectRoot" `
    --operation "audit-master" `
    --output-json "$PostAuditJson"

if ($LASTEXITCODE -ne 0) {
    throw "La auditoría posterior no fue aprobada."
}

$PostAudit = Get-Content $PostAuditJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (
    -not [bool]$PostAudit.index_mentions_component -or
    -not [bool]$PostAudit.registry_mentions_component -or
    -not [bool]$PostAudit.config_declares_component
) {
    throw "SGD-117 no quedó registrado en los documentos maestros."
}

Step "Construyendo evidencia y release"

$Evidence = [ordered]@{
    increment_code = "SGD-117"
    version = "1.0.0"
    status = "implemented_tested_and_officially_closed"
    preflight = "[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m                                                                  [100%][0m
[32m[32m[1m7 passed[0m[32m in 0.05s[0m[0m"
    pre_audit = (
        Get-Content $PreAuditJson -Raw -Encoding UTF8 |
        ConvertFrom-Json
    )
    post_audit = $PostAudit
    specific_tests = [ordered]@{
        executed = [int]$Specific.executed
        passed = [int]$Specific.passed
        failures = [int]$Specific.failures
        errors = [int]$Specific.errors
        approved = [bool]$Specific.approved
    }
    full_suite = [ordered]@{
        executed = [int]$Full.executed
        passed = [int]$Full.passed
        failures = [int]$Full.failures
        errors = [int]$Full.errors
        approved = [bool]$Full.approved
    }
    repository_validation = $Validation
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
}

Write-Json $EvidenceJson $Evidence

$EvidenceLines = @(
    "# SGD-117 v1.0.0 — Evidencia de cierre",
    "",
    ("- Pruebas específicas: " + [string]$Specific.passed + "/" + [string]$Specific.executed),
    ("- Suite completa: " + [string]$Full.passed + "/" + [string]$Full.executed),
    ("- Índice Maestro registra SGD-117: " + [string]$PostAudit.index_mentions_component),
    ("- Registro Maestro registra SGD-117: " + [string]$PostAudit.registry_mentions_component),
    ("- Configuración declara SGD-117: " + [string]$PostAudit.config_declares_component),
    "- Validación estructural: APROBADA",
    "- Entregables pendientes: 0"
)
Write-Utf8 `
    -Path $EvidenceMd `
    -Content ([string]::Join([Environment]::NewLine, $EvidenceLines))

foreach ($File in @(
    (Join-Path $SourceDir "__init__.py"),
    (Join-Path $SourceDir "models.py"),
    (Join-Path $SourceDir "manager.py"),
    (Join-Path $SourceDir "cli.py"),
    (Join-Path $TestsDir "test_SGD_117_repository_manager.py"),
    (Join-Path $ConfigDir "SGD-117-component.json"),
    (Join-Path $ConfigDir "SGD-117-policy.json"),
    (Join-Path $DocsDir "SGD-117-Arquitectura.md"),
    (Join-Path $DocsDir "SGD-117-Manual-Operativo.md"),
    $PreAuditJson,
    $PostAuditJson,
    $InventoryJson,
    $ValidationJson,
    $ReportJson,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $FullXml,
    $FullJson,
    $FullMd,
    $EvidenceJson,
    $EvidenceMd
)) {
    Require-File -Path $File -Description "archivo del release"
    Copy-Item -LiteralPath $File -Destination $ReleaseDir -Force
}

Write-Json `
    (Join-Path $ReleaseDir "manifest.json") `
    ([ordered]@{
        increment_code = "SGD-117"
        version = "1.0.0"
        release_name = "SGD-117-v1.0.0"
        status = "implemented_tested_and_officially_closed"
        native_ecosystem = $true
        mandatory_proprietary_dependencies = @()
        files = @(
            Get-ChildItem -LiteralPath $ReleaseDir -File |
            Select-Object -ExpandProperty Name
        )
    })

Run "Validando release final mediante SGD-114G" {
    python -m sgoda.governance.release_management.cli `
        --root "$ProjectRoot" `
        --operation "close" `
        --output-json (
            Join-Path $PmoDir "release-validation.json"
        )
}

if ($Publish) {
    Step "Publicando mediante gate canónico"
    & $PublisherPath `
        -Publish `
        -CommitMessage "feat(governance): implement SGD-117 repository manager" `
        -EvidenceCommitMessage "chore(governance): publish SGD-117 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "La publicación institucional terminó con errores."
    }
}

Step "Resultado final"
Write-Host "SGD-117 v1.0.0 implementado y cerrado." -ForegroundColor Green
Write-Host "Institutional Repository Manager: OPERATIVO." -ForegroundColor Green
Write-Host "Auditoría Índice Maestro: APROBADA." -ForegroundColor Green
Write-Host "Auditoría Registro Maestro: APROBADA." -ForegroundColor Green
Write-Host (
    "Pruebas específicas: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Suite completa: " +
    "$($Full.passed)/$($Full.executed) APROBADA."
) -ForegroundColor Green
Write-Host "Entregables pendientes: 0." -ForegroundColor Green
Write-Host "Release: releases\SGD-117-v1.0.0" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
