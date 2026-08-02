<#
.SYNOPSIS
    Implementa SPT-006 v0.1.0 — Pipeline Automatizado de Enriquecimiento
    Multimedia Multilingüe.

.DESCRIPTION
    Instala una primera versión funcional y gobernada del pipeline que:
      - lee el Repositorio Léxico Canónico;
      - detecta traducción inglesa y recursos faltantes;
      - planifica traducción EN, TTS ES, TTS EN, imagen y video opcional;
      - genera recursos simulados para pruebas sin llamadas externas;
      - registra trabajos idempotentes y reanudables;
      - produce manifiestos de reproducción automática;
      - prepara actualización de ODA y RMR;
      - aplica estados de validación lingüística y cultural;
      - genera evidencias, release, dashboard y quality gate;
      - actualiza SGD-115.

    Esta versión NO activa proveedores reales ni reproduce automáticamente
    video sin consentimiento del usuario.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.

.PARAMETER BatchSize
    Tamaño del lote demostrativo. Valor predeterminado: 20.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [ValidateRange(1, 1000)]
    [int]$BatchSize = 20
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

    [System.IO.File]::WriteAllText(
        $Path,
        (($Data | ConvertTo-Json -Depth 50) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\enrichment"
$TestsDir = Join-Path $ProjectRoot "tests\enrichment"
$ConfigDir = Join-Path $ProjectRoot "config\enrichment"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-006"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\enrichment\SPT-006"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-006"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-006-v0.1.0"

$CanonicalPath = Join-Path `
    $ProjectRoot `
    "artifacts\rlb\SPT-001B-P08\canonical-repository-v1.0.0.json"

$OdaPath = Join-Path `
    $ProjectRoot `
    "artifacts\oda\SPT-002\oda-repository-v0.1.0.json"

$RmrPath = Join-Path `
    $ProjectRoot `
    "artifacts\media\ADR-010\rmr.sqlite3"

$ModelsPath = Join-Path $SourceDir "models.py"
$PlannerPath = Join-Path $SourceDir "planner.py"
$ProvidersPath = Join-Path $SourceDir "providers.py"
$PipelinePath = Join-Path $SourceDir "pipeline.py"
$PlaybackPath = Join-Path $SourceDir "playback.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPT_006_multilingual_multimedia_pipeline.py"

$PolicyPath = Join-Path $ConfigDir "SPT-006-enrichment-policy.json"
$PlaybackPolicyPath = Join-Path $ConfigDir "SPT-006-playback-policy.json"
$ComponentPath = Join-Path $ConfigDir "SPT-006-component.json"

$DocPath = Join-Path $DocsDir "SPT-006-Pipeline-Enriquecimiento-Multimedia.md"
$QualityDocPath = Join-Path $DocsDir "SPT-006-Validacion-Linguistica-Cultural.md"
$PlaybackDocPath = Join-Path $DocsDir "SPT-006-Reproduccion-Automatica-Configurable.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT006-EnrichmentPipeline.ps1"

$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SPT-006.json"
$GatePath = Join-Path $PmoDir "SPT-006-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPT-006-dashboard.json"

Write-Step "Validando línea base tecnológica"

foreach ($Required in @(
    $CanonicalPath,
    $OdaPath,
    $RmrPath,
    (Join-Path $ProjectRoot "src\sgoda\automation\job_queue.py"),
    (Join-Path $ProjectRoot "src\sgoda\automation\adapters\processor.py"),
    (Join-Path $ProjectRoot "src\sgoda\media\repository.py"),
    (Join-Path $ProjectRoot "src\sgoda\oda\engine.py"),
    (Join-Path $ProjectRoot "src\sgoda\installer_builder\generator.py"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot ".git")
)) {
    Assert-Path -Path $Required -Description $Required
}

$GitStatus = @(git status --porcelain | Where-Object { $_ })
$AllowedPatterns = @(
    '^\?\? Install-SPT006-Automated-Multilingual-Multimedia-Pipeline\.ps1$',
    '^\?\? Repair-SPT006-v[0-9.]+-.*\.ps1$',
    '^\?\? SPT006-.*\.zip$',
    '^\?\? LEAME-SPT006.*\.txt$'
)

$Unexpected = @(
    foreach ($Entry in $GitStatus) {
        $Allowed = $false
        foreach ($Pattern in $AllowedPatterns) {
            if ($Entry -match $Pattern) {
                $Allowed = $true
                break
            }
        }
        if (-not $Allowed) { $Entry }
    }
)

if ($Unexpected.Count -gt 0) {
    $Unexpected | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "La línea base contiene cambios ajenos a SPT-006."
}

$ModelsContent = @'
"""Modelos del pipeline de enriquecimiento multimedia."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


RESOURCE_TYPES = (
    "translation_en",
    "audio_es",
    "audio_en",
    "image",
    "video",
)


@dataclass(slots=True)
class EnrichmentNeed:
    canonical_id: str
    resource_type: str
    priority: int
    required: bool
    reason: str


@dataclass(slots=True)
class EnrichmentJob:
    job_id: str
    canonical_id: str
    resource_type: str
    source_text: str
    target_language: str | None
    status: str = "pending"
    attempts: int = 0
    provider: str = "mock"
    validation_status: str = "pending"
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class GeneratedResource:
    resource_id: str
    canonical_id: str
    resource_type: str
    status: str
    uri: str | None
    sha256: str | None
    provider: str
    validation_status: str
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class PlaybackManifest:
    canonical_id: str
    sequence: list[str]
    autoplay_enabled: bool
    autoplay_video: bool
    stop_on_error: bool
    resources: dict[str, str | None]
'@

$PlannerContent = @'
"""Detección de necesidades y planificación idempotente."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from .models import EnrichmentJob, EnrichmentNeed


def records_from_payload(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]

    if not isinstance(payload, dict):
        return []

    for key in (
        "records",
        "entries",
        "items",
        "palabras",
        "repository",
        "canonical_records",
    ):
        value = payload.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]

    for value in payload.values():
        if isinstance(value, list) and all(
            isinstance(item, dict) for item in value
        ):
            return list(value)

    return []


def field(record: dict[str, Any], *names: str) -> Any:
    for name in names:
        value = record.get(name)
        if value not in (None, ""):
            return value
    return None


def detect_needs(record: dict[str, Any]) -> list[EnrichmentNeed]:
    canonical_id = str(
        field(record, "canonical_id", "id", "lexical_id") or ""
    )
    spanish = field(
        record,
        "espanol",
        "español",
        "spanish",
        "traduccion_espanol",
    )
    english = field(
        record,
        "ingles",
        "inglés",
        "english",
        "traduccion_ingles",
    )

    needs: list[EnrichmentNeed] = []

    if not english:
        needs.append(
            EnrichmentNeed(
                canonical_id=canonical_id,
                resource_type="translation_en",
                priority=10,
                required=True,
                reason="Traducción inglesa ausente.",
            )
        )

    needs.append(
        EnrichmentNeed(
            canonical_id=canonical_id,
            resource_type="audio_es",
            priority=20,
            required=True,
            reason="Audio español requerido.",
        )
    )
    needs.append(
        EnrichmentNeed(
            canonical_id=canonical_id,
            resource_type="audio_en",
            priority=30,
            required=True,
            reason="Audio inglés requerido.",
        )
    )
    needs.append(
        EnrichmentNeed(
            canonical_id=canonical_id,
            resource_type="image",
            priority=40,
            required=True,
            reason="Apoyo visual requerido o no aplicable.",
        )
    )
    needs.append(
        EnrichmentNeed(
            canonical_id=canonical_id,
            resource_type="video",
            priority=50,
            required=False,
            reason="Video educativo opcional.",
        )
    )

    if not spanish:
        return [
            item for item in needs
            if item.resource_type not in {"audio_es", "translation_en"}
        ]

    return needs


def create_job(
    record: dict[str, Any],
    need: EnrichmentNeed,
) -> EnrichmentJob:
    canonical_id = need.canonical_id
    spanish = str(
        field(
            record,
            "espanol",
            "español",
            "spanish",
            "traduccion_espanol",
        )
        or ""
    )
    english = str(
        field(
            record,
            "ingles",
            "inglés",
            "english",
            "traduccion_ingles",
        )
        or ""
    )

    source_text = spanish
    target_language: str | None = None

    if need.resource_type == "translation_en":
        target_language = "en"
    elif need.resource_type == "audio_es":
        target_language = "es"
    elif need.resource_type == "audio_en":
        target_language = "en"
        source_text = english or spanish
    elif need.resource_type in {"image", "video"}:
        target_language = None

    raw = f"{canonical_id}|{need.resource_type}|{source_text}"
    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:20]

    return EnrichmentJob(
        job_id=f"ENR-{digest.upper()}",
        canonical_id=canonical_id,
        resource_type=need.resource_type,
        source_text=source_text,
        target_language=target_language,
        metadata={
            "priority": need.priority,
            "required": need.required,
            "reason": need.reason,
        },
    )


