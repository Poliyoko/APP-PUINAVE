from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True)
class MultimediaReference:
    resource_id: str
    resource_type: str
    output_path: str
    sha256: str
    media_type: str | None
    language: str | None
    reviewer: str | None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class LexicalInput:
    lexical_id: str
    puinave: str
    category_id: str | None
    translations: dict[str, str]
    multimedia_manifest_sha256: str
    resources: tuple[MultimediaReference, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "lexical_id": self.lexical_id,
            "puinave": self.puinave,
            "category_id": self.category_id,
            "translations": dict(self.translations),
            "multimedia_manifest_sha256": self.multimedia_manifest_sha256,
            "resources": [item.to_dict() for item in self.resources],
        }


def parse_ready_for_fld_oda(payload: dict[str, Any]) -> LexicalInput:
    if str(payload.get("status") or "").strip() != "READY_FOR_FLD_ODA":
        raise ValueError("SPT-023.5 requires READY_FOR_FLD_ODA input.")

    lexical_id = str(payload.get("lexical_id") or "").strip()
    puinave = str(payload.get("puinave") or "").strip()
    category_id = str(payload.get("category_id") or "").strip() or None
    manifest_sha = str(payload.get("multimedia_manifest_sha256") or "").strip()

    if not lexical_id:
        raise ValueError("lexical_id is required.")
    if not puinave:
        raise ValueError("Puinave text is required.")
    if not manifest_sha:
        raise ValueError("multimedia_manifest_sha256 is required.")

    translations = dict(payload.get("translations") or {})
    resources_raw = list(payload.get("resources") or [])

    if len(resources_raw) != 5:
        raise ValueError("Exactly five multimedia resources are required.")

    resources: list[MultimediaReference] = []
    resource_types: set[str] = set()

    for raw in resources_raw:
        resource_type = str(raw.get("resource_type") or "").strip()
        resource_id = str(raw.get("resource_id") or "").strip()
        output_path = str(raw.get("output_path") or "").strip()
        sha256 = str(raw.get("sha256") or "").strip()

        if not resource_type or not resource_id or not output_path or not sha256:
            raise ValueError("Multimedia resource is incomplete.")
        if resource_type in resource_types:
            raise ValueError(f"Duplicate multimedia resource_type: {resource_type}")

        resource_types.add(resource_type)
        validation = dict(raw.get("validation") or {})
        resources.append(
            MultimediaReference(
                resource_id=resource_id,
                resource_type=resource_type,
                output_path=output_path,
                sha256=sha256,
                media_type=str(validation.get("media_type") or "").strip() or None,
                language=str(raw.get("language") or "").strip() or None,
                reviewer=str(raw.get("reviewer") or "").strip() or None,
            )
        )

    expected = {
        "image",
        "audio_puinave",
        "audio_es",
        "audio_en",
        "audio_it",
    }
    if resource_types != expected:
        raise ValueError("Multimedia resource set is incomplete or invalid.")

    return LexicalInput(
        lexical_id=lexical_id,
        puinave=puinave,
        category_id=category_id,
        translations=translations,
        multimedia_manifest_sha256=manifest_sha,
        resources=tuple(resources),
    )
