from dataclasses import dataclass, field
from typing import Any, Dict

@dataclass(frozen=True)
class ClientSurface:
    path: str
    kind: str
    production_scope: bool
    metadata: Dict[str, Any] = field(default_factory=dict)

@dataclass(frozen=True)
class ClientSecurityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str
