param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if ((Test-Path $Path) -and -not $Force) {
        throw "El archivo ya existe: $Path. Use -Force solo después de revisarlo."
    }

    $absolute = Join-Path (Get-Location) $Path
    [System.IO.File]::WriteAllText(
        $absolute,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if (-not (Test-Path ".git")) {
    throw "Ejecute este script desde la raíz del repositorio SGODA-PUINAVE."
}

$branch = git branch --show-current
$commit = git rev-parse HEAD

$moduleRoot = "src/sgoda/pmo/repository"
$schemaRoot = "$moduleRoot/schemas"
$dataRoot = "data/mmgr"
$testRoot = "tests/pmo/repository"
$evidenceRoot = "artifacts/pmo/SPB-005.2-F002A/MMGR-001"

New-Item -ItemType Directory -Force -Path `
    $moduleRoot, $schemaRoot, $dataRoot, $testRoot, $evidenceRoot | Out-Null

Write-Utf8NoBom "$moduleRoot/__init__.py" @'
"""Repository governance capabilities for SGODA-PUINAVE."""

from .mmgr_models import (
    Asset,
    AssetStatus,
    AssetType,
    Domain,
    GitPolicy,
    RiskLevel,
    Traceability,
)
from .mmgr_repository import MMGRRepository
from .mmgr_service import MMGRService
from .mmgr_validator import MMGRValidator, ValidationFinding, ValidationReport

__all__ = [
    "Asset",
    "AssetStatus",
    "AssetType",
    "Domain",
    "GitPolicy",
    "RiskLevel",
    "Traceability",
    "MMGRRepository",
    "MMGRService",
    "MMGRValidator",
    "ValidationFinding",
    "ValidationReport",
]
'@

Write-Utf8NoBom "$moduleRoot/mmgr_models.py" @'
"""Domain model for the Matriz Maestra de Gobierno del Repositorio."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import PurePosixPath
import re
from typing import Any

_ASSET_ID_PATTERN = re.compile(r"^MMGR-\d{6}$")


class StrEnum(str, Enum):
    """Enum serializable como texto JSON."""


class Domain(StrEnum):
    KERNEL = "kernel"
    API = "api"
    CORE = "core"
    PMO = "pmo"
    BUILDER = "builder"
    QA = "qa"
    DOCUMENTATION = "documentation"
    EVIDENCE = "evidence"
    AUTOMATION = "automation"
    CONFIGURATION = "configuration"
    DATA = "data"
    UNKNOWN = "unknown"


class AssetType(StrEnum):
    SOURCE_CODE = "source_code"
    TEST = "test"
    DOCUMENT = "document"
    EVIDENCE = "evidence"
    SCRIPT = "script"
    CONFIGURATION = "configuration"
    TEMPLATE = "template"
    DATA = "data"
    REPORT = "report"
    DIRECTORY = "directory"


class AssetStatus(StrEnum):
    PROPOSED = "proposed"
    IN_DEVELOPMENT = "in_development"
    VALIDATED = "validated"
    STABLE = "stable"
    HISTORICAL = "historical"
    DEPRECATED = "deprecated"
    EXPERIMENTAL = "experimental"


class GitPolicy(StrEnum):
    VERSIONED = "versioned"
    NOT_VERSIONED = "not_versioned"
    TEMPORARY = "temporary"
    GENERATED = "generated"


class RiskLevel(StrEnum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass(frozen=True, slots=True)
class Traceability:
    spb: tuple[str, ...] = ()
    sgd: tuple[str, ...] = ()
    adr: tuple[str, ...] = ()
    tests: tuple[str, ...] = ()
    evidence: tuple[str, ...] = ()
    releases: tuple[str, ...] = ()

    @classmethod
    def from_dict(cls, payload: dict[str, Any] | None) -> "Traceability":
        payload = payload or {}
        return cls(
            spb=tuple(payload.get("spb", ())),
            sgd=tuple(payload.get("sgd", ())),
            adr=tuple(payload.get("adr", ())),
            tests=tuple(payload.get("tests", ())),
            evidence=tuple(payload.get("evidence", ())),
            releases=tuple(payload.get("releases", ())),
        )


@dataclass(frozen=True, slots=True)
class Asset:
    asset_id: str
    name: str
    path: str
    domain: Domain
    owner: str
    asset_type: AssetType
    status: AssetStatus
    git_policy: GitPolicy
    risk: RiskLevel = RiskLevel.MEDIUM
    traceability: Traceability = field(default_factory=Traceability)
    dependencies: tuple[str, ...] = ()
    tags: tuple[str, ...] = ()
    observations: str = ""

    def __post_init__(self) -> None:
        if not _ASSET_ID_PATTERN.fullmatch(self.asset_id):
            raise ValueError(
                f"Identificador MMGR inválido: {self.asset_id!r}; "
                "se esperaba MMGR- seguido de seis dígitos."
            )
        if not self.name.strip():
            raise ValueError("El nombre del activo no puede estar vacío.")
        if not self.owner.strip():
            raise ValueError("El propietario del activo no puede estar vacío.")

        normalized_path = self.path.replace("\\", "/").strip()
        if not normalized_path or normalized_path.startswith("/"):
            raise ValueError("La ruta debe ser relativa a la raíz del repositorio.")
        if ".." in PurePosixPath(normalized_path).parts:
            raise ValueError("La ruta no puede escapar de la raíz del repositorio.")

        object.__setattr__(self, "path", normalized_path)
        object.__setattr__(self, "dependencies", tuple(self.dependencies))
        object.__setattr__(self, "tags", tuple(self.tags))

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "Asset":
        return cls(
            asset_id=payload["asset_id"],
            name=payload["name"],
            path=payload["path"],
            domain=Domain(payload["domain"]),
            owner=payload["owner"],
            asset_type=AssetType(payload["asset_type"]),
            status=AssetStatus(payload["status"]),
            git_policy=GitPolicy(payload["git_policy"]),
            risk=RiskLevel(payload.get("risk", RiskLevel.MEDIUM.value)),
            traceability=Traceability.from_dict(payload.get("traceability")),
            dependencies=tuple(payload.get("dependencies", ())),
            tags=tuple(payload.get("tags", ())),
            observations=payload.get("observations", ""),
        )

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["domain"] = self.domain.value
        payload["asset_type"] = self.asset_type.value
        payload["status"] = self.status.value
        payload["git_policy"] = self.git_policy.value
        payload["risk"] = self.risk.value
        payload["dependencies"] = list(self.dependencies)
        payload["tags"] = list(self.tags)
        return payload
'@

Write-Utf8NoBom "$schemaRoot/mmgr.schema.json" @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://sgoda-puinave.local/schemas/mmgr.schema.json",
  "title": "MMGR Repository Governance Catalog",
  "type": "object",
  "required": ["schema_version", "repository", "assets"],
  "additionalProperties": false,
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "1.0.0"
    },
    "repository": {
      "type": "string",
      "minLength": 1
    },
    "generated_at": {
      "type": ["string", "null"],
      "format": "date-time"
    },
    "assets": {
      "type": "array",
      "items": { "$ref": "#/$defs/asset" }
    }
  },
  "$defs": {
    "stringList": {
      "type": "array",
      "uniqueItems": true,
      "items": { "type": "string", "minLength": 1 }
    },
    "traceability": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "spb": { "$ref": "#/$defs/stringList" },
        "sgd": { "$ref": "#/$defs/stringList" },
        "adr": { "$ref": "#/$defs/stringList" },
        "tests": { "$ref": "#/$defs/stringList" },
        "evidence": { "$ref": "#/$defs/stringList" },
        "releases": { "$ref": "#/$defs/stringList" }
      }
    },
    "asset": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "asset_id", "name", "path", "domain", "owner",
        "asset_type", "status", "git_policy"
      ],
      "properties": {
        "asset_id": {
          "type": "string",
          "pattern": "^MMGR-[0-9]{6}$"
        },
        "name": { "type": "string", "minLength": 1 },
        "path": {
          "type": "string",
          "minLength": 1,
          "pattern": "^(?!/)(?!.*(?:^|/)\\.\\.(?:/|$)).+$"
        },
        "domain": {
          "enum": [
            "kernel", "api", "core", "pmo", "builder", "qa",
            "documentation", "evidence", "automation",
            "configuration", "data", "unknown"
          ]
        },
        "owner": { "type": "string", "minLength": 1 },
        "asset_type": {
          "enum": [
            "source_code", "test", "document", "evidence", "script",
            "configuration", "template", "data", "report", "directory"
          ]
        },
        "status": {
          "enum": [
            "proposed", "in_development", "validated", "stable",
            "historical", "deprecated", "experimental"
          ]
        },
        "git_policy": {
          "enum": ["versioned", "not_versioned", "temporary", "generated"]
        },
        "risk": {
          "enum": ["low", "medium", "high", "critical"],
          "default": "medium"
        },
        "traceability": { "$ref": "#/$defs/traceability" },
        "dependencies": { "$ref": "#/$defs/stringList" },
        "tags": { "$ref": "#/$defs/stringList" },
        "observations": { "type": "string" }
      }
    }
  }
}
'@

Write-Utf8NoBom "$moduleRoot/mmgr_repository.py" @'
"""Persistencia y consulta del catálogo MMGR en JSON."""

from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile
from typing import Iterable

from .mmgr_models import Asset


class MMGRRepository:
    SCHEMA_VERSION = "1.0.0"

    def __init__(self, catalog_path: str | Path) -> None:
        self.catalog_path = Path(catalog_path)

    def load_document(self) -> dict:
        if not self.catalog_path.exists():
            return {
                "schema_version": self.SCHEMA_VERSION,
                "repository": "SGODA-PUINAVE",
                "generated_at": None,
                "assets": [],
            }

        try:
            with self.catalog_path.open("r", encoding="utf-8") as handle:
                payload = json.load(handle)
        except json.JSONDecodeError as exc:
            raise ValueError(
                f"Catálogo MMGR inválido en {self.catalog_path}: {exc}"
            ) from exc

        if not isinstance(payload, dict):
            raise ValueError("La raíz del catálogo MMGR debe ser un objeto JSON.")
        return payload

    def load_assets(self) -> list[Asset]:
        document = self.load_document()
        raw_assets = document.get("assets", [])
        if not isinstance(raw_assets, list):
            raise ValueError("El campo 'assets' debe ser una lista.")
        return [Asset.from_dict(item) for item in raw_assets]

    def save_assets(
        self,
        assets: Iterable[Asset],
        *,
        repository: str = "SGODA-PUINAVE",
        generated_at: str | None = None,
    ) -> None:
        ordered = sorted(assets, key=lambda asset: asset.asset_id)
        self.save_document(
            {
                "schema_version": self.SCHEMA_VERSION,
                "repository": repository,
                "generated_at": generated_at,
                "assets": [asset.to_dict() for asset in ordered],
            }
        )

    def save_document(self, document: dict) -> None:
        self.catalog_path.parent.mkdir(parents=True, exist_ok=True)
        serialized = json.dumps(
            document,
            ensure_ascii=False,
            indent=2,
        ) + "\n"

        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{self.catalog_path.name}.",
            suffix=".tmp",
            dir=self.catalog_path.parent,
            text=True,
        )
        try:
            with os.fdopen(
                descriptor,
                "w",
                encoding="utf-8",
                newline="\n",
            ) as handle:
                handle.write(serialized)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary_name, self.catalog_path)
        except Exception:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass
            raise
'@

Write-Utf8NoBom "$moduleRoot/mmgr_service.py" @'
"""Servicios de negocio para gobierno, consulta e impacto MMGR."""

from __future__ import annotations

from collections import defaultdict, deque

from .mmgr_models import Asset, Domain
from .mmgr_repository import MMGRRepository


class MMGRService:
    def __init__(self, repository: MMGRRepository) -> None:
        self.repository = repository

    def list_assets(self) -> list[Asset]:
        return self.repository.load_assets()

    def get_asset(self, asset_id: str) -> Asset | None:
        return next(
            (asset for asset in self.list_assets() if asset.asset_id == asset_id),
            None,
        )

    def find_by_path(self, path: str) -> Asset | None:
        normalized = path.replace("\\", "/").strip("/")
        return next(
            (asset for asset in self.list_assets() if asset.path == normalized),
            None,
        )

    def search(
        self,
        *,
        text: str | None = None,
        domain: Domain | None = None,
        deliverable: str | None = None,
        owner: str | None = None,
    ) -> list[Asset]:
        needle = text.casefold() if text else None
        owner_needle = owner.casefold() if owner else None
        results: list[Asset] = []

        for asset in self.list_assets():
            if domain is not None and asset.domain is not domain:
                continue
            if owner_needle and owner_needle not in asset.owner.casefold():
                continue
            if needle:
                haystack = " ".join(
                    [asset.asset_id, asset.name, asset.path, asset.owner, *asset.tags]
                ).casefold()
                if needle not in haystack:
                    continue
            if deliverable and deliverable not in self._deliverables(asset):
                continue
            results.append(asset)

        return sorted(results, key=lambda item: item.asset_id)

    def traceability_for(self, asset_id: str) -> dict[str, tuple[str, ...]]:
        asset = self.get_asset(asset_id)
        if asset is None:
            raise KeyError(f"Activo MMGR no encontrado: {asset_id}")

        trace = asset.traceability
        return {
            "spb": trace.spb,
            "sgd": trace.sgd,
            "adr": trace.adr,
            "tests": trace.tests,
            "evidence": trace.evidence,
            "releases": trace.releases,
        }

    def impact_analysis(self, asset_id: str) -> list[Asset]:
        assets = self.list_assets()
        by_id = {asset.asset_id: asset for asset in assets}
        reverse_dependencies: dict[str, set[str]] = defaultdict(set)

        for asset in assets:
            for dependency in asset.dependencies:
                reverse_dependencies[dependency].add(asset.asset_id)

        impacted_ids: set[str] = set()
        queue: deque[str] = deque([asset_id])

        while queue:
            current = queue.popleft()
            for dependent in reverse_dependencies.get(current, set()):
                if dependent not in impacted_ids:
                    impacted_ids.add(dependent)
                    queue.append(dependent)

        return sorted(
            (by_id[item] for item in impacted_ids if item in by_id),
            key=lambda item: item.asset_id,
        )

    @staticmethod
    def _deliverables(asset: Asset) -> set[str]:
        trace = asset.traceability
        return (
            set(trace.spb)
            | set(trace.sgd)
            | set(trace.adr)
            | set(trace.releases)
        )
'@

Write-Utf8NoBom "$moduleRoot/mmgr_validator.py" @'
"""Validación de integridad y gobierno del catálogo MMGR."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Iterable

from .mmgr_models import Asset, GitPolicy


@dataclass(frozen=True, slots=True)
class ValidationFinding:
    code: str
    severity: str
    message: str
    asset_id: str | None = None
    path: str | None = None


@dataclass(frozen=True, slots=True)
class ValidationReport:
    findings: tuple[ValidationFinding, ...]

    @property
    def is_valid(self) -> bool:
        return not any(item.severity == "error" for item in self.findings)

    @property
    def error_count(self) -> int:
        return sum(item.severity == "error" for item in self.findings)

    @property
    def warning_count(self) -> int:
        return sum(item.severity == "warning" for item in self.findings)


class MMGRValidator:
    _REFERENCE_PATTERN = re.compile(
        r"^(?:SPB-\d{3}(?:\.\d+)*(?:-[A-Z0-9]+)*|"
        r"SGD-\d{3}(?:-[A-Za-z0-9._-]+)?|"
        r"ADR-\d{3}(?:-[A-Za-z0-9._-]+)?|"
        r"v\d+\.\d+(?:\.\d+)?(?:-[A-Za-z0-9._-]+)?)$"
    )

    def validate(
        self,
        assets: Iterable[Asset],
        *,
        repository_root: str | Path | None = None,
    ) -> ValidationReport:
        materialized = list(assets)
        findings: list[ValidationFinding] = []
        by_id: dict[str, Asset] = {}
        by_path: dict[str, Asset] = {}

        for asset in materialized:
            if asset.asset_id in by_id:
                findings.append(
                    ValidationFinding(
                        "MMGR-DUPLICATE-ID",
                        "error",
                        f"Identificador duplicado: {asset.asset_id}",
                        asset_id=asset.asset_id,
                        path=asset.path,
                    )
                )
            else:
                by_id[asset.asset_id] = asset

            if asset.path in by_path:
                findings.append(
                    ValidationFinding(
                        "MMGR-DUPLICATE-PATH",
                        "error",
                        f"Ruta gobernada por más de un activo: {asset.path}",
                        asset_id=asset.asset_id,
                        path=asset.path,
                    )
                )
            else:
                by_path[asset.path] = asset

            for dependency in asset.dependencies:
                if dependency == asset.asset_id:
                    findings.append(
                        ValidationFinding(
                            "MMGR-SELF-DEPENDENCY",
                            "error",
                            "Un activo no puede depender de sí mismo.",
                            asset_id=asset.asset_id,
                            path=asset.path,
                        )
                    )

            for reference in self._all_references(asset):
                if not self._REFERENCE_PATTERN.fullmatch(reference):
                    findings.append(
                        ValidationFinding(
                            "MMGR-INVALID-REFERENCE",
                            "warning",
                            f"Referencia no conforme: {reference}",
                            asset_id=asset.asset_id,
                            path=asset.path,
                        )
                    )

        known_ids = set(by_id)
        for asset in materialized:
            for dependency in asset.dependencies:
                if dependency not in known_ids:
                    findings.append(
                        ValidationFinding(
                            "MMGR-UNKNOWN-DEPENDENCY",
                            "error",
                            f"Dependencia no registrada: {dependency}",
                            asset_id=asset.asset_id,
                            path=asset.path,
                        )
                    )

        if repository_root is not None:
            root = Path(repository_root)
            for asset in materialized:
                if (
                    asset.git_policy == GitPolicy.VERSIONED
                    and not (root / asset.path).exists()
                ):
                    findings.append(
                        ValidationFinding(
                            "MMGR-MISSING-VERSIONED-ASSET",
                            "error",
                            "El activo versionable no existe en el repositorio.",
                            asset_id=asset.asset_id,
                            path=asset.path,
                        )
                    )

        return ValidationReport(tuple(findings))

    @staticmethod
    def _all_references(asset: Asset) -> tuple[str, ...]:
        trace = asset.traceability
        return trace.spb + trace.sgd + trace.adr + trace.releases
'@

Write-Utf8NoBom "$moduleRoot/mmgr_audit.py" @'
"""Puente de integración entre el Auditor del Repositorio y la MMGR."""

from __future__ import annotations

from dataclasses import asdict
from pathlib import Path

from .mmgr_repository import MMGRRepository
from .mmgr_validator import MMGRValidator


def audit_mmgr(
    repository_root: str | Path,
    catalog_path: str | Path = "data/mmgr/assets.json",
) -> dict:
    root = Path(repository_root).resolve()
    repository = MMGRRepository(root / catalog_path)
    assets = repository.load_assets()
    report = MMGRValidator().validate(
        assets,
        repository_root=root,
    )

    return {
        "check_id": "MMGR-REPOSITORY-GOVERNANCE",
        "status": "passed" if report.is_valid else "failed",
        "summary": {
            "assets": len(assets),
            "errors": report.error_count,
            "warnings": report.warning_count,
        },
        "findings": [asdict(item) for item in report.findings],
    }
'@

Write-Utf8NoBom "$dataRoot/assets.json" @'
{
  "schema_version": "1.0.0",
  "repository": "SGODA-PUINAVE",
  "generated_at": null,
  "assets": [
    {
      "asset_id": "MMGR-000001",
      "name": "MMGR domain model",
      "path": "src/sgoda/pmo/repository/mmgr_models.py",
      "domain": "pmo",
      "owner": "PMO Digital / Repository Governance",
      "asset_type": "source_code",
      "status": "in_development",
      "git_policy": "versioned",
      "risk": "high",
      "traceability": {
        "spb": ["SPB-005.2-F002A"],
        "sgd": [],
        "adr": [],
        "tests": ["tests/pmo/repository/test_mmgr_core.py"],
        "evidence": [],
        "releases": []
      },
      "dependencies": [],
      "tags": ["mmgr", "governance", "model"],
      "observations": "Registro inicial del núcleo MMGR."
    },
    {
      "asset_id": "MMGR-000002",
      "name": "MMGR JSON schema",
      "path": "src/sgoda/pmo/repository/schemas/mmgr.schema.json",
      "domain": "pmo",
      "owner": "PMO Digital / Repository Governance",
      "asset_type": "configuration",
      "status": "in_development",
      "git_policy": "versioned",
      "risk": "high",
      "traceability": {
        "spb": ["SPB-005.2-F002A"],
        "sgd": [],
        "adr": [],
        "tests": ["tests/pmo/repository/test_mmgr_core.py"],
        "evidence": [],
        "releases": []
      },
      "dependencies": ["MMGR-000001"],
      "tags": ["mmgr", "schema", "contract"],
      "observations": "Contrato oficial de la MMGR."
    }
  ]
}
'@

Write-Utf8NoBom "$testRoot/test_mmgr_core.py" @'
from __future__ import annotations

from pathlib import Path

import pytest

from sgoda.pmo.repository.mmgr_models import (
    Asset,
    AssetStatus,
    AssetType,
    Domain,
    GitPolicy,
    RiskLevel,
    Traceability,
)
from sgoda.pmo.repository.mmgr_repository import MMGRRepository
from sgoda.pmo.repository.mmgr_service import MMGRService
from sgoda.pmo.repository.mmgr_validator import MMGRValidator


def make_asset(
    asset_id: str = "MMGR-000001",
    path: str = "src/sgoda/core/example.py",
    dependencies: tuple[str, ...] = (),
) -> Asset:
    return Asset(
        asset_id=asset_id,
        name="Example",
        path=path,
        domain=Domain.CORE,
        owner="Core Runtime",
        asset_type=AssetType.SOURCE_CODE,
        status=AssetStatus.STABLE,
        git_policy=GitPolicy.VERSIONED,
        risk=RiskLevel.MEDIUM,
        traceability=Traceability(
            spb=("SPB-005.1",),
            tests=("tests/test_example.py",),
        ),
        dependencies=dependencies,
    )


def test_asset_normalizes_windows_path() -> None:
    asset = make_asset(path=r"src\sgoda\core\example.py")
    assert asset.path == "src/sgoda/core/example.py"


def test_asset_rejects_invalid_identifier() -> None:
    with pytest.raises(ValueError, match="Identificador MMGR inválido"):
        make_asset(asset_id="MMGR-1")


def test_repository_round_trip(tmp_path: Path) -> None:
    catalog = tmp_path / "assets.json"
    repository = MMGRRepository(catalog)
    repository.save_assets([make_asset()])
    assert repository.load_assets() == [make_asset()]


def test_validator_detects_duplicate_id_and_path() -> None:
    first = make_asset()
    second = make_asset()
    report = MMGRValidator().validate([first, second])

    codes = {finding.code for finding in report.findings}
    assert "MMGR-DUPLICATE-ID" in codes
    assert "MMGR-DUPLICATE-PATH" in codes
    assert not report.is_valid


def test_validator_detects_unknown_dependency() -> None:
    asset = make_asset(dependencies=("MMGR-999999",))
    report = MMGRValidator().validate([asset])

    assert any(
        finding.code == "MMGR-UNKNOWN-DEPENDENCY"
        for finding in report.findings
    )


def test_service_search_traceability_and_impact(tmp_path: Path) -> None:
    catalog = tmp_path / "assets.json"
    repository = MMGRRepository(catalog)
    first = make_asset()
    second = make_asset(
        asset_id="MMGR-000002",
        path="src/sgoda/api/example.py",
        dependencies=("MMGR-000001",),
    )
    repository.save_assets([first, second])
    service = MMGRService(repository)

    assert [item.asset_id for item in service.search(deliverable="SPB-005.1")] == [
        "MMGR-000001",
        "MMGR-000002",
    ]
    assert service.traceability_for("MMGR-000001")["spb"] == ("SPB-005.1",)
    assert [item.asset_id for item in service.impact_analysis("MMGR-000001")] == [
        "MMGR-000002"
    ]
'@

Write-Utf8NoBom "$evidenceRoot/implementation-manifest.txt" @"
MMGR-001 — Implementación del núcleo técnico
Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss K")
Rama: $branch
Commit base: $commit

Componentes creados:
- Modelo de dominio
- Esquema JSON Draft 2020-12
- Repositorio JSON con escritura atómica
- Servicio de consulta, trazabilidad e impacto
- Validador de integridad
- Puente de auditoría MMGR
- Catálogo semilla
- Pruebas unitarias

Decisión:
- No se modifica todavía el Auditor existente.
- La integración se realizará después de validar este núcleo.
"@

Write-Host ""
Write-Host "MMGR-001 creado correctamente." -ForegroundColor Green
Write-Host ""
Write-Host "Ejecute ahora:" -ForegroundColor Cyan
Write-Host '$env:PYTHONPATH = "src"'
Write-Host 'python -m pytest tests/pmo/repository/test_mmgr_core.py -q'
Write-Host 'python -m pytest tests/test_spb_005_1_foundation_runtime.py tests/test_spb_005_2_platform_kernel.py -q'
Write-Host 'git status --short --untracked-files=all'
