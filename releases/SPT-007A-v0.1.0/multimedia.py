"""Selección gobernada de recursos multimedia."""

from __future__ import annotations

from .models import LexicalEntry, MultimediaResource


def resources_for_entry(
    entry: LexicalEntry,
    language: str | None = None,
    validated_only: bool = False,
) -> tuple[MultimediaResource, ...]:
    resources = []

    for resource in entry.multimedia:
        if validated_only and not resource.validated:
            continue

        if (
            language is not None
            and resource.language not in {None, language}
        ):
            continue

        resources.append(resource)

    return tuple(
        sorted(
            resources,
            key=lambda item: (
                item.resource_type,
                item.language or "",
                item.path,
            ),
        )
    )


def playback_manifest(entry: LexicalEntry) -> dict:
    audios = [
        resource
        for resource in resources_for_entry(entry)
        if resource.resource_type == "audio"
    ]

    images = [
        resource
        for resource in resources_for_entry(entry)
        if resource.resource_type == "image"
    ]

    videos = [
        resource
        for resource in resources_for_entry(entry)
        if resource.resource_type == "video"
    ]

    return {
        "entry_id": entry.entry_id,
        "autoplay_audio": [
            {
                "language": item.language,
                "path": item.path,
                "validated": item.validated,
            }
            for item in audios
            if item.autoplay
        ],
        "images": [
            {
                "path": item.path,
                "validated": item.validated,
            }
            for item in images
        ],
        "videos": [
            {
                "path": item.path,
                "validated": item.validated,
                "autoplay": False,
            }
            for item in videos
        ],
    }