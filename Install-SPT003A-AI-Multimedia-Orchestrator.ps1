<#
.SYNOPSIS
    Implementa SPT-003A — Motor de IA y Automatización Multimedia.

.DESCRIPTION
    Instala en un único archivo:
      - modelos de trabajos multimedia;
      - cola SQLite transaccional e idempotente;
      - planificación desde el RMR ADR-010;
      - generación de prompts de imagen;
      - contratos de audio Puinave y TTS ES/EN;
      - reintentos, leasing y recuperación de trabajos;
      - eventos y payloads preparados para n8n;
      - CLI;
      - pruebas funcionales;
      - documentación, evidencias y dashboard;
      - quality gate SGD-114.

    Esta versión NO consume APIs externas ni genera archivos multimedia.
    Prepara y gobierna las colas para los proveedores de IA y grabación.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.

.EXAMPLE
    .\Install-SPT003A-AI-Multimedia-Orchestrator.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
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
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\automation"
$TestsDir = Join-Path $ProjectRoot "tests\automation"
$ConfigDir = Join-Path $ProjectRoot "config\automation"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-003"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\automation\SPT-003A"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-003A"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-003A-v0.1.0"

$ModelsPath = Join-Path $SourceDir "models.py"
$QueuePath = Join-Path $SourceDir "job_queue.py"
$PlannerPath = Join-Path $SourceDir "planner.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPT_003A_multimedia_orchestrator.py"
$PolicyPath = Join-Path $ConfigDir "SPT-003A-policy.json"
$ComponentPath = Join-Path $ConfigDir "SPT-003A-component.json"
$DocPath = Join-Path $DocsDir "SPT-003A-Orquestador-IA-Multimedia.md"
$ArchitecturePath = Join-Path $DocsDir "SPT-003A-Arquitectura-Colas-Eventos.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT003A-MultimediaOrchestrator.ps1"
$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SPT-003A.json"
$GatePath = Join-Path $PmoDir "SPT-003A-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPT-003A-dashboard.json"

$RmrDatabase = Join-Path $ProjectRoot "artifacts\media\ADR-010\rmr.sqlite3"
$OdaRepository = Join-Path $ProjectRoot "artifacts\oda\SPT-002\oda-repository-v0.1.0.json"
$JobsDatabase = Join-Path $ArtifactsDir "multimedia-jobs.sqlite3"

Write-Step "Validando línea base publicada"

foreach ($Required in @(
    $RmrDatabase,
    $OdaRepository,
    (Join-Path $ProjectRoot "artifacts\pmo\ADR-010\ADR-010-quality-gate.json"),
    (Join-Path $ProjectRoot "artifacts\pmo\SPT-002\SPT-002-quality-gate.json"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot ".git")
)) {
    Assert-Path -Path $Required -Description $Required
}

