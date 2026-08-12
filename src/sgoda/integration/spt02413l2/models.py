from dataclasses import dataclass

@dataclass(frozen=True)
class RecoveryControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str