def plan_repository(
    canonical_path: str | Path,
    *,
    limit: int | None = None,
) -> tuple[list[dict[str, Any]], list[EnrichmentJob]]:
    payload = json.loads(
        Path(canonical_path).read_text(encoding="utf-8")
    )
    records = records_from_payload(payload)

    if limit is not None:
        records = records[:limit]

    jobs: list[EnrichmentJob] = []
    seen: set[str] = set()

    for record in records:
        for need in detect_needs(record):
            job = create_job(record, need)
            if job.job_id not in seen:
                jobs.append(job)
                seen.add(job.job_id)

    jobs.sort(
        key=lambda item: (
            int(item.metadata["priority"]),
            item.canonical_id,
            item.resource_type,
        )
    )
    return records, jobs
'@

$ProvidersContent = @'
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
'@

$PlaybackContent = @'
"""Construcción del manifiesto de reproducción automática."""

from __future__ import annotations

from .models import GeneratedResource, PlaybackManifest


DEFAULT_SEQUENCE = [
    "image",
    "audio_puinave",
    "audio_es",
    "audio_en",
    "video",
]


def build_playback_manifest(
    *,
    canonical_id: str,
    resources: list[GeneratedResource],
    autoplay_enabled: bool = True,
    autoplay_video: bool = False,
) -> PlaybackManifest:
    resource_map: dict[str, str | None] = {
        "image": None,
        "audio_puinave": None,
        "audio_es": None,
        "audio_en": None,
        "video": None,
    }

    for resource in resources:
        if resource.resource_type in resource_map:
            resource_map[resource.resource_type] = resource.uri

    sequence = [
        item for item in DEFAULT_SEQUENCE
        if resource_map.get(item) is not None
    ]

    if not autoplay_video:
        sequence = [item for item in sequence if item != "video"]

    return PlaybackManifest(
        canonical_id=canonical_id,
        sequence=sequence,
        autoplay_enabled=autoplay_enabled,
        autoplay_video=autoplay_video,
        stop_on_error=False,
        resources=resource_map,
    )
