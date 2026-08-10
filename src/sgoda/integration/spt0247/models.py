from dataclasses import dataclass, field
from typing import Any, Dict


@dataclass(frozen=True)
class SupplyChainSurface:
    path: str
    surface_type: str
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class SupplyChainControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
