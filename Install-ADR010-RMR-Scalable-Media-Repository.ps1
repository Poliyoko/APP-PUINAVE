<#
.SYNOPSIS
    Formaliza e implementa ADR-010 — Arquitectura Escalable del
    Repositorio Multimedia (RMR) para SGODA-PUINAVE.

.DESCRIPTION
    Instala en una sola ejecución:
      - ADR-010 formal;
      - modelo dinámico de recursos multimedia;
      - repositorio SQLite indexado y transaccional;
      - operaciones individuales y masivas;
      - migración de los 80 slots actuales desde SPT-002;
      - CLI;
      - estadísticas, validación, evento y manifiesto;
      - prueba real de capacidad con 120.000 recursos;
      - documentación, evidencias, trazabilidad y dashboard;
      - quality gate SGD-114 con cierre institucional de ADR-010.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas ADR-010 siempre se ejecutan.

.PARAMETER SkipCapacityTest
    Omite únicamente la prueba marcada como capacity_120k.
    No se recomienda para el cierre institucional.

.EXAMPLE
    .\Install-ADR010-RMR-Scalable-Media-Repository.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$SkipCapacityTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param([string]$Path, [string]$Description)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear: $Path"
    }

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 50

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo generar: $Path"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$env:PYTHONPATH = $SrcRoot

$MediaDir = Join-Path $SrcRoot "sgoda\media"
$TestsDir = Join-Path $ProjectRoot "tests\media"
$ConfigDir = Join-Path $ProjectRoot "config\media"
$AdrDir = Join-Path $ProjectRoot "docs\03_ADR"
$TechDocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\ADR-010"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\media\ADR-010"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\ADR-010"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\ADR-010-v1.0.0"

$OdaInput = Join-Path $ProjectRoot "artifacts\oda\SPT-002\oda-repository-v0.1.0.json"
$OdaValidation = Join-Path $ProjectRoot "artifacts\oda\SPT-002\oda-validation.json"

$ModelsPath = Join-Path $MediaDir "models.py"
$RepositoryPath = Join-Path $MediaDir "repository.py"
$MigrationPath = Join-Path $MediaDir "migration.py"
$CliPath = Join-Path $MediaDir "cli.py"
$InitPath = Join-Path $MediaDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_ADR_010_rmr_repository.py"
$ComponentPath = Join-Path $ConfigDir "ADR-010-component.json"
$PolicyPath = Join-Path $ConfigDir "rmr-policy.json"
$AdrPath = Join-Path $AdrDir "ADR-010-Arquitectura-Escalable-Repositorio-Multimedia-RMR.md"
$TechDocPath = Join-Path $TechDocsDir "ADR-010-Implementacion-RMR.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-ADR010-RMR.ps1"
$TracePath = Join-Path $PmoDir "traceability-ADR-010.json"
$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$GatePath = Join-Path $PmoDir "ADR-010-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "ADR-010-RMR-dashboard.json"
$DatabasePath = Join-Path $ArtifactsDir "rmr.sqlite3"

Write-Step "Validando línea base SPT-002"

foreach ($Required in @(
    $OdaInput,
    $OdaValidation,
    (Join-Path $ProjectRoot "artifacts\pmo\SPT-002\SPT-002-quality-gate.json"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "pytest.ini")
)) {
    Assert-Path -Path $Required -Description $Required
}

$Validation = Get-Content -LiteralPath $OdaValidation -Raw |
    ConvertFrom-Json

if (-not $Validation.passed) {
    throw "La línea base ODA de SPT-002 no está validada."
}

& python --version
if ($LASTEXITCODE -ne 0) {
    throw "Python no está disponible."
}

