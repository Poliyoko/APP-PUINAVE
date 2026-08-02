"""Gobernanza de activación de proveedores reales."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import AprobacionPiloto, DecisionPiloto


PROVIDER_SECRETS = {
    "openai-image": "OPENAI_API_KEY",
    "google-tts": "GOOGLE_APPLICATION_CREDENTIALS",
    "azure-speech": "AZURE_SPEECH_KEY",
}


def load_approval(path: str | Path) -> AprobacionPiloto:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))

    return AprobacionPiloto(
        approval_id=str(payload["approval_id"]),
        provider=str(payload["provider"]),
        approved_by=str(payload["approved_by"]),
        approved_at_utc=str(payload["approved_at_utc"]),
        expires_at_utc=str(payload["expires_at_utc"]),
        administrative_approved=bool(
            payload["administrative_approved"]
        ),
        cultural_approved=bool(payload["cultural_approved"]),
        privacy_approved=bool(payload["privacy_approved"]),
        budget_approved=bool(payload["budget_approved"]),
        live_calls_authorized=bool(
            payload["live_calls_authorized"]
        ),
        allowed_job_types=[
            str(item) for item in payload.get("allowed_job_types", [])
        ],
        max_jobs=int(payload.get("max_jobs", 0)),
        max_cost_usd=float(payload.get("max_cost_usd", 0.0)),
    )


def evaluate_activation(
    *,
    provider: str,
    requested_jobs: int,
    estimated_cost_usd: float,
    job_types: list[str],
    approval: AprobacionPiloto | None,
    dry_run: bool,
) -> DecisionPiloto:
    reasons: list[str] = []

    if dry_run:
        return DecisionPiloto(
            allowed=True,
            mode="dry-run",
            reasons=["Modo dry-run: no se ejecutan llamadas externas."],
        )

    if provider == "mock":
        return DecisionPiloto(
            allowed=True,
            mode="mock",
            reasons=["Proveedor simulado autorizado."],
        )

    if approval is None:
        reasons.append("No existe aprobación institucional.")

    if approval is not None:
        now = datetime.now(timezone.utc)
        expires = datetime.fromisoformat(
            approval.expires_at_utc.replace("Z", "+00:00")
        )

        if approval.provider != provider:
            reasons.append("La aprobación corresponde a otro proveedor.")

        if expires <= now:
            reasons.append("La aprobación está vencida.")

        required_flags = {
            "administrative_approved": approval.administrative_approved,
            "cultural_approved": approval.cultural_approved,
            "privacy_approved": approval.privacy_approved,
            "budget_approved": approval.budget_approved,
            "live_calls_authorized": approval.live_calls_authorized,
        }

        for name, value in required_flags.items():
            if not value:
                reasons.append(f"Falta aprobación: {name}.")

        if requested_jobs > approval.max_jobs:
            reasons.append("La cantidad solicitada supera el límite.")

        if estimated_cost_usd > approval.max_cost_usd:
            reasons.append("El costo estimado supera el presupuesto.")

        unauthorized = sorted(
            set(job_types) - set(approval.allowed_job_types)
        )
        if unauthorized:
            reasons.append(
                "Tipos de trabajo no autorizados: "
                + ", ".join(unauthorized)
            )

    secret_name = PROVIDER_SECRETS.get(provider)
    if secret_name is None:
        reasons.append("Proveedor real no registrado.")
    elif not os.getenv(secret_name):
        reasons.append(
            f"Falta la variable de entorno {secret_name}."
        )

    return DecisionPiloto(
        allowed=not reasons,
        mode="live" if not reasons else "blocked",
        reasons=reasons,
    )