'@

$PipelineContent = @'
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
'@

$CliContent = @'
"""CLI de SPT-006."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .pipeline import run_pipeline


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--canonical",
        default=(
            "artifacts/rlb/SPT-001B-P08/"
            "canonical-repository-v1.0.0.json"
        ),
    )
    parser.add_argument(
        "--jobs-db",
        default=(
            "artifacts/enrichment/SPT-006/"
            "enrichment-jobs.sqlite3"
        ),
    )
    parser.add_argument(
        "--resources",
        default=(
            "artifacts/enrichment/SPT-006/"
            "mock-resources"
        ),
    )
    parser.add_argument(
        "--manifests",
        default=(
            "artifacts/enrichment/SPT-006/"
            "playback-manifests"
        ),
    )
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument(
        "--summary",
        default=(
            "artifacts/enrichment/SPT-006/"
            "pipeline-summary.json"
        ),
    )
    args = parser.parse_args()

    summary = run_pipeline(
        canonical_path=args.canonical,
        jobs_db=args.jobs_db,
        resources_root=args.resources,
        manifests_root=args.manifests,
        limit=args.limit,
    )

    output = Path(args.summary)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("SPT-006 ejecutado correctamente.")
    print(f"Registros: {summary['records_processed']}")
    print(f"Trabajos: {summary['jobs_planned']}")
    print(
        "Recursos simulados: "
        f"{summary['resources_generated_mock']}"
    )
    print(f"Manifiestos: {summary['playback_manifests']}")
    print("Llamadas externas: 0")
    print("Costo USD: 0.0")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Pipeline automatizado de enriquecimiento multimedia."""

