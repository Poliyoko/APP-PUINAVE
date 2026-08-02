"""Construcción del manifiesto de reproducción automática."""

from __future__ import annotations

from .models import GeneratedResource, PlaybackManifest


DEFAULT_SEQUENCE = [
    "image",
    "audio_puinave",
    "audio_es",
    "audio_en",
    "video",
]


def build_playback_manifest(
    *,
    canonical_id: str,
    resources: list[GeneratedResource],
    autoplay_enabled: bool = True,
    autoplay_video: bool = False,
) -> PlaybackManifest:
    resource_map: dict[str, str | None] = {
        "image": None,
        "audio_puinave": None,
        "audio_es": None,
        "audio_en": None,
        "video": None,
    }

    for resource in resources:
        if resource.resource_type in resource_map:
            resource_map[resource.resource_type] = resource.uri

    sequence = [
        item for item in DEFAULT_SEQUENCE
        if resource_map.get(item) is not None
    ]

    if not autoplay_video:
        sequence = [item for item in sequence if item != "video"]

    return PlaybackManifest(
        canonical_id=canonical_id,
        sequence=sequence,
        autoplay_enabled=autoplay_enabled,
        autoplay_video=autoplay_video,
        stop_on_error=False,
        resources=resource_map,
    )