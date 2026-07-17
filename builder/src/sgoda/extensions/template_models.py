"""Modelos especializados del ecosistema avanzado de plantillas."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class TemplateVariable:
    """Variable declarada por una plantilla."""

    name: str
    required: bool = False
    default: str | None = None
    description: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class TemplateMetadata:
    """Metadatos normalizados de una plantilla SGODA."""

    name: str
    version: str
    builder_requires: str
    description: str
    render_root: str
    variables: tuple[TemplateVariable, ...] = ()
    dependencies: dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            **asdict(self),
            "variables": [item.to_dict() for item in self.variables],
            "dependencies": dict(self.dependencies),
        }


@dataclass(frozen=True, slots=True)
class TemplateStateResult:
    """Resultado de habilitar o deshabilitar una plantilla."""

    name: str
    enabled: bool
    status: str
    changed: bool

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
