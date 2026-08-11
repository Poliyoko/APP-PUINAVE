from dataclasses import dataclass, field
from typing import Any, Dict


@dataclass(frozen=True)
class CorrelatedEvent:
    correlation_id: str
    category: str
    severity: str
    event_count: int
    fingerprint: str
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class Control:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
