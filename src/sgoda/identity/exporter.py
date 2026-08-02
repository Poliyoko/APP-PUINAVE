"""Exportadores de identidad para clientes SGODA."""

from __future__ import annotations

import json
from pathlib import Path

from .models import IdentityProfile


def export_flutter(
    profile: IdentityProfile,
    output: str | Path,
) -> Path:
    path = Path(output)
    path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "appName": profile.app_name,
        "assistantName": profile.assistant_name,
        "publicName": profile.public_name,
        "puinaveName": profile.puinave_name,
        "slogan": profile.slogan,
        "logoAsset": profile.logo_path,
        "iconAsset": profile.icon_path,
        "localeDefault": profile.locale_default,
        "identityVersion": profile.version,
    }

    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return path


def export_web(
    profile: IdentityProfile,
    output: str | Path,
) -> Path:
    path = Path(output)
    path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "title": profile.public_name,
        "applicationName": profile.app_name,
        "assistantName": profile.assistant_name,
        "description": profile.slogan,
        "logo": profile.logo_path,
        "icon": profile.icon_path,
        "lang": profile.locale_default,
        "technicalIdentity": profile.technical_name,
    }

    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return path


def export_api(
    profile: IdentityProfile,
    output: str | Path,
) -> Path:
    path = Path(output)
    path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "identity_id": profile.identity_id,
        "technical_name": profile.technical_name,
        "public_name": profile.public_name,
        "app_name": profile.app_name,
        "assistant_name": profile.assistant_name,
        "puinave_name": profile.puinave_name,
        "approval_status": profile.approval.status,
        "version": profile.version,
    }

    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return path