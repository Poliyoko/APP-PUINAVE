from dataclasses import dataclass
@dataclass(frozen=True)
class SecurityControl:
    control_id: str
    passed: bool
    blocking: bool
    detail: str
