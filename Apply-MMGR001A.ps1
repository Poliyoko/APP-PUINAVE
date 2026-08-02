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
        throw "El archivo ya existe: $Path. Revíselo antes de utilizar -Force."
    }

    $absolutePath = Join-Path (Get-Location) $Path
    [System.IO.File]::WriteAllText(
        $absolutePath,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if (-not (Test-Path ".git")) {
    throw "Ejecute este script desde la raíz del repositorio SGODA-PUINAVE."
}

$requiredRepositoryFile = "src/sgoda/pmo/repository/json_repository.py"
if (-not (Test-Path $requiredRepositoryFile)) {
    throw "No se encontró la arquitectura PMO esperada: $requiredRepositoryFile"
}

$moduleRoot = "src/sgoda/pmo/repository/mmgr"
$testRoot = "tests/pmo/repository/mmgr"
$evidenceRoot = "artifacts/pmo/SPB-005.2-F002A/MMGR-001A"

New-Item -ItemType Directory -Force -Path `
    $moduleRoot, $testRoot, $evidenceRoot | Out-Null

Write-Utf8NoBom "$moduleRoot/__init__.py" @'
"""Modelo de dominio de la Matriz Maestra de Gobierno del Repositorio."""

from .models import (
    Asset,
    AssetStatus,
    Domain,
    GitPolicy,
    RiskLevel,
    Traceability,
)

__all__ = [
    "Asset",
    "AssetStatus",
    "Domain",
    "GitPolicy",
    "RiskLevel",
    "Traceability",
]
'@

Write-Utf8NoBom "$moduleRoot/models.py" @'
"""Modelo de dominio para la Matriz Maestra de Gobierno del Repositorio.

Este módulo define entidades inmutables y serializables para representar
los activos gobernados por la MMGR, sus dominios, estados, políticas Git,
riesgos y relaciones de trazabilidad.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import PurePosixPath
import re
from typing import Any, Mapping

_ASSET_ID_PATTERN = re.compile(r"^MMGR-\d{6}$")


class StringEnum(str, Enum):
    """Enumeración basada en texto, compatible con serialización JSON."""


class Domain(StringEnum):
    """Dominios oficiales de gobierno del repositorio."""

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


class AssetStatus(StringEnum):
    """Estados permitidos durante el ciclo de vida de un activo."""

    PROPOSED = "proposed"
    IN_DEVELOPMENT = "in_development"
    VALIDATED = "validated"
    STABLE = "stable"
    HISTORICAL = "historical"
    DEPRECATED = "deprecated"
    EXPERIMENTAL = "experimental"


class GitPolicy(StringEnum):
    """Política de gestión del activo dentro de Git."""

    VERSIONED = "versioned"
    NOT_VERSIONED = "not_versioned"
    TEMPORARY = "temporary"
    GENERATED = "generated"


class RiskLevel(StringEnum):
    """Nivel de riesgo técnico o de gobierno del activo."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass(frozen=True, slots=True)
class Traceability:
    """Relaciones de trazabilidad de un activo MMGR."""

    spb: tuple[str, ...] = ()
    sgd: tuple[str, ...] = ()
    adr: tuple[str, ...] = ()
    tests: tuple[str, ...] = ()
    evidence: tuple[str, ...] = ()
    releases: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        for field_name in (
            "spb",
            "sgd",
            "adr",
            "tests",
            "evidence",
            "releases",
        ):
            values = tuple(getattr(self, field_name))
            if any(not isinstance(value, str) or not value.strip() for value in values):
                raise ValueError(
                    f"La colección de trazabilidad '{field_name}' "
                    "solo puede contener textos no vacíos."
                )
            if len(values) != len(set(values)):
                raise ValueError(
                    f"La colección de trazabilidad '{field_name}' "
                    "no puede contener valores duplicados."
                )
            object.__setattr__(self, field_name, values)

    @classmethod
    def from_dict(
        cls,
        payload: Mapping[str, Any] | None,
    ) -> "Traceability":
        """Construye trazabilidad desde un diccionario JSON-compatible."""

        data = payload or {}
        return cls(
            spb=tuple(data.get("spb", ())),
            sgd=tuple(data.get("sgd", ())),
            adr=tuple(data.get("adr", ())),
            tests=tuple(data.get("tests", ())),
            evidence=tuple(data.get("evidence", ())),
            releases=tuple(data.get("releases", ())),
        )

    def to_dict(self) -> dict[str, list[str]]:
        """Devuelve una representación JSON-compatible."""

        return {
            "spb": list(self.spb),
            "sgd": list(self.sgd),
            "adr": list(self.adr),
            "tests": list(self.tests),
            "evidence": list(self.evidence),
            "releases": list(self.releases),
        }


@dataclass(frozen=True, slots=True)
class Asset:
    """Activo gobernado por la MMGR."""

    asset_id: str
    name: str
    path: str
    domain: Domain
    status: AssetStatus
    git_policy: GitPolicy
    owner: str
    risk: RiskLevel = RiskLevel.MEDIUM
    traceability: Traceability = field(default_factory=Traceability)
    dependencies: tuple[str, ...] = ()
    tags: tuple[str, ...] = ()
    observations: str = ""

    def __post_init__(self) -> None:
        if not _ASSET_ID_PATTERN.fullmatch(self.asset_id):
            raise ValueError(
                f"Identificador MMGR inválido: {self.asset_id!r}. "
                "Se esperaba el formato MMGR-000001."
            )

        normalized_name = self.name.strip()
        if not normalized_name:
            raise ValueError("El nombre del activo no puede estar vacío.")

        normalized_owner = self.owner.strip()
        if not normalized_owner:
            raise ValueError("El propietario del activo no puede estar vacío.")

        normalized_path = self.path.replace("\\", "/").strip()
        path_parts = PurePosixPath(normalized_path).parts
        if not normalized_path:
            raise ValueError("La ruta del activo no puede estar vacía.")
        if normalized_path.startswith("/"):
            raise ValueError(
                "La ruta del activo debe ser relativa a la raíz del repositorio."
            )
        if ".." in path_parts:
            raise ValueError(
                "La ruta del activo no puede escapar de la raíz del repositorio."
            )

        dependencies = tuple(self.dependencies)
        if any(not _ASSET_ID_PATTERN.fullmatch(item) for item in dependencies):
            raise ValueError(
                "Todas las dependencias deben utilizar identificadores MMGR válidos."
            )
        if self.asset_id in dependencies:
            raise ValueError("Un activo no puede depender de sí mismo.")
        if len(dependencies) != len(set(dependencies)):
            raise ValueError("Las dependencias no pueden estar duplicadas.")

        tags = tuple(tag.strip() for tag in self.tags)
        if any(not tag for tag in tags):
            raise ValueError("Las etiquetas no pueden contener valores vacíos.")
        if len(tags) != len(set(tags)):
            raise ValueError("Las etiquetas no pueden estar duplicadas.")

        object.__setattr__(self, "name", normalized_name)
        object.__setattr__(self, "owner", normalized_owner)
        object.__setattr__(self, "path", normalized_path)
        object.__setattr__(self, "dependencies", dependencies)
        object.__setattr__(self, "tags", tags)
        object.__setattr__(self, "observations", self.observations.strip())

    @classmethod
    def from_dict(cls, payload: Mapping[str, Any]) -> "Asset":
        """Construye un activo desde un diccionario JSON-compatible."""

        return cls(
            asset_id=str(payload["asset_id"]),
            name=str(payload["name"]),
            path=str(payload["path"]),
            domain=Domain(payload["domain"]),
            status=AssetStatus(payload["status"]),
            git_policy=GitPolicy(payload["git_policy"]),
            owner=str(payload["owner"]),
            risk=RiskLevel(payload.get("risk", RiskLevel.MEDIUM.value)),
            traceability=Traceability.from_dict(payload.get("traceability")),
            dependencies=tuple(payload.get("dependencies", ())),
            tags=tuple(payload.get("tags", ())),
            observations=str(payload.get("observations", "")),
        )

    def to_dict(self) -> dict[str, Any]:
        """Devuelve una representación JSON-compatible del activo."""

        payload = asdict(self)
        payload["domain"] = self.domain.value
        payload["status"] = self.status.value
        payload["git_policy"] = self.git_policy.value
        payload["risk"] = self.risk.value
        payload["traceability"] = self.traceability.to_dict()
        payload["dependencies"] = list(self.dependencies)
        payload["tags"] = list(self.tags)
        return payload
'@

Write-Utf8NoBom "$testRoot/test_models.py" @'
"""Pruebas unitarias del modelo de dominio MMGR-001A."""

from __future__ import annotations

import pytest

from sgoda.pmo.repository.mmgr.models import (
    Asset,
    AssetStatus,
    Domain,
    GitPolicy,
    RiskLevel,
    Traceability,
)


def make_asset(**changes: object) -> Asset:
    payload: dict[str, object] = {
        "asset_id": "MMGR-000001",
        "name": "MMGR domain model",
        "path": "src/sgoda/pmo/repository/mmgr/models.py",
        "domain": Domain.PMO,
        "status": AssetStatus.IN_DEVELOPMENT,
        "git_policy": GitPolicy.VERSIONED,
        "owner": "PMO Digital / Repository Governance",
        "risk": RiskLevel.HIGH,
        "traceability": Traceability(
            spb=("SPB-005.2-F002A",),
            tests=("tests/pmo/repository/mmgr/test_models.py",),
        ),
        "dependencies": (),
        "tags": ("mmgr", "governance"),
        "observations": "Modelo inicial.",
    }
    payload.update(changes)
    return Asset(**payload)


def test_asset_accepts_valid_data() -> None:
    asset = make_asset()

    assert asset.asset_id == "MMGR-000001"
    assert asset.domain is Domain.PMO
    assert asset.status is AssetStatus.IN_DEVELOPMENT
    assert asset.git_policy is GitPolicy.VERSIONED
    assert asset.risk is RiskLevel.HIGH


def test_asset_normalizes_windows_path_and_text() -> None:
    asset = make_asset(
        name="  Modelo MMGR  ",
        path=r"src\sgoda\pmo\repository\mmgr\models.py",
        owner="  PMO Digital  ",
        observations="  Evidencia inicial.  ",
    )

    assert asset.name == "Modelo MMGR"
    assert asset.path == "src/sgoda/pmo/repository/mmgr/models.py"
    assert asset.owner == "PMO Digital"
    assert asset.observations == "Evidencia inicial."


@pytest.mark.parametrize(
    "asset_id",
    [
        "MMGR-1",
        "MMGR-00001",
        "MMGR-0000001",
        "mmgr-000001",
        "ASSET-000001",
        "",
    ],
)
def test_asset_rejects_invalid_identifier(asset_id: str) -> None:
    with pytest.raises(ValueError, match="Identificador MMGR inválido"):
        make_asset(asset_id=asset_id)


def test_asset_rejects_absolute_path() -> None:
    with pytest.raises(ValueError, match="relativa"):
        make_asset(path="/src/sgoda/file.py")


def test_asset_rejects_parent_path_escape() -> None:
    with pytest.raises(ValueError, match="escapar"):
        make_asset(path="../secrets.txt")


def test_asset_rejects_self_dependency() -> None:
    with pytest.raises(ValueError, match="depender de sí mismo"):
        make_asset(dependencies=("MMGR-000001",))


def test_asset_rejects_invalid_dependency_identifier() -> None:
    with pytest.raises(ValueError, match="dependencias"):
        make_asset(dependencies=("INVALID-001",))


def test_traceability_rejects_duplicate_values() -> None:
    with pytest.raises(ValueError, match="duplicados"):
        Traceability(spb=("SPB-005.2", "SPB-005.2"))


def test_asset_round_trip_dictionary() -> None:
    original = make_asset()
    restored = Asset.from_dict(original.to_dict())

    assert restored == original


def test_to_dict_is_json_compatible() -> None:
    payload = make_asset().to_dict()

    assert payload["domain"] == "pmo"
    assert payload["status"] == "in_development"
    assert payload["git_policy"] == "versioned"
    assert payload["risk"] == "high"
    assert payload["traceability"]["spb"] == ["SPB-005.2-F002A"]
    assert payload["tags"] == ["mmgr", "governance"]


def test_domain_catalog_contains_expected_values() -> None:
    assert Domain.KERNEL.value == "kernel"
    assert Domain.DOCUMENTATION.value == "documentation"
    assert Domain.EVIDENCE.value == "evidence"
    assert Domain.UNKNOWN.value == "unknown"


def test_asset_is_immutable() -> None:
    asset = make_asset()

    with pytest.raises(AttributeError):
        asset.name = "Modified"  # type: ignore[misc]
'@

$branch = git branch --show-current
$commit = git rev-parse HEAD
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"

Write-Utf8NoBom "$evidenceRoot/implementation-manifest.txt" @"
MMGR-001A — Modelo de dominio
Fecha: $timestamp
Rama: $branch
Commit base: $commit

Archivos creados:
- src/sgoda/pmo/repository/mmgr/__init__.py
- src/sgoda/pmo/repository/mmgr/models.py
- tests/pmo/repository/mmgr/test_models.py

Entidades implementadas:
- Asset
- Traceability
- Domain
- AssetStatus
- GitPolicy
- RiskLevel

Controles incluidos:
- Identificadores MMGR-000001
- Rutas relativas y normalizadas
- Inmutabilidad
- Dependencias válidas
- Prohibición de autorreferencia
- Unicidad de dependencias, etiquetas y trazabilidad
- Conversión desde/hacia diccionarios JSON-compatible

Archivos protegidos no modificados:
- src/sgoda/pmo/repository/json_repository.py
- src/sgoda/pmo/repository/__init__.py
- src/sgoda/pmo/__init__.py
"@

Write-Host ""
Write-Host "MMGR-001A creado correctamente." -ForegroundColor Green
Write-Host ""
Write-Host "Archivos existentes del PMO no fueron modificados." -ForegroundColor Green
Write-Host ""
Write-Host "Ejecute las pruebas:" -ForegroundColor Cyan
Write-Host '$env:PYTHONPATH = "src"'
Write-Host 'python -m pytest tests/pmo/repository/mmgr/test_models.py -q'
Write-Host ""
Write-Host "Luego ejecute la regresión PMO:" -ForegroundColor Cyan
Write-Host 'python -m pytest tests/test_pmo_governance_platform.py -q'
Write-Host 'python -m pytest tests/test_spb_005_1_foundation_runtime.py tests/test_spb_005_2_platform_kernel.py -q'
Write-Host ""
Write-Host "Finalmente revise:" -ForegroundColor Cyan
Write-Host 'git status --short --untracked-files=all'
