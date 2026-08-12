from dataclasses import dataclass

@dataclass(frozen=True)
class RiskRecord:
    risk_id: str
    title: str
    inherent_score: int
    residual_score: int
    priority: str
    treatment: str
    owner: str
    status: str
    exception: bool
    acceptance_required: bool
