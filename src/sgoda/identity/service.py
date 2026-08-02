"""Servicio de gobierno de identidad cultural."""

from __future__ import annotations

import json
import re
import uuid
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

from .models import CulturalApproval, IdentityChange, IdentityProfile
from .repository import IdentityRepository


APPROVED_STATUSES = {"approved", "active"}
IDENTITY_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{2,63}$")


class IdentityGovernanceError(ValueError):
    pass


class IdentityService:
    def __init__(
        self,
        *,
        repository: IdentityRepository,
        history_path: str | Path,
    ) -> None:
        self.repository = repository
        self.history_path = Path(history_path)

    @staticmethod
    def validate(profile: IdentityProfile) -> list[str]:
        errors: list[str] = []

        if not IDENTITY_PATTERN.fullmatch(profile.identity_id):
            errors.append("identity_id no cumple la nomenclatura.")

        if profile.technical_name != "SGODA-PUINAVE":
            errors.append(
                "La identidad técnica debe permanecer SGODA-PUINAVE."
            )

        for field_name, value in {
            "public_name": profile.public_name,
            "app_name": profile.app_name,
            "assistant_name": profile.assistant_name,
            "spanish_name": profile.spanish_name,
            "english_name": profile.english_name,
            "slogan": profile.slogan,
        }.items():
            if not str(value).strip():
                errors.append(f"{field_name} no puede estar vacío.")

        if profile.puinave_name:
            if profile.approval.status not in APPROVED_STATUSES:
                errors.append(
                    "Un nombre Puinave no puede activarse sin aprobación."
                )
            if not profile.approval.approved_by:
                errors.append("Falta la autoridad que aprobó el nombre.")
            if not profile.approval.approval_date:
                errors.append("Falta la fecha de aprobación.")
            if not profile.approval.approval_document:
                errors.append("Falta el acta o documento de aprobación.")

        return errors

    def register(self, profile: IdentityProfile) -> IdentityProfile:
        errors = self.validate(profile)
        if errors:
            raise IdentityGovernanceError(" | ".join(errors))

        self.repository.upsert(profile)
        return profile

    def activate(
        self,
        identity_id: str,
        *,
        changed_by: str,
        reason: str,
    ) -> IdentityProfile:
        profile = self.repository.get(identity_id)
        if profile is None:
            raise IdentityGovernanceError(
                f"No existe la identidad: {identity_id}"
            )

        errors = self.validate(profile)
        if errors:
            raise IdentityGovernanceError(" | ".join(errors))

        profiles = self.repository.list_profiles()
        previous = self.repository.active()

        for item in profiles:
            item.active = item.identity_id == identity_id

        self.repository.save_profiles(profiles, identity_id)

        event = IdentityChange(
            event_id=f"IDENTITY-{uuid.uuid4().hex.upper()}",
            occurred_at_utc=datetime.now(timezone.utc).isoformat(),
            previous_identity_id=(
                previous.identity_id if previous else None
            ),
            new_identity_id=identity_id,
            changed_by=changed_by,
            reason=reason,
        )
        self._append_history(event)

        active = self.repository.get(identity_id)
        if active is None:
            raise IdentityGovernanceError(
                "No fue posible recuperar la identidad activada."
            )
        return active

    def _append_history(self, event: IdentityChange) -> None:
        self.history_path.parent.mkdir(parents=True, exist_ok=True)
        with self.history_path.open("a", encoding="utf-8") as stream:
            stream.write(
                json.dumps(asdict(event), ensure_ascii=False) + "\n"
            )

    def create_pending_puinave_proposal(
        self,
        *,
        identity_id: str,
        proposed_name: str,
        proposed_by: str,
    ) -> IdentityProfile:
        return IdentityProfile(
            identity_id=identity_id,
            technical_name="SGODA-PUINAVE",
            public_name=proposed_name,
            app_name=proposed_name,
            assistant_name=f"Asistente {proposed_name}",
            puinave_name=None,
            spanish_name="Plataforma Digital Puinave",
            english_name="Puinave Digital Platform",
            slogan="Tecnología para preservar la memoria del pueblo Puinave.",
            locale_default="es",
            approval=CulturalApproval(
                status="pending",
                notes=(
                    "Propuesta pendiente de validación lingüística, "
                    f"cultural y comunitaria. Propuesta por {proposed_by}."
                ),
            ),
        )