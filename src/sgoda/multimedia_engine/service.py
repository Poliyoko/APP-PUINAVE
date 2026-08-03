"""Servicio principal de SPT-014."""

from __future__ import annotations

from typing import Any

from .manifest import (
    export_manifest,
    load_manifest,
    media_from_dict,
    media_to_dict,
)
from .models import MultimediaCommand, MultimediaResult
from .oda import build_multimedia_oda
from .repository import MediaRepository
from .validation import validate_media_payload


class IntelligentMultimediaEngine:
    def __init__(
        self,
        repository: MediaRepository | None = None,
    ) -> None:
        self.repository = repository or MediaRepository()

    def execute(
        self,
        command: MultimediaCommand,
    ) -> MultimediaResult:
        handlers = {
            "register": self._register,
            "upsert": self._upsert,
            "get": self._get,
            "for_entry": self._for_entry,
            "build_oda": self._build_oda,
            "import_manifest": self._import_manifest,
            "export_manifest": self._export_manifest,
            "audit": self._audit,
            "stats": self._stats,
        }

        handler = handlers.get(command.operation)

        if handler is None:
            return MultimediaResult(
                operation=command.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(command.payload)

    def _register(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        errors = validate_media_payload(payload)

        if errors:
            return MultimediaResult(
                operation="register",
                status="invalid_resource",
                data={"errors": list(errors)},
                warnings=errors,
            )

        resource = media_from_dict(payload)

        try:
            self.repository.add(resource)
        except ValueError as error:
            return MultimediaResult(
                operation="register",
                status="duplicate_id",
                data={"resource_id": resource.resource_id},
                warnings=(str(error),),
            )

        return MultimediaResult(
            operation="register",
            status="ok",
            data=media_to_dict(resource),
        )

    def _upsert(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        errors = validate_media_payload(payload)

        if errors:
            return MultimediaResult(
                operation="upsert",
                status="invalid_resource",
                data={"errors": list(errors)},
                warnings=errors,
            )

        resource = self.repository.upsert(
            media_from_dict(payload)
        )

        return MultimediaResult(
            operation="upsert",
            status="ok",
            data=media_to_dict(resource),
        )

    def _get(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        resource_id = str(
            payload.get("resource_id") or ""
        ).strip()
        resource = self.repository.get(resource_id)

        if resource is None:
            return MultimediaResult(
                operation="get",
                status="not_found",
                data={"resource_id": resource_id},
            )

        return MultimediaResult(
            operation="get",
            status="ok",
            data=media_to_dict(resource),
        )

    def _for_entry(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        entry_id = str(payload.get("entry_id") or "").strip()
        validated_only = bool(
            payload.get("validated_only", False)
        )
        resources = self.repository.for_entry(
            entry_id,
            validated_only=validated_only,
        )

        return MultimediaResult(
            operation="for_entry",
            status="ok",
            data={
                "entry_id": entry_id,
                "total": len(resources),
                "resources": [
                    media_to_dict(item)
                    for item in resources
                ],
            },
        )

    def _build_oda(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        entry_id = str(payload.get("entry_id") or "").strip()
        resources = self.repository.for_entry(
            entry_id,
            validated_only=False,
        )

        return MultimediaResult(
            operation="build_oda",
            status="ok",
            data=build_multimedia_oda(
                entry_id,
                resources,
            ),
        )

    def _import_manifest(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        path = str(payload.get("path") or "").strip()
        imported = 0
        rejected = []

        for resource in load_manifest(path):
            raw = media_to_dict(resource)
            errors = validate_media_payload(raw)

            if errors:
                rejected.append(
                    {
                        "resource_id": resource.resource_id,
                        "errors": list(errors),
                    }
                )
                continue

            self.repository.upsert(resource)
            imported += 1

        return MultimediaResult(
            operation="import_manifest",
            status="ok",
            data={
                "imported": imported,
                "rejected": rejected,
            },
        )

    def _export_manifest(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        path = str(payload.get("path") or "").strip()
        export_manifest(path, self.repository.all())

        return MultimediaResult(
            operation="export_manifest",
            status="ok",
            data={
                "path": path,
                "total": len(self.repository.all()),
            },
        )

    def _audit(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        duplicates = self.repository.find_duplicates()
        invalid = []

        for resource in self.repository.all():
            errors = validate_media_payload(
                media_to_dict(resource)
            )

            if errors:
                invalid.append(
                    {
                        "resource_id": resource.resource_id,
                        "errors": list(errors),
                    }
                )

        approved = not duplicates and not invalid

        return MultimediaResult(
            operation="audit",
            status="ok" if approved else "not_approved",
            data={
                "approved": approved,
                "duplicates": list(duplicates),
                "invalid": invalid,
            },
        )

    def _stats(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        resources = self.repository.all()

        return MultimediaResult(
            operation="stats",
            status="ok",
            data={
                "total": len(resources),
                "validated": sum(
                    1 for item in resources if item.validated
                ),
                "pending_validation": sum(
                    1 for item in resources if not item.validated
                ),
                "images": sum(
                    1
                    for item in resources
                    if item.media_type == "image"
                ),
                "audio": sum(
                    1
                    for item in resources
                    if item.media_type.startswith("audio_")
                ),
                "video": sum(
                    1
                    for item in resources
                    if item.media_type == "video"
                ),
            },
        )