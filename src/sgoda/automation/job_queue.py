"""Cola transaccional e idempotente para trabajos multimedia."""

from __future__ import annotations

import hashlib
import json
import sqlite3
from contextlib import contextmanager
from dataclasses import asdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Iterator

from .models import TrabajoMultimedia


SCHEMA_VERSION = "0.1.0"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def deterministic_job_id(
    resource_id: str,
    job_type: str,
    version: str = "1",
) -> str:
    identity = f"{resource_id}|{job_type}|{version}"
    digest = hashlib.sha256(
        identity.encode("utf-8")
    ).hexdigest()[:24].upper()
    return f"JOB-{digest}"


class ColaTrabajosMultimedia:
    def __init__(self, database_path: str | Path) -> None:
        self.database_path = Path(database_path)

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(self.database_path, timeout=30)
        connection.row_factory = sqlite3.Row
        try:
            connection.execute("PRAGMA journal_mode = WAL")
            connection.execute("PRAGMA synchronous = NORMAL")
            connection.execute("PRAGMA foreign_keys = ON")
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def initialize(self) -> None:
        with self.connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS queue_metadata (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS multimedia_jobs (
                    job_id TEXT PRIMARY KEY,
                    resource_id TEXT NOT NULL,
                    oda_id TEXT NOT NULL,
                    canonical_id TEXT NOT NULL,
                    job_type TEXT NOT NULL,
                    language TEXT,
                    status TEXT NOT NULL,
                    priority INTEGER NOT NULL,
                    attempt_count INTEGER NOT NULL,
                    max_attempts INTEGER NOT NULL,
                    provider TEXT,
                    payload_json TEXT NOT NULL,
                    result_json TEXT NOT NULL,
                    error TEXT,
                    available_at_utc TEXT NOT NULL,
                    lease_until_utc TEXT,
                    created_at_utc TEXT NOT NULL,
                    updated_at_utc TEXT NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_jobs_status_available
                    ON multimedia_jobs(status, available_at_utc, priority);

                CREATE INDEX IF NOT EXISTS idx_jobs_resource
                    ON multimedia_jobs(resource_id);

                CREATE INDEX IF NOT EXISTS idx_jobs_oda
                    ON multimedia_jobs(oda_id);

                CREATE INDEX IF NOT EXISTS idx_jobs_type
                    ON multimedia_jobs(job_type);
                """
            )
            connection.execute(
                """
                INSERT INTO queue_metadata(key, value)
                VALUES('schema_version', ?)
                ON CONFLICT(key) DO UPDATE SET value=excluded.value
                """,
                (SCHEMA_VERSION,),
            )

    @staticmethod
    def _parameters(job: TrabajoMultimedia) -> tuple[Any, ...]:
        now = utc_now()
        return (
            job.job_id,
            job.resource_id,
            job.oda_id,
            job.canonical_id,
            job.job_type,
            job.language,
            job.status,
            job.priority,
            job.attempt_count,
            job.max_attempts,
            job.provider,
            json.dumps(job.payload, ensure_ascii=False),
            json.dumps(job.result, ensure_ascii=False),
            job.error,
            job.available_at_utc or now,
            job.lease_until_utc,
            job.created_at_utc or now,
            now,
        )

    def upsert_many(
        self,
        jobs: Iterable[TrabajoMultimedia],
        batch_size: int = 5000,
    ) -> tuple[int, int]:
        sql = """
            INSERT INTO multimedia_jobs(
                job_id, resource_id, oda_id, canonical_id,
                job_type, language, status, priority,
                attempt_count, max_attempts, provider,
                payload_json, result_json, error,
                available_at_utc, lease_until_utc,
                created_at_utc, updated_at_utc
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(job_id) DO NOTHING
        """

        inserted = 0
        existing = 0
        batch: list[tuple[Any, ...]] = []

        with self.connect() as connection:
            cursor = connection.cursor()

            for job in jobs:
                batch.append(self._parameters(job))
                if len(batch) >= batch_size:
                    before = connection.total_changes
                    cursor.executemany(sql, batch)
                    changed = connection.total_changes - before
                    inserted += changed
                    existing += len(batch) - changed
                    batch.clear()

            if batch:
                before = connection.total_changes
                cursor.executemany(sql, batch)
                changed = connection.total_changes - before
                inserted += changed
                existing += len(batch) - changed

        return inserted, existing

    def count(self, status: str | None = None) -> int:
        with self.connect() as connection:
            if status is None:
                row = connection.execute(
                    "SELECT COUNT(*) AS total FROM multimedia_jobs"
                ).fetchone()
            else:
                row = connection.execute(
                    """
                    SELECT COUNT(*) AS total
                    FROM multimedia_jobs
                    WHERE status = ?
                    """,
                    (status,),
                ).fetchone()
        return int(row["total"])

    def lease(
        self,
        *,
        worker_id: str,
        limit: int = 10,
        lease_seconds: int = 300,
    ) -> list[TrabajoMultimedia]:
        if limit < 1 or limit > 1000:
            raise ValueError("limit debe estar entre 1 y 1000.")

        now = datetime.now(timezone.utc)
        now_iso = now.isoformat()
        lease_until = (
            now + timedelta(seconds=lease_seconds)
        ).isoformat()

        with self.connect() as connection:
            rows = connection.execute(
                """
                SELECT *
                FROM multimedia_jobs
                WHERE status = 'pending'
                  AND available_at_utc <= ?
                ORDER BY priority ASC, created_at_utc ASC
                LIMIT ?
                """,
                (now_iso, limit),
            ).fetchall()

            ids = [row["job_id"] for row in rows]

            if ids:
                placeholders = ",".join("?" for _ in ids)
                connection.execute(
                    f"""
                    UPDATE multimedia_jobs
                    SET status='leased',
                        provider=?,
                        lease_until_utc=?,
                        updated_at_utc=?
                    WHERE job_id IN ({placeholders})
                      AND status='pending'
                    """,
                    (worker_id, lease_until, now_iso, *ids),
                )

            leased = connection.execute(
                f"""
                SELECT *
                FROM multimedia_jobs
                WHERE job_id IN ({",".join("?" for _ in ids)})
                  AND status='leased'
                ORDER BY priority ASC, created_at_utc ASC
                """ if ids else
                "SELECT * FROM multimedia_jobs WHERE 1=0",
                ids,
            ).fetchall()

        return [self._from_row(row) for row in leased]

    def complete(
        self,
        job_id: str,
        result: dict[str, Any],
    ) -> None:
        with self.connect() as connection:
            cursor = connection.execute(
                """
                UPDATE multimedia_jobs
                SET status='completed',
                    result_json=?,
                    error=NULL,
                    lease_until_utc=NULL,
                    updated_at_utc=?
                WHERE job_id=? AND status='leased'
                """,
                (
                    json.dumps(result, ensure_ascii=False),
                    utc_now(),
                    job_id,
                ),
            )
            if cursor.rowcount != 1:
                raise ValueError(
                    f"El trabajo no estÃ¡ leased: {job_id}"
                )

    def fail(
        self,
        job_id: str,
        error: str,
        retry_delay_seconds: int = 60,
    ) -> None:
        with self.connect() as connection:
            row = connection.execute(
                """
                SELECT attempt_count, max_attempts
                FROM multimedia_jobs
                WHERE job_id=?
                """,
                (job_id,),
            ).fetchone()

            if row is None:
                raise KeyError(job_id)

            attempts = int(row["attempt_count"]) + 1
            exhausted = attempts >= int(row["max_attempts"])
            status = "failed" if exhausted else "pending"
            available = (
                datetime.now(timezone.utc)
                + timedelta(seconds=retry_delay_seconds)
            ).isoformat()

            connection.execute(
                """
                UPDATE multimedia_jobs
                SET status=?,
                    attempt_count=?,
                    error=?,
                    available_at_utc=?,
                    lease_until_utc=NULL,
                    updated_at_utc=?
                WHERE job_id=?
                """,
                (
                    status,
                    attempts,
                    error,
                    available,
                    utc_now(),
                    job_id,
                ),
            )

    def recover_expired_leases(self) -> int:
        now = utc_now()
        with self.connect() as connection:
            cursor = connection.execute(
                """
                UPDATE multimedia_jobs
                SET status='pending',
                    lease_until_utc=NULL,
                    provider=NULL,
                    updated_at_utc=?
                WHERE status='leased'
                  AND lease_until_utc < ?
                """,
                (now, now),
            )
            return int(cursor.rowcount)

    def statistics(self) -> dict[str, Any]:
        with self.connect() as connection:
            by_status = {
                row["status"]: int(row["total"])
                for row in connection.execute(
                    """
                    SELECT status, COUNT(*) AS total
                    FROM multimedia_jobs
                    GROUP BY status
                    ORDER BY status
                    """
                ).fetchall()
            }
            by_type = {
                row["job_type"]: int(row["total"])
                for row in connection.execute(
                    """
                    SELECT job_type, COUNT(*) AS total
                    FROM multimedia_jobs
                    GROUP BY job_type
                    ORDER BY job_type
                    """
                ).fetchall()
            }

        return {
            "total_jobs": self.count(),
            "by_status": by_status,
            "by_type": by_type,
        }

    @staticmethod
    def _from_row(row: sqlite3.Row) -> TrabajoMultimedia:
        return TrabajoMultimedia(
            job_id=row["job_id"],
            resource_id=row["resource_id"],
            oda_id=row["oda_id"],
            canonical_id=row["canonical_id"],
            job_type=row["job_type"],
            language=row["language"],
            status=row["status"],
            priority=int(row["priority"]),
            attempt_count=int(row["attempt_count"]),
            max_attempts=int(row["max_attempts"]),
            provider=row["provider"],
            payload=json.loads(row["payload_json"]),
            result=json.loads(row["result_json"]),
            error=row["error"],
            available_at_utc=row["available_at_utc"],
            lease_until_utc=row["lease_until_utc"],
            created_at_utc=row["created_at_utc"],
            updated_at_utc=row["updated_at_utc"],
        )