from __future__ import annotations

from typing import Any

__all__ = [
    "EnrichmentJob",
    "EnrichmentNeed",
    "EnrichmentPipeline",
    "GeneratedResource",
    "MockEnrichmentProvider",
    "PlaybackManifest",
    "build_playback_manifest",
    "detect_needs",
    "plan_repository",
    "run_pipeline",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)

    if name in {
        "EnrichmentJob",
        "EnrichmentNeed",
        "GeneratedResource",
        "PlaybackManifest",
    }:
        from . import models
        return getattr(models, name)

    if name in {"detect_needs", "plan_repository"}:
        from . import planner
        return getattr(planner, name)

    if name == "MockEnrichmentProvider":
        from . import providers
        return getattr(providers, name)

    if name == "build_playback_manifest":
        from . import playback
        return getattr(playback, name)

    from . import pipeline
    return getattr(pipeline, name)
'@

$TestContent = @'
"""Pruebas SPT-006."""

import json
import sqlite3
from pathlib import Path

from sgoda.enrichment.models import GeneratedResource
from sgoda.enrichment.pipeline import EnrichmentPipeline, run_pipeline
from sgoda.enrichment.planner import (
    create_job,
    detect_needs,
    plan_repository,
)
from sgoda.enrichment.playback import build_playback_manifest
from sgoda.enrichment.providers import MockEnrichmentProvider


def _canonical(tmp_path: Path) -> Path:
    path = tmp_path / "canonical.json"
    path.write_text(
        json.dumps(
            {
                "records": [
                    {
                        "canonical_id": "LEX-001",
                        "puinave": "AMDA",
                        "espanol": "ejemplo",
                        "ingles": "example",
                    },
                    {
                        "canonical_id": "LEX-002",
                        "puinave": "WAI",
                        "espanol": "agua",
                        "ingles": "",
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def test_SPT_006_detecta_traduccion_ingles_faltante() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-002",
            "espanol": "agua",
            "ingles": "",
        }
    )
    assert any(
        item.resource_type == "translation_en"
        for item in needs
    )


def test_SPT_006_planifica_audio_espanol() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-001",
            "espanol": "ejemplo",
            "ingles": "example",
        }
    )
    assert any(item.resource_type == "audio_es" for item in needs)


def test_SPT_006_planifica_audio_ingles() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-001",
            "espanol": "ejemplo",
            "ingles": "example",
        }
    )
    assert any(item.resource_type == "audio_en" for item in needs)


def test_SPT_006_planifica_imagen() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-001",
            "espanol": "ejemplo",
            "ingles": "example",
        }
    )
    assert any(item.resource_type == "image" for item in needs)


