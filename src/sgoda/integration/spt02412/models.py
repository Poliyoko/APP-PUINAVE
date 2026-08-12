from dataclasses import dataclass


@dataclass(frozen=True)
class InfrastructureControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
