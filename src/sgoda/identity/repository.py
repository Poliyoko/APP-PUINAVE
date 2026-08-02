"""Repositorio persistente de identidades culturales."""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from .models import CulturalApproval, IdentityProfile


class IdentityRepository:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _load_payload(self) -> dict[str, Any]:
        if not self.path.is_file():
            return {
                "technical_identity": "SGODA-PUINAVE",
                "active_identity_id": None,
                "profiles": [],
            }

        return json.loads(self.path.read_text(encoding="utf-8"))

    @staticmethod
    def _profile_from_dict(payload: dict[str, Any]) -> IdentityProfile:
        approval_payload = dict(payload.get("approval", {}))
        return IdentityProfile(
            identity_id=str(payload["identity_id"]),
            technical_name=str(payload["technical_name"]),
            public_name=str(payload["public_name"]),
            app_name=str(payload["app_name"]),
            assistant_name=str(payload["assistant_name"]),
            puinave_name=payload.get("puinave_name"),
            spanish_name=str(payload["spanish_name"]),
            english_name=str(payload["english_name"]),
            slogan=str(payload["slogan"]),
            locale_default=str(payload.get("locale_default", "es")),
            logo_path=payload.get("logo_path"),
            icon_path=payload.get("icon_path"),
            active=bool(payload.get("active", False)),
            version=str(payload.get("version", "1.0.0")),
            approval=CulturalApproval(
                status=str(approval_payload.get("status", "pending")),
                approved_by=approval_payload.get("approved_by"),
                approval_date=approval_payload.get("approval_date"),
                approval_document=approval_payload.get(
                    "approval_document"
                ),
                community_scope=approval_payload.get("community_scope"),
                notes=approval_payload.get("notes"),
            ),
            metadata=dict(payload.get("metadata", {})),
        )

    def list_profiles(self) -> list[IdentityProfile]:
        payload = self._load_payload()
        return [
            self._profile_from_dict(item)
            for item in payload.get("profiles", [])
        ]

    def get(self, identity_id: str) -> IdentityProfile | None:
        for profile in self.list_profiles():
            if profile.identity_id == identity_id:
                return profile
        return None

    def active(self) -> IdentityProfile | None:
        payload = self._load_payload()
        active_id = payload.get("active_identity_id")
        return self.get(str(active_id)) if active_id else None

    def save_profiles(
        self,
        profiles: list[IdentityProfile],
        active_identity_id: str | None,
    ) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)

        payload = {
            "technical_identity": "SGODA-PUINAVE",
            "active_identity_id": active_identity_id,
            "profiles": [asdict(item) for item in profiles],
        }

        self.path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    def upsert(self, profile: IdentityProfile) -> None:
        profiles = self.list_profiles()
        active_id = (
            self._load_payload().get("active_identity_id")
        )

        replaced = False
        for index, existing in enumerate(profiles):
            if existing.identity_id == profile.identity_id:
                profiles[index] = profile
                replaced = True
                break

        if not replaced:
            profiles.append(profile)

        self.save_profiles(profiles, active_id)