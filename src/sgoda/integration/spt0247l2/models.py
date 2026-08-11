from dataclasses import dataclass, field
from typing import Any, Dict


@dataclass(frozen=True)
class Control:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str


@dataclass(frozen=True)
class Finding:
    finding_id: str
    path: str
    category: str
    severity: str
    blocking: bool
    metadata: Dict[str, Any] = field(default_factory=dict)
