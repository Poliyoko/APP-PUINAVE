from dataclasses import dataclass
@dataclass(frozen=True)
class InfrastructureControl:
    control_id: str
    passed: bool
    blocking: bool
    detail: str