def test_SPT_006_video_es_opcional() -> None:
    needs = detect_needs(
        {
            "canonical_id": "LEX-001",
            "espanol": "ejemplo",
            "ingles": "example",
        }
    )
    video = next(
        item for item in needs if item.resource_type == "video"
    )
    assert video.required is False


def test_SPT_006_job_es_idempotente() -> None:
    record = {
        "canonical_id": "LEX-001",
        "espanol": "ejemplo",
        "ingles": "example",
    }
    need = detect_needs(record)[0]
    assert create_job(record, need).job_id == create_job(
        record,
        need,
    ).job_id


def test_SPT_006_planifica_repositorio(tmp_path: Path) -> None:
    records, jobs = plan_repository(_canonical(tmp_path))
    assert len(records) == 2
    assert len(jobs) == 9


def test_SPT_006_mock_no_hace_llamada_externa(
    tmp_path: Path,
) -> None:
    record = {
        "canonical_id": "LEX-001",
        "espanol": "ejemplo",
        "ingles": "example",
    }
    job = create_job(record, detect_needs(record)[0])
    resource = MockEnrichmentProvider().execute(
        job,
        tmp_path / "resources",
    )
    assert resource.metadata["external_call"] is False
    assert resource.metadata["cost_usd"] == 0.0


def test_SPT_006_mock_genera_checksum(tmp_path: Path) -> None:
    record = {
        "canonical_id": "LEX-001",
        "espanol": "ejemplo",
        "ingles": "example",
    }
    job = create_job(record, detect_needs(record)[0])
    resource = MockEnrichmentProvider().execute(
        job,
        tmp_path / "resources",
    )
    assert resource.sha256 is not None
    assert len(resource.sha256) == 64


def test_SPT_006_manifiesto_reproduce_audio_no_video() -> None:
    resources = [
        GeneratedResource(
            resource_id="R1",
            canonical_id="LEX-001",
            resource_type="audio_es",
            status="available",
            uri="audio-es.mp3",
            sha256="a" * 64,
            provider="mock",
            validation_status="technical_valid",
        ),
        GeneratedResource(
            resource_id="R2",
            canonical_id="LEX-001",
            resource_type="video",
            status="available",
            uri="video.mp4",
            sha256="b" * 64,
            provider="mock",
            validation_status="approved",
        ),
    ]
    manifest = build_playback_manifest(
        canonical_id="LEX-001",
        resources=resources,
    )
    assert "audio_es" in manifest.sequence
    assert "video" not in manifest.sequence
    assert manifest.autoplay_video is False


def test_SPT_006_persistencia_idempotente(tmp_path: Path) -> None:
    canonical = _canonical(tmp_path)
    _, jobs = plan_repository(canonical)
    pipeline = EnrichmentPipeline(
        jobs_db=tmp_path / "jobs.sqlite3",
        resources_root=tmp_path / "resources",
        manifests_root=tmp_path / "manifests",
    )
    first = pipeline.persist_jobs(jobs)
    second = pipeline.persist_jobs(jobs)
    assert first == len(jobs)
    assert second == 0


def test_SPT_006_pipeline_genera_manifiestos(
    tmp_path: Path,
) -> None:
    summary = run_pipeline(
        canonical_path=_canonical(tmp_path),
        jobs_db=tmp_path / "jobs.sqlite3",
        resources_root=tmp_path / "resources",
        manifests_root=tmp_path / "manifests",
        limit=2,
    )
    assert summary["records_processed"] == 2
    assert summary["playback_manifests"] == 2
    assert summary["external_calls"] == 0


def test_SPT_006_base_sqlite_registra_recursos(
    tmp_path: Path,
) -> None:
    db = tmp_path / "jobs.sqlite3"
    run_pipeline(
        canonical_path=_canonical(tmp_path),
        jobs_db=db,
        resources_root=tmp_path / "resources",
        manifests_root=tmp_path / "manifests",
    )
    with sqlite3.connect(db) as connection:
        count = connection.execute(
            "SELECT COUNT(*) FROM generated_resources"
        ).fetchone()[0]
    assert count == 9


