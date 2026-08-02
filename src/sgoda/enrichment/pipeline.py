"""Orquestación funcional del enriquecimiento multimedia."""

from __future__ import annotations

import json
import sqlite3
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

from .models import EnrichmentJob, GeneratedResource
from .planner import plan_repository
from .playback import build_playback_manifest
from .providers import MockEnrichmentProvider


class EnrichmentPipeline:
    def __init__(
        self,
        *,
        jobs_db: str | Path,
        resources_root: str | Path,
        manifests_root: str | Path,
    ) -> None:
        self.jobs_db = Path(jobs_db)
        self.resources_root = Path(resources_root)
        self.manifests_root = Path(manifests_root)

    def _connection(self) -> sqlite3.Connection:
        self.jobs_db.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(self.jobs_db)
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS enrichment_jobs (
                job_id TEXT PRIMARY KEY,
                canonical_id TEXT NOT NULL,
                resource_type TEXT NOT NULL,
                status TEXT NOT NULL,
                provider TEXT NOT NULL,
                attempts INTEGER NOT NULL,
                updated_at_utc TEXT NOT NULL
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS generated_resources (
                resource_id TEXT PRIMARY KEY,
                canonical_id TEXT NOT NULL,
                resource_type TEXT NOT NULL,
                uri TEXT,
                sha256 TEXT,
                validation_status TEXT NOT NULL,
                provider TEXT NOT NULL,
                created_at_utc TEXT NOT NULL
            )
            """
        )
        return connection

    def persist_jobs(self, jobs: list[EnrichmentJob]) -> int:
        inserted = 0
        now = datetime.now(timezone.utc).isoformat()

        with self._connection() as connection:
            for job in jobs:
                cursor = connection.execute(
                    """
                    INSERT OR IGNORE INTO enrichment_jobs (
                        job_id, canonical_id, resource_type,
                        status, provider, attempts, updated_at_utc
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        job.job_id,
                        job.canonical_id,
                        job.resource_type,
                        job.status,
                        job.provider,
                        job.attempts,
                        now,
                    ),
                )
                inserted += cursor.rowcount

        return inserted

    def execute_mock(
        self,
        jobs: list[EnrichmentJob],
    ) -> list[GeneratedResource]:
        provider = MockEnrichmentProvider()
        resources: list[GeneratedResource] = []
        now = datetime.now(timezone.utc).isoformat()

        with self._connection() as connection:
            for job in jobs:
                resource = provider.execute(
                    job,
                    self.resources_root / job.canonical_id,
                )
                resources.append(resource)

                connection.execute(
                    """
                    INSERT OR REPLACE INTO generated_resources (
                        resource_id, canonical_id, resource_type,
                        uri, sha256, validation_status,
                        provider, created_at_utc
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        resource.resource_id,
                        resource.canonical_id,
                        resource.resource_type,
                        resource.uri,
                        resource.sha256,
                        resource.validation_status,
                        resource.provider,
                        now,
                    ),
                )
                connection.execute(
                    """
                    UPDATE enrichment_jobs
                    SET status = ?, attempts = attempts + 1,
                        updated_at_utc = ?
                    WHERE job_id = ?
                    """,
                    ("completed_mock", now, job.job_id),
                )

        return resources

    def publish_manifests(
        self,
        resources: list[GeneratedResource],
    ) -> list[Path]:
        by_entry: dict[str, list[GeneratedResource]] = {}
        for resource in resources:
            by_entry.setdefault(
                resource.canonical_id,
                [],
            ).append(resource)

        self.manifests_root.mkdir(parents=True, exist_ok=True)
        paths: list[Path] = []

        for canonical_id, entry_resources in by_entry.items():
            manifest = build_playback_manifest(
                canonical_id=canonical_id,
                resources=entry_resources,
                autoplay_enabled=True,
                autoplay_video=False,
            )
            path = self.manifests_root / f"{canonical_id}.json"
            path.write_text(
                json.dumps(
                    asdict(manifest),
                    ensure_ascii=False,
                    indent=2,
                ) + "\n",
                encoding="utf-8",
            )
            paths.append(path)

        return paths


def run_pipeline(
    *,
    canonical_path: str | Path,
    jobs_db: str | Path,
    resources_root: str | Path,
    manifests_root: str | Path,
    limit: int | None = None,
) -> dict:
    records, jobs = plan_repository(
        canonical_path,
        limit=limit,
    )
    pipeline = EnrichmentPipeline(
        jobs_db=jobs_db,
        resources_root=resources_root,
        manifests_root=manifests_root,
    )
    inserted = pipeline.persist_jobs(jobs)
    resources = pipeline.execute_mock(jobs)
    manifests = pipeline.publish_manifests(resources)

    return {
        "records_processed": len(records),
        "jobs_planned": len(jobs),
        "jobs_inserted": inserted,
        "resources_generated_mock": len(resources),
        "playback_manifests": len(manifests),
        "external_calls": 0,
        "cost_usd": 0.0,
        "provider": "mock",
        "autoplay_audio": True,
        "autoplay_video": False,
    }