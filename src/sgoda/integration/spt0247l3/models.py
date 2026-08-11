from dataclasses import dataclass
from typing import Any, Dict


@dataclass(frozen=True)
class ClosureControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str


@dataclass(frozen=True)
class ClosureEvidence:
    path: str
    sha256: str
    bytes: int
    metadata: Dict[str, Any]
