"""Repositorio de recursos multimedia."""

from __future__ import annotations

from .models import MediaResource


class MediaRepository:
    def __init__(self) -> None:
        self._resources: dict[str, MediaResource] = {}

    def add(self, resource: MediaResource) -> MediaResource:
        if resource.resource_id in self._resources:
            raise ValueError(
                f"El recurso ya existe: {resource.resource_id}"
            )

        self._resources[resource.resource_id] = resource
        return resource

    def upsert(self, resource: MediaResource) -> MediaResource:
        self._resources[resource.resource_id] = resource
        return resource

    def get(self, resource_id: str) -> MediaResource | None:
        return self._resources.get(
            str(resource_id or "").strip()
        )

    def all(self) -> tuple[MediaResource, ...]:
        return tuple(
            self._resources[key]
            for key in sorted(self._resources)
        )

    def for_entry(
        self,
        entry_id: str,
        validated_only: bool = False,
    ) -> tuple[MediaResource, ...]:
        items = [
            item
            for item in self.all()
            if item.entry_id == entry_id
        ]

        if validated_only:
            items = [
                item
                for item in items
                if item.validated
            ]

        return tuple(items)

    def find_duplicates(self) -> tuple[dict[str, str], ...]:
        seen = {}
        duplicates = []

        for item in self.all():
            key = (
                item.entry_id,
                item.media_type,
                item.language,
                item.uri.casefold(),
            )

            if key in seen:
                duplicates.append(
                    {
                        "first": seen[key],
                        "duplicate": item.resource_id,
                    }
                )
            else:
                seen[key] = item.resource_id

        return tuple(duplicates)