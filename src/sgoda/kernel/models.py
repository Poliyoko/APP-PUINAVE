"""Modelos internos del SGODA Platform Kernel."""

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class ModuleDescriptor:
    """Describe un módulo registrado en la plataforma."""

    name: str
    code: str
    version: str
    status: str
    description: str
    enabled: bool = True
    capabilities: tuple[str, ...] = field(default_factory=tuple)
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        """Convierte el descriptor en un diccionario serializable."""

        data = asdict(self)
        data["capabilities"] = list(self.capabilities)
        return data
