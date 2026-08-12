from dataclasses import dataclass

@dataclass(frozen=True)
class DatabaseGovernanceControl:
    control_id: str
    passed: bool
    blocking: bool
    detail: str