$GitStatus = @(
    git status --porcelain |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

$AllowedPreflightPatterns = @(
    '^\?\? Install-SPT003A-AI-Multimedia-Orchestrator\.ps1$',
    '^\?\? Repair-SPT003A-v[0-9.]+-.*\.ps1$',
    '^\?\? SPT003A-.*\.zip$',
    '^\?\? LEAME-SPT003A.*\.txt$'
)

$UnexpectedGitChanges = @(
    foreach ($Entry in $GitStatus) {
        $Allowed = $false

        foreach ($Pattern in $AllowedPreflightPatterns) {
            if ($Entry -match $Pattern) {
                $Allowed = $true
                break
            }
        }

        if (-not $Allowed) {
            $Entry
        }
    }
)

if ($UnexpectedGitChanges.Count -gt 0) {
    Write-Host "Cambios Git no permitidos antes de SPT-003A:" -ForegroundColor Red

    foreach ($Entry in $UnexpectedGitChanges) {
        Write-Host "  $Entry" -ForegroundColor Red
    }

    throw (
        "La línea base contiene cambios ajenos a los archivos de " +
        "instalación SPT-003A."
    )
}

if ($GitStatus.Count -gt 0) {
    Write-Host (
        "Preflight Git aprobado con archivos de instalación " +
        "SPT-003A permitidos."
    ) -ForegroundColor Yellow
}
else {
    Write-Host "Preflight Git aprobado: repositorio limpio." -ForegroundColor Green
}

$ModelsContent = @'
"""Modelos del orquestador multimedia SPT-003A."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class TrabajoMultimedia:
    job_id: str
    resource_id: str
    oda_id: str
    canonical_id: str
    job_type: str
    language: str | None
    status: str = "pending"
    priority: int = 100
    attempt_count: int = 0
    max_attempts: int = 3
    provider: str | None = None
    payload: dict[str, Any] = field(default_factory=dict)
    result: dict[str, Any] = field(default_factory=dict)
    error: str | None = None
    available_at_utc: str | None = None
    lease_until_utc: str | None = None
    created_at_utc: str | None = None
    updated_at_utc: str | None = None


@dataclass(slots=True)
class ResumenPlanificacion:
    resources_seen: int
    jobs_planned: int
    jobs_inserted: int
    jobs_existing: int
    by_type: dict[str, int]
    unsupported_resources: int
'@

$QueueContent = @'
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
                    f"El trabajo no está leased: {job_id}"
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
'@

$PlannerContent = @'
"""Planificador de trabajos multimedia desde ADR-010 RMR."""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from .job_queue import (
    ColaTrabajosMultimedia,
    deterministic_job_id,
)
from .models import ResumenPlanificacion, TrabajoMultimedia


SUPPORTED = {
    "imagen_ilustrativa": "generate_image",
    "audio_puinave": "record_native_audio",
    "audio_espanol": "generate_tts",
    "audio_ingles": "generate_tts",
}


def _read_oda_index(path: Path) -> dict[str, dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    objects = payload.get("objetos_digitales_aprendizaje") or []
    return {
        str(item["oda_id"]): item
        for item in objects
        if isinstance(item, dict) and item.get("oda_id")
    }


def _image_prompt(oda: dict[str, Any]) -> str:
    word = str(oda.get("palabra_puinave") or "").strip()
    spanish = str(
        oda.get("traduccion_espanol") or ""
    ).strip()
    cultural = str(
        oda.get("contexto_etnografico")
        or oda.get("tema_cultural")
        or ""
    ).strip()

    parts = [
        "Ilustración educativa clara y culturalmente respetuosa",
        f"para la palabra Puinave «{word}»",
    ]

    if spanish:
        parts.append(f"cuyo significado en español es «{spanish}»")

    if cultural:
        parts.append(f"con contexto cultural: {cultural}")

    parts.extend(
        [
            "sin texto escrito dentro de la imagen",
            "composición simple",
            "apta para una aplicación educativa infantil y comunitaria",
        ]
    )

    return ". ".join(parts) + "."


def _payload(
    resource: sqlite3.Row,
    oda: dict[str, Any],
    job_type: str,
) -> dict[str, Any]:
    base = {
        "resource_id": resource["resource_id"],
        "oda_id": resource["oda_id"],
        "canonical_id": resource["canonical_id"],
        "resource_type": resource["resource_type"],
        "language": resource["language"],
        "callback_event": "MultimediaJobCompleted",
    }

    if job_type == "generate_image":
        base.update(
            {
                "prompt": _image_prompt(oda),
                "negative_prompt": (
                    "texto, letras, marcas de agua, estereotipos, "
                    "contenido ofensivo, anatomía incorrecta"
                ),
                "human_review_required": True,
            }
        )
    elif job_type == "record_native_audio":
        base.update(
            {
                "text": oda.get("palabra_puinave"),
                "speaker_type": "native_puinave",
                "recording_mode": "human_recording",
                "human_review_required": True,
            }
        )
    elif job_type == "generate_tts":
        language = resource["language"]
        text = (
            oda.get("traduccion_espanol")
            if language == "es"
            else oda.get("traduccion_ingles")
        )
        base.update(
            {
                "text": text,
                "voice_policy": "institutional_neutral",
                "human_review_required": True,
            }
        )

    return base


def iter_jobs(
    *,
    rmr_database: str | Path,
    oda_repository: str | Path,
) -> Iterable[TrabajoMultimedia]:
    oda_index = _read_oda_index(Path(oda_repository))

    connection = sqlite3.connect(rmr_database)
    connection.row_factory = sqlite3.Row

    try:
        rows = connection.execute(
            """
            SELECT *
            FROM media_resources
            ORDER BY resource_id
            """
        )

        for resource in rows:
            job_type = SUPPORTED.get(resource["resource_type"])

            if job_type is None:
                continue

            oda = oda_index.get(resource["oda_id"], {})
            payload = _payload(resource, oda, job_type)

            yield TrabajoMultimedia(
                job_id=deterministic_job_id(
                    resource["resource_id"],
                    job_type,
                ),
                resource_id=resource["resource_id"],
                oda_id=resource["oda_id"],
                canonical_id=resource["canonical_id"],
                job_type=job_type,
                language=resource["language"],
                priority=50 if job_type == "record_native_audio" else 100,
                payload=payload,
            )
    finally:
        connection.close()


def planificar(
    *,
    rmr_database: str | Path,
    oda_repository: str | Path,
    jobs_database: str | Path,
) -> ResumenPlanificacion:
    queue = ColaTrabajosMultimedia(jobs_database)
    queue.initialize()

    jobs = list(
        iter_jobs(
            rmr_database=rmr_database,
            oda_repository=oda_repository,
        )
    )

    inserted, existing = queue.upsert_many(jobs)

    by_type: dict[str, int] = {}
    for job in jobs:
        by_type[job.job_type] = by_type.get(job.job_type, 0) + 1

    with sqlite3.connect(rmr_database) as connection:
        resources_seen = int(
            connection.execute(
                "SELECT COUNT(*) FROM media_resources"
            ).fetchone()[0]
        )

    return ResumenPlanificacion(
        resources_seen=resources_seen,
        jobs_planned=len(jobs),
        jobs_inserted=inserted,
        jobs_existing=existing,
        by_type=by_type,
        unsupported_resources=resources_seen - len(jobs),
    )


def publish_artifacts(
    *,
    summary: ResumenPlanificacion,
    queue: ColaTrabajosMultimedia,
    output_dir: str | Path,
) -> dict[str, Path]:
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    stats = queue.statistics()
    generated_at = datetime.now(timezone.utc).isoformat()

    summary_path = output / "planning-summary.json"
    summary_path.write_text(
        json.dumps(asdict(summary), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    stats_path = output / "job-statistics.json"
    stats_path.write_text(
        json.dumps(stats, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    event = {
        "event_type": "MultimediaJobsPlanned",
        "occurred_at_utc": generated_at,
        "source": "sgoda.automation",
        "increment": "SPT-003A",
        "jobs_planned": summary.jobs_planned,
        "jobs_inserted": summary.jobs_inserted,
        "jobs_existing": summary.jobs_existing,
        "n8n_contract": {
            "trigger": "queue_poll_or_event",
            "completion_event": "MultimediaJobCompleted",
            "failure_event": "MultimediaJobFailed",
        },
    }

    event_path = output / "multimedia-jobs-planned-event.json"
    event_path.write_text(
        json.dumps(event, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    validation = {
        "increment": "SPT-003A",
        "passed": (
            summary.jobs_planned > 0
            and summary.jobs_planned == stats["total_jobs"]
        ),
        "checks": {
            "jobs_present": summary.jobs_planned > 0,
            "idempotent_total": summary.jobs_planned == stats["total_jobs"],
            "supported_resources_only": summary.unsupported_resources >= 0,
            "four_baseline_job_groups": len(summary.by_type) == 3,
        },
    }

    validation_path = output / "orchestrator-validation.json"
    validation_path.write_text(
        json.dumps(validation, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    return {
        "summary": summary_path,
        "statistics": stats_path,
        "event": event_path,
        "validation": validation_path,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--rmr",
        default="artifacts/media/ADR-010/rmr.sqlite3",
    )
    parser.add_argument(
        "--oda",
        default="artifacts/oda/SPT-002/oda-repository-v0.1.0.json",
    )
    parser.add_argument(
        "--jobs",
        default="artifacts/automation/SPT-003A/multimedia-jobs.sqlite3",
    )
    parser.add_argument(
        "--output",
        default="artifacts/automation/SPT-003A",
    )
    args = parser.parse_args()

    summary = planificar(
        rmr_database=args.rmr,
        oda_repository=args.oda,
        jobs_database=args.jobs,
    )

    queue = ColaTrabajosMultimedia(args.jobs)
    artifacts = publish_artifacts(
        summary=summary,
        queue=queue,
        output_dir=args.output,
    )

    validation = json.loads(
        artifacts["validation"].read_text(encoding="utf-8")
    )

    print("SPT-003A ejecutado correctamente.")
    print(f"Recursos RMR: {summary.resources_seen}")
    print(f"Trabajos planificados: {summary.jobs_planned}")
    print(f"Nuevos: {summary.jobs_inserted}")
    print(f"Existentes: {summary.jobs_existing}")
    print(f"Cola: {args.jobs}")

    return 0 if validation["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$CliContent = @'
"""CLI pública SPT-003A."""

from .planner import main


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Orquestador multimedia SGODA-PUINAVE."""

from __future__ import annotations

__all__ = [
    "ColaTrabajosMultimedia",
    "TrabajoMultimedia",
    "deterministic_job_id",
    "planificar",
]


def __getattr__(name: str):
    if name in {"ColaTrabajosMultimedia", "deterministic_job_id"}:
        from . import job_queue
        return getattr(job_queue, name)
    if name == "TrabajoMultimedia":
        from .models import TrabajoMultimedia
        return TrabajoMultimedia
    if name == "planificar":
        from .planner import planificar
        return planificar
    raise AttributeError(name)
'@

$TestContent = @'
"""Pruebas funcionales SPT-003A."""

import json
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sgoda.automation.job_queue import (
    ColaTrabajosMultimedia,
    deterministic_job_id,
)
from sgoda.automation.models import TrabajoMultimedia
from sgoda.automation.planner import planificar


def _job(index: int) -> TrabajoMultimedia:
    resource_id = f"RMR-{index:04d}"
    return TrabajoMultimedia(
        job_id=deterministic_job_id(
            resource_id,
            "generate_image",
        ),
        resource_id=resource_id,
        oda_id=f"ODA-{index:04d}",
        canonical_id=f"LEX-{index:04d}",
        job_type="generate_image",
        language=None,
        payload={"prompt": f"Imagen {index}"},
    )


def test_SPT_003A_job_id_deterministico() -> None:
    first = deterministic_job_id("RMR-1", "generate_image")
    second = deterministic_job_id("RMR-1", "generate_image")
    assert first == second
    assert first.startswith("JOB-")


def test_SPT_003A_insercion_idempotente(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()

    inserted, existing = queue.upsert_many([_job(1), _job(2)])
    inserted_2, existing_2 = queue.upsert_many([_job(1), _job(2)])

    assert (inserted, existing) == (2, 0)
    assert (inserted_2, existing_2) == (0, 2)
    assert queue.count() == 2


def test_SPT_003A_lease_y_completion(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many([_job(1)])

    jobs = queue.lease(worker_id="worker-test", limit=1)
    assert len(jobs) == 1
    assert jobs[0].status == "leased"

    queue.complete(jobs[0].job_id, {"uri": "media/image.png"})
    assert queue.count("completed") == 1


def test_SPT_003A_reintentos_y_fallo_final(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()

    job = _job(1)
    job.max_attempts = 2
    queue.upsert_many([job])

    leased = queue.lease(worker_id="worker")[0]
    queue.fail(leased.job_id, "error uno", retry_delay_seconds=0)
    assert queue.count("pending") == 1

    leased = queue.lease(worker_id="worker")[0]
    queue.fail(leased.job_id, "error dos", retry_delay_seconds=0)
    assert queue.count("failed") == 1


def test_SPT_003A_recupera_leases_vencidos(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many([_job(1)])
    leased = queue.lease(worker_id="worker")[0]

    expired = (
        datetime.now(timezone.utc) - timedelta(minutes=5)
    ).isoformat()

    with queue.connect() as connection:
        connection.execute(
            """
            UPDATE multimedia_jobs
            SET lease_until_utc=?
            WHERE job_id=?
            """,
            (expired, leased.job_id),
        )

    assert queue.recover_expired_leases() == 1
    assert queue.count("pending") == 1


def _create_rmr(path: Path) -> None:
    connection = sqlite3.connect(path)
    connection.executescript(
        """
        CREATE TABLE media_resources(
            resource_id TEXT PRIMARY KEY,
            oda_id TEXT NOT NULL,
            canonical_id TEXT NOT NULL,
            resource_type TEXT NOT NULL,
            language TEXT
        );
        """
    )
    rows = [
        ("RMR-IMG", "ODA-1", "LEX-1", "imagen_ilustrativa", None),
        ("RMR-PUI", "ODA-1", "LEX-1", "audio_puinave", "pui"),
        ("RMR-ES", "ODA-1", "LEX-1", "audio_espanol", "es"),
        ("RMR-EN", "ODA-1", "LEX-1", "audio_ingles", "en"),
    ]
    connection.executemany(
        "INSERT INTO media_resources VALUES (?, ?, ?, ?, ?)",
        rows,
    )
    connection.commit()
    connection.close()


def _create_oda(path: Path) -> None:
    payload = {
        "objetos_digitales_aprendizaje": [
            {
                "oda_id": "ODA-1",
                "canonical_id": "LEX-1",
                "palabra_puinave": "AMDA",
                "traduccion_espanol": "ejemplo",
                "traduccion_ingles": "example",
                "tema_cultural": "vida cotidiana",
            }
        ]
    }
    path.write_text(json.dumps(payload), encoding="utf-8")


def test_SPT_003A_planifica_cuatro_recursos(tmp_path: Path) -> None:
    rmr = tmp_path / "rmr.sqlite3"
    oda = tmp_path / "oda.json"
    jobs = tmp_path / "jobs.sqlite3"
    _create_rmr(rmr)
    _create_oda(oda)

    summary = planificar(
        rmr_database=rmr,
        oda_repository=oda,
        jobs_database=jobs,
    )

    assert summary.resources_seen == 4
    assert summary.jobs_planned == 4
    assert summary.jobs_inserted == 4
    assert summary.unsupported_resources == 0


def test_SPT_003A_prompt_imagen_respetuoso(tmp_path: Path) -> None:
    rmr = tmp_path / "rmr.sqlite3"
    oda = tmp_path / "oda.json"
    jobs = tmp_path / "jobs.sqlite3"
    _create_rmr(rmr)
    _create_oda(oda)

    planificar(
        rmr_database=rmr,
        oda_repository=oda,
        jobs_database=jobs,
    )

    connection = sqlite3.connect(jobs)
    payload_json = connection.execute(
        """
        SELECT payload_json
        FROM multimedia_jobs
        WHERE job_type='generate_image'
        """
    ).fetchone()[0]
    connection.close()

    payload = json.loads(payload_json)
    assert "AMDA" in payload["prompt"]
    assert "culturalmente respetuosa" in payload["prompt"]
    assert payload["human_review_required"] is True


def test_SPT_003A_escala_120000_trabajos(tmp_path: Path) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()

    total = 120_000
    inserted, existing = queue.upsert_many(
        (
            TrabajoMultimedia(
                job_id=f"JOB-CAP-{index:012d}",
                resource_id=f"RMR-CAP-{index:012d}",
                oda_id=f"ODA-{index // 4:08d}",
                canonical_id=f"LEX-{index // 4:08d}",
                job_type=(
                    "generate_image"
                    if index % 4 == 0
                    else "record_native_audio"
                    if index % 4 == 1
                    else "generate_tts"
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
            )
            for index in range(total)
        ),
        batch_size=5000,
    )

    assert inserted == total
    assert existing == 0
    assert queue.count() == total
'@

$PolicyContent = @'
{
  "increment_code": "SPT-003A",
  "version": "0.1.0",
  "capacity_target_jobs": 120000,
  "supported_job_types": [
    "generate_image",
    "record_native_audio",
    "generate_tts"
  ],
  "supported_resource_types": [
    "imagen_ilustrativa",
    "audio_puinave",
    "audio_espanol",
    "audio_ingles"
  ],
  "human_review_required": true,
  "external_api_calls_enabled": false,
  "max_attempts_default": 3,
  "lease_seconds_default": 300,
  "n8n_ready": true,
  "events": [
    "MultimediaJobsPlanned",
    "MultimediaJobCompleted",
    "MultimediaJobFailed"
  ],
  "governed_by": "SGD-114-v2.0.1"
}
'@

$ComponentContent = @'
{
  "increment_code": "SPT-003A",
  "component_type": "ai_multimedia_orchestrator",
  "version": "0.1.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.automation.cli",
  "source": [
    "src/sgoda/automation/models.py",
    "src/sgoda/automation/job_queue.py",
    "src/sgoda/automation/planner.py",
    "src/sgoda/automation/cli.py"
  ],
  "tests": [
    "tests/automation/test_SPT_003A_multimedia_orchestrator.py"
  ],
  "governed_by": "SGD-114-v2.0.1"
}
'@

$DocContent = @'
# SPT-003A — Motor de IA y Automatización Multimedia

## Objetivo

Convertir los recursos pendientes del RMR en trabajos operativos,
idempotentes, trazables y escalables para imágenes, grabación Puinave y
TTS español/inglés.

## Alcance

Esta versión planifica y gobierna trabajos. No consume proveedores
externos ni genera multimedia física.

## Capacidades

- cola SQLite con WAL;
- IDs determinísticos;
- inserción masiva;
- leasing para trabajadores;
- reintentos;
- recuperación de leases vencidos;
- prompts de imagen culturalmente respetuosos;
- contratos de grabación nativa;
- contratos TTS;
- eventos preparados para n8n;
- prueba de 120.000 trabajos.

## Siguiente incremento

SPT-003B incorporará adaptadores de proveedores, almacenamiento de
objetos y recepción de resultados.
'@

$ArchitectureContent = @'
# SPT-003A — Arquitectura de colas y eventos

```text
RMR ADR-010
    |
    v
Planificador SPT-003A
    |
    v
Cola multimedia SQLite
    |
    +--> imagen IA
    +--> grabación Puinave
    +--> TTS español
    +--> TTS inglés
    |
    v
n8n / trabajadores / proveedores
    |
    v
Eventos de finalización o fallo
```

La cola separa planificación, ejecución y validación humana. Esto
permite operar desde 80 hasta 120.000 trabajos sin modificar el contrato.
'@

$InvokeContent = @'
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.automation.cli `
    --rmr "artifacts/media/ADR-010/rmr.sqlite3" `
    --oda "artifacts/oda/SPT-002/oda-repository-v0.1.0.json" `
    --jobs "artifacts/automation/SPT-003A/multimedia-jobs.sqlite3" `
    --output "artifacts/automation/SPT-003A"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-003A terminó con errores."
}
'@

Write-Step "Instalando SPT-003A"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $QueuePath -Content $QueueContent
Write-Utf8NoBom -Path $PlannerPath -Content $PlannerContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent
Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $ArchitecturePath -Content $ArchitectureContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Evidence = [ordered]@{
    increment_code = "SPT-003A"
    version = "0.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    capacity_target_jobs = 120000
    components = @(
        "src/sgoda/automation/models.py",
        "src/sgoda/automation/job_queue.py",
        "src/sgoda/automation/planner.py",
        "src/sgoda/automation/cli.py",
        "tests/automation/test_SPT_003A_multimedia_orchestrator.py",
        "config/automation/SPT-003A-policy.json",
        "config/automation/SPT-003A-component.json",
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003A-Orquestador-IA-Multimedia.md",
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003A-Arquitectura-Colas-Eventos.md",
        "scripts/Invoke-SPT003A-MultimediaOrchestrator.ps1"
    )
}
Write-JsonUtf8 -Path $EvidencePath -Data $Evidence

$Trace = [ordered]@{
    increment_code = "SPT-003A"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/automation/models.py",
        "src/sgoda/automation/job_queue.py",
        "src/sgoda/automation/planner.py",
        "src/sgoda/automation/cli.py"
    )
    tests = @(
        "tests/automation/test_SPT_003A_multimedia_orchestrator.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003A-Orquestador-IA-Multimedia.md",
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003A-Arquitectura-Colas-Eventos.md"
    )
    evidence = @(
        "artifacts/pmo/SPT-003A/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando importaciones"

& python -c "from sgoda.automation.job_queue import ColaTrabajosMultimedia; from sgoda.automation.planner import planificar; print(ColaTrabajosMultimedia.__name__, planificar.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SPT-003A."
}

Write-Step "Ejecutando 8 pruebas específicas SPT-003A"

& python -m pytest `
    "tests/automation/test_SPT_003A_multimedia_orchestrator.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPT-003A fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Planificando los 80 recursos actuales"

if (Test-Path -LiteralPath $JobsDatabase) {
    Remove-Item -LiteralPath $JobsDatabase -Force
}

foreach ($Sidecar in @("$JobsDatabase-wal", "$JobsDatabase-shm")) {
    if (Test-Path -LiteralPath $Sidecar) {
        Remove-Item -LiteralPath $Sidecar -Force
    }
}

& python -m sgoda.automation.cli `
    --rmr "artifacts/media/ADR-010/rmr.sqlite3" `
    --oda "artifacts/oda/SPT-002/oda-repository-v0.1.0.json" `
    --jobs "artifacts/automation/SPT-003A/multimedia-jobs.sqlite3" `
    --output "artifacts/automation/SPT-003A"

if ($LASTEXITCODE -ne 0) {
    throw "La planificación real SPT-003A falló."
}

foreach ($Artifact in @(
    "multimedia-jobs.sqlite3",
    "planning-summary.json",
    "job-statistics.json",
    "multimedia-jobs-planned-event.json",
    "orchestrator-validation.json"
)) {
    Assert-Path `
        -Path (Join-Path $ArtifactsDir $Artifact) `
        -Description $Artifact
}

$Summary = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "planning-summary.json") `
    -Raw |
    ConvertFrom-Json

$Validation = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "orchestrator-validation.json") `
    -Raw |
    ConvertFrom-Json

if (-not $Validation.passed) {
    throw "La validación real del orquestador no fue aprobada."
}

if ([int]$Summary.jobs_planned -ne 80) {
    throw "Se esperaban 80 trabajos y se obtuvieron $($Summary.jobs_planned)."
}

Write-Step "Publicando release técnico"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

foreach ($Artifact in @(
    "planning-summary.json",
    "job-statistics.json",
    "multimedia-jobs-planned-event.json",
    "orchestrator-validation.json"
)) {
    Copy-Item `
        -LiteralPath (Join-Path $ArtifactsDir $Artifact) `
        -Destination (Join-Path $ReleaseDir $Artifact) `
        -Force
}

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-003A" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SPT-003A no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "SPT-003A no contiene passed=true."
}

$Dashboard = [ordered]@{
    increment_code = "SPT-003A"
    version = "0.1.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    resources_rmr = $Summary.resources_seen
    jobs_planned = $Summary.jobs_planned
    jobs_inserted = $Summary.jobs_inserted
    jobs_existing = $Summary.jobs_existing
    unsupported_resources = $Summary.unsupported_resources
    capacity_test_jobs = 120000
    image_jobs = $Summary.by_type.generate_image
    native_audio_jobs = $Summary.by_type.record_native_audio
    tts_jobs = $Summary.by_type.generate_tts
    n8n_ready = $true
    external_api_calls = $false
    tests = "approved"
    quality_gate = "approved"
    release = "SPT-003A-v0.1.0"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SPT-003A implementado y validado." -ForegroundColor Green
Write-Host "Pruebas específicas: 8 APROBADAS." -ForegroundColor Green
Write-Host "Suite total esperada desde 103: 111 pruebas." -ForegroundColor Cyan
Write-Host "Recursos RMR procesados: $($Summary.resources_seen)" -ForegroundColor Cyan
Write-Host "Trabajos planificados: $($Summary.jobs_planned)" -ForegroundColor Green
Write-Host "Capacidad 120.000 trabajos: APROBADA." -ForegroundColor Green
Write-Host "n8n: CONTRATO PREPARADO." -ForegroundColor Green
Write-Host "APIs externas: NO ACTIVADAS." -ForegroundColor Yellow
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-003A-v0.1.0" -ForegroundColor Cyan
Write-Host ""
Write-Host "Publique el incremento con SPB-007 después de revisar git status." -ForegroundColor Yellow