def test_SPT_006_traduccion_requiere_revision(
    tmp_path: Path,
) -> None:
    record = {
        "canonical_id": "LEX-002",
        "espanol": "agua",
        "ingles": "",
    }
    need = next(
        item for item in detect_needs(record)
        if item.resource_type == "translation_en"
    )
    resource = MockEnrichmentProvider().execute(
        create_job(record, need),
        tmp_path / "resources",
    )
    assert resource.validation_status == "machine_proposed"
'@

$PolicyContent = @'
{
  "increment_code": "SPT-006",
  "version": "0.1.0",
  "policy_name": "Pipeline Automatizado de Enriquecimiento Multimedia Multilingüe",
  "languages": ["pui", "es", "en"],
  "required_resources": [
    "audio_es",
    "audio_en",
    "image"
  ],
  "optional_resources": ["video"],
  "translation_en_requires_validation": true,
  "image_requires_cultural_review": true,
  "video_requires_review": true,
  "autoplay": {
    "enabled": true,
    "audio_puinave": true,
    "audio_es": true,
    "audio_en": true,
    "image": true,
    "video": false,
    "user_configurable": true
  },
  "external_providers_enabled": false,
  "mock_provider_enabled": true,
  "batch_processing": true,
  "idempotent": true,
  "resume_supported": true,
  "target_capacity_jobs": 120000,
  "governed_by": [
    "ADR-010",
    "SPT-003A",
    "SPT-003B",
    "SPT-003C",
    "SGD-114-v2.0.1",
    "SGD-115-v1.0.1",
    "SIB-001"
  ]
}
'@

$PlaybackPolicyContent = @'
{
  "sequence": [
    "image",
    "audio_puinave",
    "audio_es",
    "audio_en",
    "video"
  ],
  "autoplay_enabled_default": true,
  "autoplay_audio_puinave": true,
  "autoplay_audio_spanish": true,
  "autoplay_audio_english": true,
  "autoplay_video_default": false,
  "video_requires_user_action": true,
  "respect_device_mute": true,
  "respect_accessibility_preferences": true,
  "allow_user_disable_autoplay": true,
  "stop_on_error": false
}
'@

$ComponentContent = @'
{
  "increment_code": "SPT-006",
  "name": "Pipeline Automatizado de Enriquecimiento Multimedia Multilingüe",
  "component_type": "multilingual_multimedia_enrichment_pipeline",
  "version": "0.1.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.enrichment.cli",
  "source": [
    "src/sgoda/enrichment/models.py",
    "src/sgoda/enrichment/planner.py",
    "src/sgoda/enrichment/providers.py",
    "src/sgoda/enrichment/playback.py",
    "src/sgoda/enrichment/pipeline.py",
    "src/sgoda/enrichment/cli.py"
  ],
  "tests": [
    "tests/enrichment/test_SPT_006_multilingual_multimedia_pipeline.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SPT-006/SPT-006-Pipeline-Enriquecimiento-Multimedia.md",
    "docs/05_Fase_Tecnologica/SPT-006/SPT-006-Validacion-Linguistica-Cultural.md",
    "docs/05_Fase_Tecnologica/SPT-006/SPT-006-Reproduccion-Automatica-Configurable.md"
  ],
  "governed_by": [
    "ADR-010",
    "SPT-003A",
    "SPT-003B",
    "SPT-003C",
    "SGD-114-v2.0.1",
    "SGD-115-v1.0.1",
    "SIB-001"
  ]
}
'@

$DocContent = @'
# SPT-006 — Pipeline Automatizado de Enriquecimiento Multimedia

## Objetivo

Procesar el Repositorio Léxico Canónico para preparar automáticamente:

- propuesta de traducción inglesa;
- audio español;
- audio inglés;
- imagen educativa;
- video educativo cuando sea pertinente;
- manifiesto de reproducción para la aplicación.

