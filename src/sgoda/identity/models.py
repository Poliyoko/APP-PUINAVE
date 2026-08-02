"""Modelos del Sistema de Identidad Cultural Configurable."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class CulturalApproval:
    status: str
    approved_by: str | None = None
    approval_date: str | None = None
    approval_document: str | None = None
    community_scope: str | None = None
    notes: str | None = None


@dataclass(slots=True)
class IdentityProfile:
    identity_id: str
    technical_name: str
    public_name: str
    app_name: str
    assistant_name: str
    puinave_name: str | None
    spanish_name: str
    english_name: str
    slogan: str
    locale_default: str
    logo_path: str | None = None
    icon_path: str | None = None
    active: bool = False
    version: str = "1.0.0"
    approval: CulturalApproval = field(
        default_factory=lambda: CulturalApproval(status="pending")
    )
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class IdentityChange:
    event_id: str
    occurred_at_utc: str
    previous_identity_id: str | None
    new_identity_id: str
    changed_by: str
    reason: str