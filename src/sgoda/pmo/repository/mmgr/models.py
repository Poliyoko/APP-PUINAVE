"""Modelo de dominio para la Matriz Maestra de Gobierno del Repositorio.

Este mÃ³dulo define entidades inmutables y serializables para representar
los activos gobernados por la MMGR, sus dominios, estados, polÃ­ticas Git,
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
    """EnumeraciÃ³n basada en texto, compatible con serializaciÃ³n JSON."""


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
    """PolÃ­tica de gestiÃ³n del activo dentro de Git."""

    VERSIONED = "versioned"
    NOT_VERSIONED = "not_versioned"
    TEMPORARY = "temporary"
    GENERATED = "generated"


class RiskLevel(StringEnum):
    """Nivel de riesgo tÃ©cnico o de gobierno del activo."""

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
                    f"La colecciÃ³n de trazabilidad '{field_name}' "
                    "solo puede contener textos no vacÃ­os."
                )
            if len(values) != len(set(values)):
                raise ValueError(
                    f"La colecciÃ³n de trazabilidad '{field_name}' "
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
        """Devuelve una representaciÃ³n JSON-compatible."""

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
                f"Identificador MMGR invÃ¡lido: {self.asset_id!r}. "
                "Se esperaba el formato MMGR-000001."
            )

        normalized_name = self.name.strip()
        if not normalized_name:
            raise ValueError("El nombre del activo no puede estar vacÃ­o.")

        normalized_owner = self.owner.strip()
        if not normalized_owner:
            raise ValueError("El propietario del activo no puede estar vacÃ­o.")

        normalized_path = self.path.replace("\\", "/").strip()
        path_parts = PurePosixPath(normalized_path).parts
        if not normalized_path:
            raise ValueError("La ruta del activo no puede estar vacÃ­a.")
        if normalized_path.startswith("/"):
            raise ValueError(
                "La ruta del activo debe ser relativa a la raÃ­z del repositorio."
            )
        if ".." in path_parts:
            raise ValueError(
                "La ruta del activo no puede escapar de la raÃ­z del repositorio."
            )

        dependencies = tuple(self.dependencies)
        if any(not _ASSET_ID_PATTERN.fullmatch(item) for item in dependencies):
            raise ValueError(
                "Todas las dependencias deben utilizar identificadores MMGR vÃ¡lidos."
            )
        if self.asset_id in dependencies:
            raise ValueError("Un activo no puede depender de sÃ­ mismo.")
        if len(dependencies) != len(set(dependencies)):
            raise ValueError("Las dependencias no pueden estar duplicadas.")

        tags = tuple(tag.strip() for tag in self.tags)
        if any(not tag for tag in tags):
            raise ValueError("Las etiquetas no pueden contener valores vacÃ­os.")
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
        """Devuelve una representaciÃ³n JSON-compatible del activo."""

        payload = asdict(self)
        payload["domain"] = self.domain.value
        payload["status"] = self.status.value
        payload["git_policy"] = self.git_policy.value
        payload["risk"] = self.risk.value
        payload["traceability"] = self.traceability.to_dict()
        payload["dependencies"] = list(self.dependencies)
        payload["tags"] = list(self.tags)
        return payload