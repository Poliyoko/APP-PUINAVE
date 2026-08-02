"""Modelos del motor multilingüe local y gratuito."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class LanguageProfile:
    language: str
    locale: str
    regional_variant: str
    translation_source: str | None
    translation_target: str | None
    tts_priority: list[str]
    offline_only: bool = True


@dataclass(slots=True)
class ModelLicenseRecord:
    model_id: str
    purpose: str
    language: str
    locale: str
    provider: str
    local: bool
    requires_payment: bool
    requires_api_key: bool
    license_name: str | None
    license_url: str | None
    model_card_verified: bool
    approved: bool
    checksum_sha256: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class TranslationResult:
    source_text: str
    translated_text: str
    source_locale: str
    target_locale: str
    provider: str
    status: str


@dataclass(slots=True)
class AudioResult:
    text: str
    locale: str
    provider: str
    voice_id: str
    output_path: str
    sha256: str
    status: str