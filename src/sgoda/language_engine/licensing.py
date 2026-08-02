"""Control de licencias y gratuidad de modelos."""

from __future__ import annotations

import json
from pathlib import Path

from .models import ModelLicenseRecord


class ModelBlockedError(RuntimeError):
    pass


def load_allowlist(path: str | Path) -> list[ModelLicenseRecord]:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    return [
        ModelLicenseRecord(**item)
        for item in payload.get("models", [])
    ]


def validate_model(record: ModelLicenseRecord) -> None:
    reasons: list[str] = []

    if not record.local:
        reasons.append("el modelo no es local")
    if record.requires_payment:
        reasons.append("el modelo requiere pago")
    if record.requires_api_key:
        reasons.append("el modelo requiere clave API")
    if not record.license_name:
        reasons.append("la licencia no está identificada")
    if not record.license_url:
        reasons.append("la fuente de licencia no está registrada")
    if not record.model_card_verified:
        reasons.append("la ficha del modelo no fue verificada")
    if not record.approved:
        reasons.append("el modelo no está aprobado")

    if reasons:
        raise ModelBlockedError(" | ".join(reasons))


def approved_models(
    path: str | Path,
    *,
    purpose: str | None = None,
    locale: str | None = None,
) -> list[ModelLicenseRecord]:
    result: list[ModelLicenseRecord] = []

    for record in load_allowlist(path):
        try:
            validate_model(record)
        except ModelBlockedError:
            continue

        if purpose and record.purpose != purpose:
            continue
        if locale and record.locale != locale:
            continue
        result.append(record)

    return result