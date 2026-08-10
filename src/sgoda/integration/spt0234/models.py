from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True)
class MultimediaResourcePlan:
    resource_id: str
    lexical_id: str
    resource_type: str
    language: str | None
    route: str
    provider_family: str
    status: str
    required: bool
    requires_human_validation: bool
    existing_resource_reused: bool
    metadata: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class MultimediaPlan:
    lexical_id: str
    puinave: str
    category_id: str | None
    plans: tuple[MultimediaResourcePlan, ...]
    automatic_external_calls: bool = False
    paid_api_allowed: bool = False
    next_component: str = "SPT-023.4-CAPA-2"

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": "SPT-023.4",
            "layer": "1",
            "lexical_id": self.lexical_id,
            "puinave": self.puinave,
            "category_id": self.category_id,
            "plans": [item.to_dict() for item in self.plans],
            "automatic_external_calls": self.automatic_external_calls,
            "paid_api_allowed": self.paid_api_allowed,
            "next_component": self.next_component,
        }
