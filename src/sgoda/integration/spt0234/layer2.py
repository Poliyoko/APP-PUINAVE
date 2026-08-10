from __future__ import annotations

from pathlib import Path
from typing import Any

from .executor import LocalMultimediaExecutor
from .rmr import RmrRegistry


class Spt0234Layer2Service:
    """EjecuciÃ³n local y persistencia efectiva de los planes de Capa 1."""

    def __init__(
        self,
        *,
        executor: LocalMultimediaExecutor,
        rmr: RmrRegistry,
        media_root: str | Path,
    ) -> None:
        self.executor = executor
        self.rmr = rmr
        self.media_root = Path(media_root)

    def _output_path(
        self,
        *,
        lexical_id: str,
        resource_type: str,
        extension: str,
    ) -> Path:
        safe_lexical = "".join(
            ch if ch.isalnum() or ch in "-_." else "_"
            for ch in lexical_id
        )
        return self.media_root / safe_lexical / f"{resource_type}{extension}"

    def execute_resource(
        self,
        plan: dict[str, Any],
        *,
        puinave: str,
        localized_text: str | None = None,
        image_prompt: str | None = None,
        native_audio_source: str | Path | None = None,
    ) -> dict[str, Any]:
        resource_id = str(plan["resource_id"])
        lexical_id = str(plan["lexical_id"])
        resource_type = str(plan["resource_type"])
        language = plan.get("language")

        existing = self.rmr.get(resource_id)
        if existing and str(existing.get("status")) in {
            "GENERATED_LOCAL",
            "IMPORTED_NATIVE",
            "APPROVED",
            "PUBLISHED",
        }:
            reused = dict(existing)
            reused["reused"] = True
            reused["status"] = "REUSE_EXISTING"
            return reused

        if resource_type == "image":
            prompt = str(image_prompt or "").strip()
            if not prompt:
                raise ValueError("Image execution requires image_prompt.")
            result = self.executor.execute_image(
                resource_id=resource_id,
                lexical_id=lexical_id,
                puinave=puinave,
                prompt=prompt,
                output_path=self._output_path(
                    lexical_id=lexical_id,
                    resource_type="image",
                    extension=".png",
                ),
            )
        elif resource_type == "audio_puinave":
            if native_audio_source is None:
                raise ValueError("Puinave audio requires native_audio_source.")
            result = self.executor.import_native_audio(
                resource_id=resource_id,
                lexical_id=lexical_id,
                source_path=native_audio_source,
                output_path=self._output_path(
                    lexical_id=lexical_id,
                    resource_type="audio_puinave",
                    extension=".wav",
                ),
            )
        elif resource_type in {"audio_es", "audio_en", "audio_it"}:
            text = str(localized_text or "").strip()
            if not text:
                raise ValueError(f"{resource_type} requires localized_text.")
            result = self.executor.execute_tts(
                resource_id=resource_id,
                lexical_id=lexical_id,
                resource_type=resource_type,
                language=str(language),
                text=text,
                output_path=self._output_path(
                    lexical_id=lexical_id,
                    resource_type=resource_type,
                    extension=".wav",
                ),
            )
        else:
            raise ValueError(f"Unsupported multimedia resource_type: {resource_type}")

        record = result.to_dict()
        record.update(
            {
                "lexical_id": lexical_id,
                "language": language,
                "source_component": "SPT-023.4-CAPA-1",
                "target_component": "ADR-010/RMR",
                "paid_api_used": False,
                "external_network_required": False,
            }
        )
        return self.rmr.upsert(record)

    def execute_plan(
        self,
        multimedia_plan: dict[str, Any],
        *,
        localized_texts: dict[str, str],
        image_prompt: str,
        native_audio_source: str | Path,
    ) -> dict[str, Any]:
        lexical_id = str(multimedia_plan["lexical_id"])
        puinave = str(multimedia_plan["puinave"])
        results: list[dict[str, Any]] = []

        for plan in multimedia_plan["plans"]:
            resource_type = str(plan["resource_type"])
            results.append(
                self.execute_resource(
                    plan,
                    puinave=puinave,
                    localized_text=localized_texts.get(resource_type),
                    image_prompt=image_prompt,
                    native_audio_source=native_audio_source,
                )
            )

        status_counts: dict[str, int] = {}
        for item in results:
            status = str(item["status"])
            status_counts[status] = status_counts.get(status, 0) + 1

        return {
            "component": "SPT-023.4",
            "layer": "2",
            "lexical_id": lexical_id,
            "resources_processed": len(results),
            "status_counts": status_counts,
            "paid_api_used": False,
            "external_network_required": False,
            "rmr_persisted": True,
            "results": results,
            "next_component": "SPT-023.4-CAPA-3",
        }
