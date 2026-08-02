"""ADR-010: repositorio multimedia escalable sobre SQLite."""

from __future__ import annotations

import hashlib
import json
import sqlite3
from contextlib import contextmanager
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Iterator

from .models import (
    ConsultaRecursosRMR,
    RecursoMultimediaRMR,
)


SCHEMA_VERSION = "1.0.0"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def deterministic_resource_id(
    *,
    oda_id: str,
    resource_type: str,
    subtype: str = "principal",
    language: str | None = None,
    variant: str | None = None,
    version: str = "1.0.0",
) -> str:
    """Genera un ID estable sin imponer tipos multimedia fijos."""

    identity = "|".join(
        [
            oda_id.strip(),
            resource_type.strip(),
            subtype.strip(),
            (language or "").strip(),
            (variant or "").strip(),
            version.strip(),
        ]
    )

    digest = hashlib.sha256(
        identity.encode("utf-8")
    ).hexdigest()[:24].upper()

    return f"RMR-{digest}"


class RepositorioMultimediaRMR:
    """Repositorio transaccional y paginado de recursos multimedia."""

    def __init__(self, database_path: str | Path) -> None:
        self.database_path = Path(database_path)

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        self.database_path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        connection = sqlite3.connect(
            self.database_path,
            timeout=30,
        )
        connection.row_factory = sqlite3.Row

        try:
            connection.execute("PRAGMA foreign_keys = ON")
            connection.execute("PRAGMA journal_mode = WAL")
            connection.execute("PRAGMA synchronous = NORMAL")
            connection.execute("PRAGMA temp_store = MEMORY")
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def initialize(self) -> None:
        """Crea tablas e índices idempotentes."""

        with self.connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS rmr_metadata (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS media_resources (
                    resource_id TEXT PRIMARY KEY,
                    oda_id TEXT NOT NULL,
                    canonical_id TEXT NOT NULL,
                    resource_type TEXT NOT NULL,
                    subtype TEXT NOT NULL DEFAULT 'principal',
                    language TEXT,
                    variant TEXT,
                    provider TEXT,
                    version TEXT NOT NULL DEFAULT '1.0.0',
                    media_format TEXT,
                    uri TEXT,
                    checksum_sha256 TEXT,
                    status TEXT NOT NULL,
                    metadata_json TEXT NOT NULL DEFAULT '{}',
                    created_at_utc TEXT NOT NULL,
                    updated_at_utc TEXT NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_rmr_oda_id
                    ON media_resources (oda_id);

                CREATE INDEX IF NOT EXISTS idx_rmr_canonical_id
                    ON media_resources (canonical_id);

                CREATE INDEX IF NOT EXISTS idx_rmr_type
                    ON media_resources (resource_type);

                CREATE INDEX IF NOT EXISTS idx_rmr_language
                    ON media_resources (language);

                CREATE INDEX IF NOT EXISTS idx_rmr_status
                    ON media_resources (status);

                CREATE INDEX IF NOT EXISTS idx_rmr_oda_type_status
                    ON media_resources (
                        oda_id,
                        resource_type,
                        status
                    );
                """
            )

            connection.execute(
                """
                INSERT INTO rmr_metadata (key, value)
                VALUES ('schema_version', ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                (SCHEMA_VERSION,),
            )

    @staticmethod
    def _row_to_model(
        row: sqlite3.Row,
    ) -> RecursoMultimediaRMR:
        return RecursoMultimediaRMR(
            resource_id=row["resource_id"],
            oda_id=row["oda_id"],
            canonical_id=row["canonical_id"],
            resource_type=row["resource_type"],
            subtype=row["subtype"],
            language=row["language"],
            variant=row["variant"],
            provider=row["provider"],
            version=row["version"],
            media_format=row["media_format"],
            uri=row["uri"],
            checksum_sha256=row["checksum_sha256"],
            status=row["status"],
            metadata=json.loads(
                row["metadata_json"] or "{}"
            ),
            created_at_utc=row["created_at_utc"],
            updated_at_utc=row["updated_at_utc"],
        )

    @staticmethod
    def _validate(resource: RecursoMultimediaRMR) -> None:
        required = {
            "resource_id": resource.resource_id,
            "oda_id": resource.oda_id,
            "canonical_id": resource.canonical_id,
            "resource_type": resource.resource_type,
            "status": resource.status,
        }

        missing = [
            name
            for name, value in required.items()
            if not str(value or "").strip()
        ]

        if missing:
            raise ValueError(
                "Campos obligatorios vacíos: "
                + ", ".join(missing)
            )

    @staticmethod
    def _parameters(
        resource: RecursoMultimediaRMR,
    ) -> tuple[Any, ...]:
        now = utc_now()
        created = resource.created_at_utc or now
        updated = now

        return (
            resource.resource_id,
            resource.oda_id,
            resource.canonical_id,
            resource.resource_type,
            resource.subtype,
            resource.language,
            resource.variant,
            resource.provider,
            resource.version,
            resource.media_format,
            resource.uri,
            resource.checksum_sha256,
            resource.status,
            json.dumps(
                resource.metadata,
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            created,
            updated,
        )

    @staticmethod
    def _upsert_sql() -> str:
        return """
            INSERT INTO media_resources (
                resource_id,
                oda_id,
                canonical_id,
                resource_type,
                subtype,
                language,
                variant,
                provider,
                version,
                media_format,
                uri,
                checksum_sha256,
                status,
                metadata_json,
                created_at_utc,
                updated_at_utc
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(resource_id) DO UPDATE SET
                oda_id = excluded.oda_id,
                canonical_id = excluded.canonical_id,
                resource_type = excluded.resource_type,
                subtype = excluded.subtype,
                language = excluded.language,
                variant = excluded.variant,
                provider = excluded.provider,
                version = excluded.version,
                media_format = excluded.media_format,
                uri = excluded.uri,
                checksum_sha256 = excluded.checksum_sha256,
                status = excluded.status,
                metadata_json = excluded.metadata_json,
                updated_at_utc = excluded.updated_at_utc
        """

    def upsert(
        self,
        resource: RecursoMultimediaRMR,
    ) -> None:
        self._validate(resource)

        with self.connect() as connection:
            connection.execute(
                self._upsert_sql(),
                self._parameters(resource),
            )

    def bulk_upsert(
        self,
        resources: Iterable[RecursoMultimediaRMR],
        *,
        batch_size: int = 5000,
    ) -> int:
        """Inserta o actualiza grandes volúmenes por lotes."""

        if batch_size < 1:
            raise ValueError(
                "batch_size debe ser mayor que cero."
            )

        processed = 0
        batch: list[tuple[Any, ...]] = []

        with self.connect() as connection:
            cursor = connection.cursor()
            sql = self._upsert_sql()

            for resource in resources:
                self._validate(resource)
                batch.append(self._parameters(resource))

                if len(batch) >= batch_size:
                    cursor.executemany(sql, batch)
                    processed += len(batch)
                    batch.clear()

            if batch:
                cursor.executemany(sql, batch)
                processed += len(batch)

        return processed

    def get(
        self,
        resource_id: str,
    ) -> RecursoMultimediaRMR | None:
        with self.connect() as connection:
            row = connection.execute(
                """
                SELECT *
                FROM media_resources
                WHERE resource_id = ?
                """,
                (resource_id,),
            ).fetchone()

        return (
            self._row_to_model(row)
            if row is not None
            else None
        )

    def query(
        self,
        filters: ConsultaRecursosRMR,
    ) -> list[RecursoMultimediaRMR]:
        if filters.limit < 1 or filters.limit > 10000:
            raise ValueError(
                "limit debe estar entre 1 y 10000."
            )

        if filters.offset < 0:
            raise ValueError(
                "offset no puede ser negativo."
            )

        clauses: list[str] = []
        parameters: list[Any] = []

        for column, value in (
            ("oda_id", filters.oda_id),
            ("canonical_id", filters.canonical_id),
            ("resource_type", filters.resource_type),
            ("language", filters.language),
            ("status", filters.status),
        ):
            if value is not None:
                clauses.append(f"{column} = ?")
                parameters.append(value)

        where = (
            " WHERE " + " AND ".join(clauses)
            if clauses
            else ""
        )

        parameters.extend(
            [filters.limit, filters.offset]
        )

        with self.connect() as connection:
            rows = connection.execute(
                f"""
                SELECT *
                FROM media_resources
                {where}
                ORDER BY resource_id
                LIMIT ? OFFSET ?
                """,
                parameters,
            ).fetchall()

        return [
            self._row_to_model(row)
            for row in rows
        ]

    def count(self) -> int:
        with self.connect() as connection:
            row = connection.execute(
                "SELECT COUNT(*) AS total FROM media_resources"
            ).fetchone()

        return int(row["total"])

    def statistics(self) -> dict[str, Any]:
        with self.connect() as connection:
            total = int(
                connection.execute(
                    "SELECT COUNT(*) AS total FROM media_resources"
                ).fetchone()["total"]
            )

            by_type = {
                row["resource_type"]: int(row["total"])
                for row in connection.execute(
                    """
                    SELECT resource_type, COUNT(*) AS total
                    FROM media_resources
                    GROUP BY resource_type
                    ORDER BY resource_type
                    """
                ).fetchall()
            }

            by_status = {
                row["status"]: int(row["total"])
                for row in connection.execute(
                    """
                    SELECT status, COUNT(*) AS total
                    FROM media_resources
                    GROUP BY status
                    ORDER BY status
                    """
                ).fetchall()
            }

            unique_oda = int(
                connection.execute(
                    """
                    SELECT COUNT(DISTINCT oda_id) AS total
                    FROM media_resources
                    """
                ).fetchone()["total"]
            )

            unique_types = int(
                connection.execute(
                    """
                    SELECT COUNT(DISTINCT resource_type) AS total
                    FROM media_resources
                    """
                ).fetchone()["total"]
            )

        return {
            "total_resources": total,
            "unique_oda": unique_oda,
            "unique_resource_types": unique_types,
            "by_type": by_type,
            "by_status": by_status,
        }

    def validate_repository(self) -> dict[str, Any]:
        with self.connect() as connection:
            empty_required = int(
                connection.execute(
                    """
                    SELECT COUNT(*) AS total
                    FROM media_resources
                    WHERE TRIM(resource_id) = ''
                       OR TRIM(oda_id) = ''
                       OR TRIM(canonical_id) = ''
                       OR TRIM(resource_type) = ''
                       OR TRIM(status) = ''
                    """
                ).fetchone()["total"]
            )

            duplicate_ids = int(
                connection.execute(
                    """
                    SELECT COUNT(*) AS total
                    FROM (
                        SELECT resource_id
                        FROM media_resources
                        GROUP BY resource_id
                        HAVING COUNT(*) > 1
                    )
                    """
                ).fetchone()["total"]
            )

            indexes = {
                row["name"]
                for row in connection.execute(
                    """
                    SELECT name
                    FROM sqlite_master
                    WHERE type = 'index'
                      AND tbl_name = 'media_resources'
                    """
                ).fetchall()
            }

        required_indexes = {
            "idx_rmr_oda_id",
            "idx_rmr_canonical_id",
            "idx_rmr_type",
            "idx_rmr_language",
            "idx_rmr_status",
            "idx_rmr_oda_type_status",
        }

        checks = {
            "database_exists": self.database_path.is_file(),
            "resources_present": self.count() > 0,
            "required_fields_complete": empty_required == 0,
            "resource_ids_unique": duplicate_ids == 0,
            "required_indexes_present": (
                required_indexes.issubset(indexes)
            ),
        }

        return {
            "passed": all(checks.values()),
            "checks": checks,
            "empty_required_fields": empty_required,
            "duplicate_resource_ids": duplicate_ids,
            "indexes": sorted(indexes),
        }

    def export_jsonl(
        self,
        output_path: str | Path,
        *,
        page_size: int = 5000,
    ) -> Path:
        """Exporta en flujo JSONL sin cargar todo en memoria."""

        if page_size < 1 or page_size > 10000:
            raise ValueError(
                "page_size debe estar entre 1 y 10000."
            )

        target = Path(output_path)
        target.parent.mkdir(parents=True, exist_ok=True)

        offset = 0

        with target.open(
            "w",
            encoding="utf-8",
            newline="\n",
        ) as stream:
            while True:
                page = self.query(
                    ConsultaRecursosRMR(
                        limit=page_size,
                        offset=offset,
                    )
                )

                if not page:
                    break

                for resource in page:
                    stream.write(
                        json.dumps(
                            asdict(resource),
                            ensure_ascii=False,
                        )
                        + "\n"
                    )

                offset += len(page)

        return target