$ModelsContent = @'
"""Modelos dinámicos del Repositorio Multimedia Relacional (RMR)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class RecursoMultimediaRMR:
    """Recurso multimedia extensible y versionado."""

    resource_id: str
    oda_id: str
    canonical_id: str
    resource_type: str
    subtype: str = "principal"
    language: str | None = None
    variant: str | None = None
    provider: str | None = None
    version: str = "1.0.0"
    media_format: str | None = None
    uri: str | None = None
    checksum_sha256: str | None = None
    status: str = "pendiente"
    metadata: dict[str, Any] = field(default_factory=dict)
    created_at_utc: str | None = None
    updated_at_utc: str | None = None


@dataclass(slots=True)
class ConsultaRecursosRMR:
    """Filtros y paginación para consultar recursos."""

    oda_id: str | None = None
    canonical_id: str | None = None
    resource_type: str | None = None
    language: str | None = None
    status: str | None = None
    limit: int = 100
    offset: int = 0


@dataclass(slots=True)
class ResultadoMigracionRMR:
    """Resultado de migrar slots ODA al RMR."""

    total_oda: int
    total_resources: int
    inserted: int
    updated: int
    errors: list[dict[str, Any]]
'@

$RepositoryContent = @'
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
'@

$MigrationContent = @'
"""Migración de slots ODA al Repositorio Multimedia Relacional."""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import (
    RecursoMultimediaRMR,
    ResultadoMigracionRMR,
)
from .repository import (
    RepositorioMultimediaRMR,
    deterministic_resource_id,
)


def _read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(
            f"No se encontró el repositorio ODA: {path}"
        )

    return json.loads(path.read_text(encoding="utf-8"))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as stream:
        for chunk in iter(
            lambda: stream.read(1024 * 1024),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


def _language_from_type(
    resource_type: str,
) -> str | None:
    mapping = {
        "audio_puinave": "pui",
        "audio_espanol": "es",
        "audio_ingles": "en",
    }
    return mapping.get(resource_type)


def _resources_from_oda(
    oda: dict[str, Any],
) -> list[RecursoMultimediaRMR]:
    oda_id = str(oda.get("oda_id") or "").strip()
    canonical_id = str(
        oda.get("canonical_id") or ""
    ).strip()

    if not oda_id or not canonical_id:
        raise ValueError(
            "El ODA no contiene oda_id/canonical_id."
        )

    slots = oda.get("recursos") or []

    if not isinstance(slots, list):
        raise ValueError(
            f"Los recursos de {oda_id} no son una lista."
        )

    result: list[RecursoMultimediaRMR] = []

    for slot in slots:
        if not isinstance(slot, dict):
            continue

        resource_type = str(
            slot.get("tipo") or "recurso_desconocido"
        ).strip()

        subtype = str(
            slot.get("subtipo") or "principal"
        ).strip()

        language = (
            slot.get("idioma")
            or _language_from_type(resource_type)
        )

        variant = slot.get("variante")
        version = str(
            slot.get("version") or "1.0.0"
        )

        resource_id = deterministic_resource_id(
            oda_id=oda_id,
            resource_type=resource_type,
            subtype=subtype,
            language=language,
            variant=variant,
            version=version,
        )

        result.append(
            RecursoMultimediaRMR(
                resource_id=resource_id,
                oda_id=oda_id,
                canonical_id=canonical_id,
                resource_type=resource_type,
                subtype=subtype,
                language=language,
                variant=variant,
                provider=slot.get("proveedor"),
                version=version,
                media_format=slot.get("formato"),
                uri=slot.get("uri"),
                checksum_sha256=slot.get(
                    "checksum_sha256"
                ),
                status=str(
                    slot.get("estado") or "pendiente"
                ),
                metadata=dict(
                    slot.get("metadatos") or {}
                ),
            )
        )

    return result


def migrar_oda_a_rmr(
    *,
    oda_repository_path: str | Path,
    database_path: str | Path,
) -> ResultadoMigracionRMR:
    """Migra slots existentes de forma idempotente."""

    source_path = Path(oda_repository_path)
    payload = _read_json(source_path)
    objects = payload.get(
        "objetos_digitales_aprendizaje"
    )

    if not isinstance(objects, list) or not objects:
        raise ValueError(
            "El repositorio ODA no contiene objetos."
        )

    repository = RepositorioMultimediaRMR(
        database_path
    )
    repository.initialize()

    resources: list[RecursoMultimediaRMR] = []
    errors: list[dict[str, Any]] = []

    for position, oda in enumerate(objects, start=1):
        if not isinstance(oda, dict):
            errors.append(
                {
                    "position": position,
                    "code": "oda_not_object",
                }
            )
            continue

        try:
            resources.extend(
                _resources_from_oda(oda)
            )
        except ValueError as error:
            errors.append(
                {
                    "position": position,
                    "code": "invalid_oda",
                    "message": str(error),
                }
            )

    before = repository.count()
    processed = repository.bulk_upsert(resources)
    after = repository.count()

    inserted = max(after - before, 0)
    updated = processed - inserted

    return ResultadoMigracionRMR(
        total_oda=len(objects),
        total_resources=len(resources),
        inserted=inserted,
        updated=updated,
        errors=errors,
    )


def publicar_evidencias_rmr(
    *,
    repository: RepositorioMultimediaRMR,
    migration: ResultadoMigracionRMR,
    oda_repository_path: str | Path,
    output_dir: str | Path,
) -> dict[str, Path]:
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    generated_at = datetime.now(
        timezone.utc
    ).isoformat()

    stats = repository.statistics()
    validation = repository.validate_repository()

    migration_path = output / "rmr-migration-result.json"
    migration_path.write_text(
        json.dumps(
            asdict(migration),
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    stats_path = output / "rmr-statistics.json"
    stats_path.write_text(
        json.dumps(
            stats,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    validation_path = output / "rmr-validation.json"
    validation_path.write_text(
        json.dumps(
            validation,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    jsonl_path = repository.export_jsonl(
        output / "rmr-resources.jsonl"
    )

    event = {
        "event_type": "MediaRepositoryInitialized",
        "occurred_at_utc": generated_at,
        "source": "sgoda.media",
        "architecture_decision": "ADR-010",
        "database": repository.database_path.as_posix(),
        "total_resources": stats["total_resources"],
        "unique_oda": stats["unique_oda"],
        "source_oda_repository": (
            Path(oda_repository_path).as_posix()
        ),
        "source_oda_sha256": _sha256(
            Path(oda_repository_path)
        ),
    }

    event_path = output / "rmr-initialized-event.json"
    event_path.write_text(
        json.dumps(
            event,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    artifact_paths = [
        repository.database_path,
        migration_path,
        stats_path,
        validation_path,
        jsonl_path,
        event_path,
    ]

    manifest = {
        "release": "ADR-010-v1.0.0",
        "generated_at_utc": generated_at,
        "capacity_target_resources": 120000,
        "artifacts": [
            {
                "path": path.as_posix(),
                "sha256": _sha256(path),
                "size_bytes": path.stat().st_size,
            }
            for path in artifact_paths
        ],
    }

    manifest_path = output / "rmr-baseline-manifest.json"
    manifest_path.write_text(
        json.dumps(
            manifest,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    return {
        "migration": migration_path,
        "statistics": stats_path,
        "validation": validation_path,
        "jsonl": jsonl_path,
        "event": event_path,
        "manifest": manifest_path,
    }


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Inicializa el Repositorio Multimedia Relacional ADR-010."
        )
    )
    parser.add_argument(
        "--oda-repository",
        default=(
            "artifacts/oda/SPT-002/"
            "oda-repository-v0.1.0.json"
        ),
    )
    parser.add_argument(
        "--database",
        default="artifacts/media/ADR-010/rmr.sqlite3",
    )
    parser.add_argument(
        "--output",
        default="artifacts/media/ADR-010",
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()

    migration = migrar_oda_a_rmr(
        oda_repository_path=args.oda_repository,
        database_path=args.database,
    )

    repository = RepositorioMultimediaRMR(
        args.database
    )

    artifacts = publicar_evidencias_rmr(
        repository=repository,
        migration=migration,
        oda_repository_path=args.oda_repository,
        output_dir=args.output,
    )

    validation = json.loads(
        artifacts["validation"].read_text(
            encoding="utf-8"
        )
    )

    print("ADR-010 RMR ejecutado correctamente.")
    print(f"ODA migrados: {migration.total_oda}")
    print(
        "Recursos migrados: "
        f"{migration.total_resources}"
    )
    print(
        "Recursos en repositorio: "
        f"{repository.count()}"
    )
    print(
        "Validación: "
        f"{'APROBADA' if validation['passed'] else 'NO APROBADA'}"
    )
    print(f"Base de datos: {repository.database_path}")

    return 0 if validation["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$CliContent = @'
"""CLI pública de ADR-010 RMR."""

from .migration import main


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Repositorio Multimedia Relacional de SGODA-PUINAVE."""

