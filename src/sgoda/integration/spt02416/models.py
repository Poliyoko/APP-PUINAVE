from dataclasses import dataclass
@dataclass(frozen=True)
class DatabaseControl:
    control_id: str
    passed: bool
    blocking: bool
    detail: str
