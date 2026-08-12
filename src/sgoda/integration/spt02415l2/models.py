from dataclasses import dataclass
@dataclass(frozen=True)
class ApiControl:
    control_id: str
    passed: bool
    blocking: bool
    detail: str