from .migration import (
    migrar_oda_a_rmr,
    publicar_evidencias_rmr,
)
from .models import (
    ConsultaRecursosRMR,
    RecursoMultimediaRMR,
    ResultadoMigracionRMR,
)
from .repository import (
    RepositorioMultimediaRMR,
    deterministic_resource_id,
)

__all__ = [
    "ConsultaRecursosRMR",
    "RecursoMultimediaRMR",
    "RepositorioMultimediaRMR",
    "ResultadoMigracionRMR",
    "deterministic_resource_id",
    "migrar_oda_a_rmr",
    "publicar_evidencias_rmr",
]
'@

$TestContent = @'
"""Pruebas ADR-010 del Repositorio Multimedia Relacional."""

import json
import sqlite3
from pathlib import Path

import pytest

from sgoda.media import (
    ConsultaRecursosRMR,
    RecursoMultimediaRMR,
    RepositorioMultimediaRMR,
    deterministic_resource_id,
    migrar_oda_a_rmr,
)


def _resource(
    index: int,
    resource_type: str = "imagen_ilustrativa",
) -> RecursoMultimediaRMR:
    oda_id = f"ODA-{index:06d}"

    return RecursoMultimediaRMR(
        resource_id=deterministic_resource_id(
            oda_id=oda_id,
            resource_type=resource_type,
            language=None,
        ),
        oda_id=oda_id,
        canonical_id=f"LEX-{index:06d}",
        resource_type=resource_type,
        status="pendiente",
        metadata={"index": index},
    )


