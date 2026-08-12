from dataclasses import dataclass, asdict

@dataclass(frozen=True)
class RecertificationRecord:
    domain: str
    decision: str
    source: str

    def to_dict(self):
        return asdict(self)