## Primera versión

La versión 0.1.0 utiliza un proveedor simulado. No consume APIs, no genera
costos y no publica contenido definitivo.

## Flujo

RLB → detección de faltantes → trabajos → proveedor → validación →
recursos RMR → actualización ODA → manifiesto de reproducción.

## Escalabilidad

Los trabajos son idempotentes, persistentes en SQLite y procesables por
lotes. La política declara una capacidad objetivo de 120.000 trabajos.
'@

$QualityDocContent = @'
# SPT-006 — Validación Lingüística y Cultural

- La traducción inglesa automática queda como `machine_proposed`.
- El audio inglés definitivo requiere traducción validada.
- Las imágenes quedan pendientes de revisión cultural.
- El video es opcional y requiere revisión.
- Ningún recurso simulado se publica como recurso definitivo.
- El audio Puinave continúa dependiendo de grabaciones de hablantes.
- Toda aprobación debe conservar evidencia y trazabilidad.
'@

$PlaybackDocContent = @'
# SPT-006 — Reproducción Automática Configurable

Secuencia predeterminada:

1. mostrar imagen;
2. reproducir audio Puinave si está disponible;
3. reproducir audio español;
4. reproducir audio inglés;
5. ofrecer video mediante acción del usuario.

El video no se reproduce automáticamente por defecto. El usuario puede
desactivar toda reproducción automática y deben respetarse preferencias
de accesibilidad, silencio y consumo de datos.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [ValidateRange(1, 1000)]
    [int]$Limit = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.enrichment.cli --limit $Limit

if ($LASTEXITCODE -ne 0) {
    throw "SPT-006 terminó con errores."
}
'@

Write-Step "Instalando SPT-006"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $PlannerPath -Content $PlannerContent
Write-Utf8NoBom -Path $ProvidersPath -Content $ProvidersContent
Write-Utf8NoBom -Path $PlaybackPath -Content $PlaybackContent
Write-Utf8NoBom -Path $PipelinePath -Content $PipelineContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent

Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $PlaybackPolicyPath -Content $PlaybackPolicyContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent

Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $QualityDocPath -Content $QualityDocContent
Write-Utf8NoBom -Path $PlaybackDocPath -Content $PlaybackDocContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

Write-JsonUtf8 -Path $EvidencePath -Data ([ordered]@{
    increment_code = "SPT-006"
    version = "0.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    pipeline_mode = "mock_controlled"
    external_calls = 0
    estimated_cost_usd = 0.0
    resource_types = @(
        "translation_en",
        "audio_es",
        "audio_en",
        "image",
        "video"
    )
    autoplay_audio = $true
    autoplay_video = $false
    target_capacity_jobs = 120000
})

Write-JsonUtf8 -Path $TracePath -Data ([ordered]@{
    increment_code = "SPT-006"
    source = @("src/sgoda/enrichment/")
    tests = @(
        "tests/enrichment/test_SPT_006_multilingual_multimedia_pipeline.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-006/SPT-006-Pipeline-Enriquecimiento-Multimedia.md",
        "docs/05_Fase_Tecnologica/SPT-006/SPT-006-Validacion-Linguistica-Cultural.md",
        "docs/05_Fase_Tecnologica/SPT-006/SPT-006-Reproduccion-Automatica-Configurable.md"
    )
})

Write-Step "Validando sintaxis e importaciones"

& python -m py_compile `
    "src/sgoda/enrichment/models.py" `
    "src/sgoda/enrichment/planner.py" `
    "src/sgoda/enrichment/providers.py" `
    "src/sgoda/enrichment/playback.py" `
    "src/sgoda/enrichment/pipeline.py" `
    "src/sgoda/enrichment/cli.py"

if ($LASTEXITCODE -ne 0) {
    throw "La compilación de SPT-006 falló."
}