def test_ADR_010_crea_tablas_e_indices(
    tmp_path: Path,
) -> None:
    database = tmp_path / "rmr.sqlite3"
    repository = RepositorioMultimediaRMR(database)
    repository.initialize()

    with sqlite3.connect(database) as connection:
        tables = {
            row[0]
            for row in connection.execute(
                """
                SELECT name
                FROM sqlite_master
                WHERE type = 'table'
                """
            )
        }
        indexes = {
            row[0]
            for row in connection.execute(
                """
                SELECT name
                FROM sqlite_master
                WHERE type = 'index'
                  AND tbl_name = 'media_resources'
                """
            )
        }

    assert "media_resources" in tables
    assert "rmr_metadata" in tables
    assert "idx_rmr_oda_id" in indexes
    assert "idx_rmr_oda_type_status" in indexes


def test_ADR_010_upsert_es_idempotente(
    tmp_path: Path,
) -> None:
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr.sqlite3"
    )
    repository.initialize()

    resource = _resource(1)
    repository.upsert(resource)
    resource.status = "disponible"
    repository.upsert(resource)

    assert repository.count() == 1
    stored = repository.get(resource.resource_id)
    assert stored is not None
    assert stored.status == "disponible"


def test_ADR_010_admite_tipos_dinamicos(
    tmp_path: Path,
) -> None:
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr.sqlite3"
    )
    repository.initialize()

    types = [
        "imagen_ilustrativa",
        "audio_puinave",
        "video_cultural",
        "modelo_3d",
        "actividad_interactiva",
        "recurso_futuro_no_previsto",
    ]

    repository.bulk_upsert(
        _resource(index, resource_type)
        for index, resource_type in enumerate(
            types,
            start=1,
        )
    )

    statistics = repository.statistics()

    assert repository.count() == len(types)
    assert statistics["unique_resource_types"] == len(types)
    assert statistics["by_type"][
        "recurso_futuro_no_previsto"
    ] == 1


def test_ADR_010_consulta_paginada_y_filtrada(
    tmp_path: Path,
) -> None:
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr.sqlite3"
    )
    repository.initialize()

    resources = []

    for index in range(250):
        resource = _resource(
            index,
            "audio_puinave"
            if index % 2 == 0
            else "imagen_ilustrativa",
        )
        resource.language = (
            "pui"
            if resource.resource_type == "audio_puinave"
            else None
        )
        resources.append(resource)

    repository.bulk_upsert(resources)

    page = repository.query(
        ConsultaRecursosRMR(
            resource_type="audio_puinave",
            language="pui",
            limit=25,
            offset=25,
        )
    )

    assert len(page) == 25
    assert all(
        item.resource_type == "audio_puinave"
        for item in page
    )


