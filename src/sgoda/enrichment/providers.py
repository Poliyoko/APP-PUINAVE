"""Proveedores simulados seguros para pruebas y dry-run."""

from __future__ import annotations

import hashlib
from pathlib import Path

from .models import EnrichmentJob, GeneratedResource


class MockEnrichmentProvider:
    name = "mock"

    def execute(
        self,
        job: EnrichmentJob,
        output_root: str | Path,
    ) -> GeneratedResource:
        root = Path(output_root)
        root.mkdir(parents=True, exist_ok=True)

        payload: bytes
        suffix: str
        validation = "pending_review"

        if job.resource_type == "translation_en":
            payload = (
                f"PROPOSED_EN::{job.source_text}"
            ).encode("utf-8")
            suffix = ".txt"
            validation = "machine_proposed"
        elif job.resource_type in {"audio_es", "audio_en"}:
            payload = (
                f"MOCK_AUDIO::{job.target_language}::{job.source_text}"
            ).encode("utf-8")
            suffix = ".mock-audio"
            validation = "technical_valid"
        elif job.resource_type == "image":
            payload = (
                f"MOCK_IMAGE::{job.canonical_id}::{job.source_text}"
            ).encode("utf-8")
            suffix = ".mock-image"
            validation = "pending_cultural_review"
        else:
            payload = (
                f"MOCK_VIDEO_PLAN::{job.canonical_id}::{job.source_text}"
            ).encode("utf-8")
            suffix = ".mock-video-plan"
            validation = "not_generated_optional"

        digest = hashlib.sha256(payload).hexdigest()
        resource_id = (
            f"RMR-{job.resource_type.upper().replace('_', '-')}-"
            f"{digest[:16].upper()}"
        )
        path = root / f"{resource_id}{suffix}"
        path.write_bytes(payload)

        return GeneratedResource(
            resource_id=resource_id,
            canonical_id=job.canonical_id,
            resource_type=job.resource_type,
            status="generated_mock",
            uri=path.as_posix(),
            sha256=digest,
            provider=self.name,
            validation_status=validation,
            metadata={
                "external_call": False,
                "cost_usd": 0.0,
                "test_artifact": True,
            },
        )