from dataclasses import dataclass, asdict
from typing import List, Dict

@dataclass(frozen=True)
class RecertificationRecord:
    domain: str
    decision: str
    evidence: str

@dataclass(frozen=True)
class ClosureResult:
    status: str
    failed_controls: List[str]
    recertification_records: List[Dict[str, str]]
    evidence_records: int

    def to_dict(self):
        return asdict(self)