def test_ADR_010_migra_slots_oda(
    tmp_path: Path,
) -> None:
    oda_repository = {
        "objetos_digitales_aprendizaje": [
            {
                "oda_id": "ODA-LEX-0001",
                "canonical_id": "LEX-0001",
                "recursos": [
                    {
                        "tipo": "imagen_ilustrativa",
                        "estado": "pendiente_generacion_ia",
                    },
                    {
                        "tipo": "audio_puinave",
                        "estado": "pendiente_grabacion_nativa",
                    },
                    {
                        "tipo": "audio_espanol",
                        "estado": "pendiente_tts",
                    },
                    {
                        "tipo": "audio_ingles",
                        "estado": "pendiente_tts",
                    },
                ],
            }
        ]
    }

    source = tmp_path / "oda.json"
    source.write_text(
        json.dumps(oda_repository),
        encoding="utf-8",
    )

    database = tmp_path / "rmr.sqlite3"

    result = migrar_oda_a_rmr(
        oda_repository_path=source,
        database_path=database,
    )

    repository = RepositorioMultimediaRMR(database)

    assert result.total_oda == 1
    assert result.total_resources == 4
    assert result.errors == []
    assert repository.count() == 4


def test_ADR_010_exporta_jsonl_en_flujo(
    tmp_path: Path,
) -> None:
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr.sqlite3"
    )
    repository.initialize()
    repository.bulk_upsert(
        _resource(index)
        for index in range(1000)
    )

    output = repository.export_jsonl(
        tmp_path / "resources.jsonl",
        page_size=137,
    )

    lines = output.read_text(
        encoding="utf-8"
    ).splitlines()

    assert len(lines) == 1000
    assert json.loads(lines[0])["resource_id"]


@pytest.mark.capacity_120k
def test_ADR_010_capacidad_real_120000_recursos(
    tmp_path: Path,
) -> None:
    """Prueba funcional real del objetivo mínimo de capacidad."""

    total = 120_000
    repository = RepositorioMultimediaRMR(
        tmp_path / "rmr-capacity.sqlite3"
    )
    repository.initialize()

    processed = repository.bulk_upsert(
        (
            RecursoMultimediaRMR(
                resource_id=f"RMR-CAP-{index:012d}",
                oda_id=f"ODA-{index // 10:08d}",
                canonical_id=f"LEX-{index // 10:08d}",
                resource_type=(
                    "imagen_ilustrativa"
                    if index % 4 == 0
                    else "audio_puinave"
                    if index % 4 == 1
                    else "audio_espanol"
                    if index % 4 == 2
                    else "audio_ingles"
                ),
                language=(
                    None
                    if index % 4 == 0
                    else "pui"
                    if index % 4 == 1
                    else "es"
                    if index % 4 == 2
                    else "en"
                ),
                status="pendiente",
            )
            for index in range(total)
        ),
        batch_size=5000,
    )

    validation = repository.validate_repository()
    statistics = repository.statistics()

    assert processed == total
    assert repository.count() == total
    assert statistics["total_resources"] == total
    assert statistics["unique_resource_types"] == 4
    assert validation["passed"] is True
'@

$ComponentConfig = @'
{
  "increment_code": "ADR-010",
  "decision": "Arquitectura Escalable del Repositorio Multimedia",
  "component_type": "relational_media_repository",
  "version": "1.0.0",
  "status": "institutionally_closed",
  "entrypoint": "sgoda.media.cli",
  "capacity_target_resources": 120000,
  "storage_engine": "SQLite",
  "source": [
    "src/sgoda/media/models.py",
    "src/sgoda/media/repository.py",
    "src/sgoda/media/migration.py",
    "src/sgoda/media/cli.py"
  ],
  "tests": [
    "tests/media/test_ADR_010_rmr_repository.py"
  ],
  "governed_by": "SGD-114"
}
'@

$PolicyContent = @'
{
  "policy_code": "ADR-010-RMR",
  "version": "1.0.0",
  "capacity_target_resources": 120000,
  "design_limit": "unbounded_by_resource_type",
  "storage_model": "one_row_per_media_resource",
  "dynamic_resource_types": true,
  "preserve_unknown_resource_types": true,
  "deterministic_resource_ids": true,
  "pagination_required": true,
  "bulk_operations_required": true,
  "streaming_export_required": true,
  "required_indexes": [
    "oda_id",
    "canonical_id",
    "resource_type",
    "language",
    "status",
    "oda_id_resource_type_status"
  ],
  "lifecycle_statuses_extensible": true,
  "source_oda_release": "SPT-002-v0.1.0"
}
'@

