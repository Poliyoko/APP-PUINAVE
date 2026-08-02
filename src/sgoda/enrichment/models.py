"""Modelos del pipeline de enriquecimiento multimedia."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


RESOURCE_TYPES = (
    "translation_en",
    "audio_es",
    "audio_en",
    "image",
    "video",
)


@dataclass(slots=True)
class EnrichmentNeed:
    canonical_id: str
    resource_type: str
    priority: int
    required: bool
    reason: str


@dataclass(slots=True)
class EnrichmentJob:
    job_id: str
    canonical_id: str
    resource_type: str
    source_text: str
    target_language: str | None
    status: str = "pending"
    attempts: int = 0
    provider: str = "mock"
    validation_status: str = "pending"
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class GeneratedResource:
    resource_id: str
    canonical_id: str
    resource_type: str
    status: str
    uri: str | None
    sha256: str | None
    provider: str
    validation_status: str
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class PlaybackManifest:
    canonical_id: str
    sequence: list[str]
    autoplay_enabled: bool
    autoplay_video: bool
    stop_on_error: bool
    resources: dict[str, str | None]