& python -c "from sgoda.enrichment import EnrichmentPipeline, MockEnrichmentProvider, run_pipeline; print(EnrichmentPipeline.__name__, MockEnrichmentProvider.__name__, run_pipeline.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SPT-006."
}

Write-Step "Ejecutando 14 pruebas específicas SPT-006"

& python -m pytest `
    "tests/enrichment/test_SPT_006_multilingual_multimedia_pipeline.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPT-006 fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Ejecutando lote controlado sobre el RLB oficial"

& python -m sgoda.enrichment.cli `
    --canonical "$CanonicalPath" `
    --limit $BatchSize `
    --summary "artifacts/enrichment/SPT-006/pipeline-summary.json"

if ($LASTEXITCODE -ne 0) {
    throw "La ejecución controlada SPT-006 falló."
}

$SummaryPath = Join-Path $ArtifactsDir "pipeline-summary.json"
Assert-Path -Path $SummaryPath -Description "pipeline-summary.json"

$Summary = Get-Content -LiteralPath $SummaryPath -Raw | ConvertFrom-Json

if ($Summary.external_calls -ne 0) {
    throw "La instalación no debe realizar llamadas externas."
}

if ($Summary.cost_usd -ne 0) {
    throw "La instalación no debe generar costos."
}

Write-Step "Publicando release técnico"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($Artifact in @(
    $PolicyPath,
    $PlaybackPolicyPath,
    $ComponentPath,
    $DocPath,
    $QualityDocPath,
    $PlaybackDocPath,
    $SummaryPath
)) {
    Copy-Item `
        -LiteralPath $Artifact `
        -Destination (Join-Path $ReleaseDir (Split-Path $Artifact -Leaf)) `
        -Force
}

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-006" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SPT-006 no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw | ConvertFrom-Json
if (-not $Gate.passed) {
    throw "SPT-006 no contiene passed=true."
}

Write-JsonUtf8 -Path $DashboardPath -Data ([ordered]@{
    increment_code = "SPT-006"
    version = "0.1.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    records_processed = $Summary.records_processed
    jobs_planned = $Summary.jobs_planned
    resources_generated_mock = $Summary.resources_generated_mock
    playback_manifests = $Summary.playback_manifests
    external_calls = 0
    cost_usd = 0.0
    autoplay_audio = $true
    autoplay_video = $false
    specific_tests = 14
    target_capacity_jobs = 120000
    quality_gate = "approved"
    release = "SPT-006-v0.1.0"
})

Write-Step "Actualizando documentación maestra SGD-115"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La actualización SGD-115 falló."
}

Write-Step "Resultado final"

Write-Host "SPT-006 v0.1.0 implementado y validado." -ForegroundColor Green
Write-Host "Pipeline de enriquecimiento: OPERATIVO EN MODO MOCK." -ForegroundColor Green
Write-Host "Pruebas específicas: 14 APROBADAS." -ForegroundColor Green
Write-Host "Registros procesados: $($Summary.records_processed)" -ForegroundColor Cyan
Write-Host "Trabajos planificados: $($Summary.jobs_planned)" -ForegroundColor Cyan
Write-Host "Recursos simulados: $($Summary.resources_generated_mock)" -ForegroundColor Cyan
Write-Host "Manifiestos de reproducción: $($Summary.playback_manifests)" -ForegroundColor Cyan
Write-Host "Audio español automático: PREPARADO." -ForegroundColor Green
Write-Host "Traducción y audio inglés: PREPARADOS CON VALIDACIÓN." -ForegroundColor Green
Write-Host "Imágenes automáticas: PREPARADAS CON REVISIÓN CULTURAL." -ForegroundColor Green
Write-Host "Video opcional: PREPARADO, NO AUTOPLAY." -ForegroundColor Green
Write-Host "Llamadas externas: 0." -ForegroundColor Green
Write-Host "Costo USD: 0.0." -ForegroundColor Green
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SPT-006-v0.1.0" -ForegroundColor Cyan