$AdrContent = @'
# ADR-010 — Arquitectura Escalable del Repositorio Multimedia (RMR)

## Estado

**Aceptada, implementada y sujeta a cierre institucional mediante
SGD-114.**

## Contexto

SPT-002 creó 20 ODA y 80 espacios multimedia iniciales. Esa cantidad es
solamente una línea base de validación. El proyecto debe prepararse para
administrar al menos 120.000 recursos y, posteriormente, volúmenes
superiores sin rediseñar el modelo.

Un ODA puede contener imágenes, audios, videos, documentos, animaciones,
modelos 3D, actividades, evaluaciones y tipos todavía no definidos.

## Decisión

Se adopta un **Repositorio Multimedia Relacional (RMR)** independiente
del documento ODA.

Cada recurso se almacena como una entidad individual con:

- `resource_id`;
- `oda_id`;
- `canonical_id`;
- tipo y subtipo;
- idioma y variante;
- proveedor;
- versión y formato;
- URI y checksum;
- estado de ciclo de vida;
- metadatos extensibles;
- fechas de creación y actualización.

La implementación inicial utiliza SQLite con WAL, transacciones,
operaciones masivas, paginación, índices y exportación JSONL en flujo.

## Capacidad

La arquitectura fija como objetivo mínimo probado **120.000 recursos**.
El modelo no contiene una enumeración cerrada de tipos y puede escalar a
cientos de miles de filas mediante el mismo contrato.

## Consecuencias positivas

- Los ODA no crecen como documentos monolíticos.
- Los recursos se consultan y actualizan de forma independiente.
- Los motores IA y n8n pueden registrar nuevos recursos.
- Se preservan tipos multimedia futuros.
- El dashboard puede medir producción, disponibilidad y pendientes.
- La base puede migrarse posteriormente a PostgreSQL conservando el
  contrato relacional.

## Restricciones

- No se almacenan binarios dentro de SQLite.
- Los binarios se ubicarán en almacenamiento de objetos o archivos.
- El RMR conserva URI, checksum y metadatos.
- Todo recurso debe tener trazabilidad a ODA y registro canónico.

## Evidencia de decisión

- Código: `src/sgoda/media/`
- Pruebas: `tests/media/test_ADR_010_rmr_repository.py`
- Capacidad: prueba automatizada de 120.000 recursos
- Evidencias: `artifacts/media/ADR-010/`
- Quality gate: `artifacts/pmo/ADR-010/ADR-010-quality-gate.json`
'@

$TechDocContent = @'
# ADR-010 — Implementación técnica del RMR

## Flujo

```text
Repositorio ODA SPT-002
          |
          v
Migrador de slots multimedia
          |
          v
RMR SQLite indexado
          |
   +------+------+------+------+
   |             |             |
Imágenes      Audios        Tipos futuros
   |             |             |
   +------+------+------+------+
          |
          v
IA / n8n / API / Dashboard
```

## Operaciones disponibles

- inicialización idempotente;
- inserción o actualización individual;
- inserción masiva por lotes;
- consulta por ODA, registro, tipo, idioma y estado;
- paginación;
- estadísticas;
- validación estructural;
- exportación JSONL en flujo;
- migración de los 80 slots actuales.

## Escalabilidad

La prueba `capacity_120k` crea e indexa 120.000 recursos reales en una
base temporal y verifica conteo, tipos, campos obligatorios, unicidad e
índices.
'@

