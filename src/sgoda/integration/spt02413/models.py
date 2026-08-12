from dataclasses import dataclass


@dataclass(frozen=True)
class ContinuityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
