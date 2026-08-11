from dataclasses import dataclass, field
from typing import Any, Dict, FrozenSet


@dataclass(frozen=True)
class Identity:
    identity_id: str
    identity_type: str
    roles: FrozenSet[str]
    enabled: bool = True
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class AccessDecision:
    allowed: bool
    reason: str
    identity_id: str
    resource: str
    action: str


@dataclass(frozen=True)
class SecurityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