$InvokeContent = @'
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.media.cli `
    --oda-repository "artifacts/oda/SPT-002/oda-repository-v0.1.0.json" `
    --database "artifacts/media/ADR-010/rmr.sqlite3" `
    --output "artifacts/media/ADR-010"

if ($LASTEXITCODE -ne 0) {
    throw "ADR-010 RMR terminó con errores."
}
'@

Write-Step "Instalando ADR-010 y el RMR"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $RepositoryPath -Content $RepositoryContent
Write-Utf8NoBom -Path $MigrationPath -Content $MigrationContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentConfig
Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $AdrPath -Content $AdrContent
Write-Utf8NoBom -Path $TechDocPath -Content $TechDocContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Registrando marcador pytest de capacidad"

$PytestIniPath = Join-Path $ProjectRoot "pytest.ini"
$PytestIniContent = Get-Content -LiteralPath $PytestIniPath -Raw

if ($PytestIniContent -notmatch "capacity_120k") {
    $UpdatedPytestIni = $PytestIniContent.TrimEnd() + @"

markers =
    capacity_120k: prueba de capacidad real con 120000 recursos multimedia
"@
    Write-Utf8NoBom -Path $PytestIniPath -Content $UpdatedPytestIni
}
else {
    Write-Host "El marcador capacity_120k ya existe." -ForegroundColor Yellow
}

Write-Step "Generando evidencias y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Evidence = [ordered]@{
    increment_code = "ADR-010"
    version = "1.0.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    capacity_target_resources = 120000
    source_oda_release = "SPT-002-v0.1.0"
    components = @(
        "src/sgoda/media/models.py",
        "src/sgoda/media/repository.py",
        "src/sgoda/media/migration.py",
        "src/sgoda/media/cli.py",
        "tests/media/test_ADR_010_rmr_repository.py",
        "config/media/ADR-010-component.json",
        "config/media/rmr-policy.json",
        "docs/03_ADR/ADR-010-Arquitectura-Escalable-Repositorio-Multimedia-RMR.md",
        "docs/05_Fase_Tecnologica/ADR-010/ADR-010-Implementacion-RMR.md",
        "scripts/Invoke-ADR010-RMR.ps1"
    )
}
Write-JsonUtf8 -Path $EvidencePath -Data $Evidence

$Trace = [ordered]@{
    increment_code = "ADR-010"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/media/models.py",
        "src/sgoda/media/repository.py",
        "src/sgoda/media/migration.py",
        "src/sgoda/media/cli.py",
        "config/media/ADR-010-component.json",
        "config/media/rmr-policy.json"
    )
    tests = @(
        "tests/media/test_ADR_010_rmr_repository.py"
    )
    documentation = @(
        "docs/03_ADR/ADR-010-Arquitectura-Escalable-Repositorio-Multimedia-RMR.md",
        "docs/05_Fase_Tecnologica/ADR-010/ADR-010-Implementacion-RMR.md"
    )
    evidence = @(
        "artifacts/pmo/ADR-010/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando importaciones"

& python -c "from sgoda.media import RepositorioMultimediaRMR, deterministic_resource_id; print(RepositorioMultimediaRMR.__name__, deterministic_resource_id(oda_id='ODA-1', resource_type='video_cultural'))"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de ADR-010."
}

Write-Step "Ejecutando pruebas funcionales ADR-010"

if ($SkipCapacityTest) {
    & python -m pytest `
        "tests/media/test_ADR_010_rmr_repository.py" `
        -q `
        -m "not capacity_120k"
}
else {
    & python -m pytest `
        "tests/media/test_ADR_010_rmr_repository.py" `
        -q
}

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas ADR-010 terminaron con errores."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    if ($SkipCapacityTest) {
        & python -m pytest -m "not capacity_120k"
    }
    else {
        & python -m pytest
    }

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Migrando los 80 recursos actuales al RMR"

if (Test-Path -LiteralPath $DatabasePath) {
    Remove-Item -LiteralPath $DatabasePath -Force
}

$WalPath = "$DatabasePath-wal"
$ShmPath = "$DatabasePath-shm"

foreach ($Sidecar in @($WalPath, $ShmPath)) {
    if (Test-Path -LiteralPath $Sidecar) {
        Remove-Item -LiteralPath $Sidecar -Force
    }
}

