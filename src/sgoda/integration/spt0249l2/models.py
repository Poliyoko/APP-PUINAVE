from dataclasses import dataclass, field
from typing import Any, Dict, FrozenSet


@dataclass(frozen=True)
class PrivilegedIdentity:
    identity_id: str
    identity_type: str
    roles: FrozenSet[str]
    owner: str
    enabled: bool = True
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class PrivilegeGrant:
    grant_id: str
    identity_id: str
    permission: str
    justification: str
    expires_at: str
    approved_by: str
    active: bool = False


@dataclass(frozen=True)
class Control:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
