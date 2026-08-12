from dataclasses import dataclass


@dataclass(frozen=True)
class RiskControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