& python -m sgoda.media.cli `
    --oda-repository "artifacts/oda/SPT-002/oda-repository-v0.1.0.json" `
    --database "artifacts/media/ADR-010/rmr.sqlite3" `
    --output "artifacts/media/ADR-010"

if ($LASTEXITCODE -ne 0) {
    throw "La migración real al RMR terminó con errores."
}

foreach ($Artifact in @(
    "rmr.sqlite3",
    "rmr-migration-result.json",
    "rmr-statistics.json",
    "rmr-validation.json",
    "rmr-resources.jsonl",
    "rmr-initialized-event.json",
    "rmr-baseline-manifest.json"
)) {
    Assert-Path `
        -Path (Join-Path $ArtifactsDir $Artifact) `
        -Description $Artifact
}

$Statistics = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "rmr-statistics.json") `
    -Raw |
    ConvertFrom-Json

$RmrValidation = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "rmr-validation.json") `
    -Raw |
    ConvertFrom-Json

if (-not $RmrValidation.passed) {
    throw "La validación real del RMR no fue aprobada."
}

if ([int]$Statistics.total_resources -ne 80) {
    throw (
        "Se esperaban 80 recursos migrados y se obtuvieron " +
        $Statistics.total_resources
    )
}

Write-Step "Publicando release ADR-010"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

foreach ($Artifact in @(
    "rmr.sqlite3",
    "rmr-migration-result.json",
    "rmr-statistics.json",
    "rmr-validation.json",
    "rmr-resources.jsonl",
    "rmr-initialized-event.json",
    "rmr-baseline-manifest.json"
)) {
    Copy-Item `
        -LiteralPath (Join-Path $ArtifactsDir $Artifact) `
        -Destination (Join-Path $ReleaseDir $Artifact) `
        -Force
}

$Trace.evidence = @(
    "artifacts/pmo/ADR-010/implementation-evidence.json",
    "artifacts/media/ADR-010/rmr.sqlite3",
    "artifacts/media/ADR-010/rmr-migration-result.json",
    "artifacts/media/ADR-010/rmr-statistics.json",
    "artifacts/media/ADR-010/rmr-validation.json",
    "artifacts/media/ADR-010/rmr-resources.jsonl",
    "artifacts/media/ADR-010/rmr-baseline-manifest.json",
    "releases/ADR-010-v1.0.0/"
)
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Ejecutando quality gate y cierre ADR-010"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "ADR-010" `
    --status "institutionally_closed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    $Failure = Get-Content -LiteralPath $GatePath -Raw |
        ConvertFrom-Json
    $Missing = $Failure.missing_categories -join ", "
    throw "Quality gate ADR-010 no aprobado. Faltan: $Missing"
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "ADR-010 no tiene passed=true."
}

if (-not $Gate.closure_authorized) {
    throw "SGD-114 no autorizó el cierre de ADR-010."
}

$CapacityStatus = if ($SkipCapacityTest) {
    "not_executed"
}
else {
    "approved_120000"
}

$Dashboard = [ordered]@{
    decision = "ADR-010"
    version = "1.0.0"
    status = "institutionally_closed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    current_resources = $Statistics.total_resources
    current_oda = $Statistics.unique_oda
    current_resource_types = $Statistics.unique_resource_types
    capacity_target_resources = 120000
    capacity_test = $CapacityStatus
    dynamic_resource_types = $true
    bulk_operations = "implemented"
    pagination = "implemented"
    streaming_jsonl = "implemented"
    indexed_repository = "implemented"
    validation = "approved"
    quality_gate = "authorized"
    release = "ADR-010-v1.0.0"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "ADR-010 formalizado, implementado y cerrado." -ForegroundColor Green
Write-Host "RMR: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Recursos actuales migrados: $($Statistics.total_resources)" -ForegroundColor Cyan
Write-Host "ODA actuales: $($Statistics.unique_oda)" -ForegroundColor Cyan
Write-Host "Tipos actuales: $($Statistics.unique_resource_types)" -ForegroundColor Cyan

if ($SkipCapacityTest) {
    Write-Host "Prueba 120.000: OMITIDA POR PARÁMETRO." -ForegroundColor Yellow
}
else {
    Write-Host "Prueba 120.000: APROBADA." -ForegroundColor Green
}

Write-Host "Validación RMR: APROBADA." -ForegroundColor Green
Write-Host "Cierre institucional: AUTORIZADO." -ForegroundColor Green
Write-Host "Base de datos: artifacts\media\ADR-010\rmr.sqlite3" -ForegroundColor Cyan
Write-Host "Release: releases\ADR-010-v1.0.0" -ForegroundColor Cyan
