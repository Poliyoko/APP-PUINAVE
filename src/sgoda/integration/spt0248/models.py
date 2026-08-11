from dataclasses import dataclass, field
from typing import Any, Dict


@dataclass(frozen=True)
class SecurityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str


@dataclass(frozen=True)
class IncidentRecord:
    incident_id: str
    severity: str
    status: str
    source: str
    fingerprint: str
    metadata: Dict[str, Any] = field(default_factory=dict)
