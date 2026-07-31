from __future__ import annotations
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

@dataclass(frozen=True)
class RetentionPolicy:
    policy_id: str
    version: str
    description: str
    duration_days: int | None
    action_on_expiry: str
    permanent: bool = False
    priority: int = 100
    match: dict[str, Any] | None = None

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "RetentionPolicy":
        return cls(
            policy_id=data["policy_id"],
            version=data.get("version","1.0"),
            description=data.get("description",""),
            duration_days=data.get("duration_days"),
            action_on_expiry=data.get("action_on_expiry","review"),
            permanent=bool(data.get("permanent",False)),
            priority=int(data.get("priority",100)),
            match=dict(data.get("match",{})),
        )

class RetentionPolicyRepository:
    def __init__(self, path: Path) -> None:
        self.path=path

    def load(self) -> list[RetentionPolicy]:
        data=json.loads(self.path.read_text(encoding="utf-8"))
        policies=[RetentionPolicy.from_dict(item) for item in data.get("policies",[])]
        return sorted(policies,key=lambda item:item.priority)

    def get(self, policy_id: str) -> RetentionPolicy:
        for policy in self.load():
            if policy.policy_id==policy_id:
                return policy
        raise KeyError(f"No existe la polÃ­tica: {policy_id}")