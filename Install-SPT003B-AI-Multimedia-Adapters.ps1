<#
.SYNOPSIS
    Implementa SPT-003B — Adaptadores de IA y Procesamiento Multimedia.

.DESCRIPTION
    Instala desde un solo archivo:
      - contratos de proveedores multimedia;
      - adaptador de imagen IA;
      - adaptador TTS español e inglés;
      - adaptador de grabación humana Puinave;
      - adaptador de almacenamiento RMR;
      - adaptador n8n;
      - proveedor simulado para pruebas;
      - procesador de trabajos SPT-003A;
      - validación de resultados;
      - registro de eventos;
      - pruebas funcionales y de integración;
      - documentación, evidencias, dashboard y quality gate.

    Las pruebas NO consumen servicios externos y NO requieren claves.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.

.EXAMPLE
    .\Install-SPT003B-AI-Multimedia-Adapters.ps1
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\automation\adapters"
$TestsDir = Join-Path $ProjectRoot "tests\automation"
$ConfigDir = Join-Path $ProjectRoot "config\automation"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-003"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\automation\SPT-003B"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-003B"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-003B-v0.1.0"

$ContractsPath = Join-Path $SourceDir "contracts.py"
$ProvidersPath = Join-Path $SourceDir "providers.py"
$StoragePath = Join-Path $SourceDir "storage.py"
$N8nPath = Join-Path $SourceDir "n8n.py"
$ProcessorPath = Join-Path $SourceDir "processor.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPT_003B_ai_multimedia_adapters.py"
$PolicyPath = Join-Path $ConfigDir "SPT-003B-policy.json"
$ProvidersConfigPath = Join-Path $ConfigDir "SPT-003B-providers.example.json"
$ComponentPath = Join-Path $ConfigDir "SPT-003B-component.json"
$DocPath = Join-Path $DocsDir "SPT-003B-Adaptadores-IA-Multimedia.md"
$SecurityPath = Join-Path $DocsDir "SPT-003B-Seguridad-Credenciales-Proveedores.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT003B-AdapterValidation.ps1"
$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SPT-003B.json"
$GatePath = Join-Path $PmoDir "SPT-003B-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPT-003B-dashboard.json"

Write-Step "Validando línea base SPT-003A"

foreach ($Required in @(
    (Join-Path $ProjectRoot "src\sgoda\automation\job_queue.py"),
    (Join-Path $ProjectRoot "src\sgoda\automation\planner.py"),
    (Join-Path $ProjectRoot "artifacts\automation\SPT-003A\multimedia-jobs.sqlite3"),
    (Join-Path $ProjectRoot "artifacts\pmo\SPT-003A\SPT-003A-quality-gate.json"),
    (Join-Path $ProjectRoot "artifacts\media\ADR-010\rmr.sqlite3"),
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

$AllowedPatterns = @(
    '^\?\? Install-SPT003B-AI-Multimedia-Adapters\.ps1$',
    '^\?\? Repair-SPT003B-v[0-9.]+-.*\.ps1$',
    '^\?\? SPT003B-.*\.zip$',
    '^\?\? LEAME-SPT003B.*\.txt$'
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
        if (-not $Allowed) {
            $Entry
        }
    }
)

if ($Unexpected.Count -gt 0) {
    Write-Host "Cambios Git no permitidos antes de SPT-003B:" -ForegroundColor Red
    $Unexpected | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }
    throw "La línea base contiene cambios ajenos a SPT-003B."
}

$ContractsContent = @'
"""Contratos de adaptadores multimedia SPT-003B."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass(slots=True)
class SolicitudProveedor:
    job_id: str
    job_type: str
    resource_id: str
    oda_id: str
    language: str | None
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class ResultadoProveedor:
    success: bool
    provider: str
    external_id: str | None = None
    media_bytes: bytes | None = None
    media_type: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)
    error: str | None = None


@dataclass(slots=True)
class ResultadoPersistencia:
    resource_id: str
    uri: str
    sha256: str
    size_bytes: int
    media_type: str
    metadata: dict[str, Any] = field(default_factory=dict)


class ProveedorMultimedia(Protocol):
    name: str

    def supports(self, job_type: str) -> bool:
        ...

    def execute(
        self,
        request: SolicitudProveedor,
    ) -> ResultadoProveedor:
        ...


class AlmacenamientoMultimedia(Protocol):
    def store(
        self,
        *,
        resource_id: str,
        media_bytes: bytes,
        media_type: str,
        metadata: dict[str, Any],
    ) -> ResultadoPersistencia:
        ...


class PublicadorEventos(Protocol):
    def publish(
        self,
        *,
        event_type: str,
        payload: dict[str, Any],
    ) -> None:
        ...
'@

$ProvidersContent = @'
"""Proveedores multimedia y fábrica institucional."""

from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass
from typing import Any

from .contracts import (
    ResultadoProveedor,
    SolicitudProveedor,
)


SUPPORTED_JOB_TYPES = {
    "generate_image",
    "generate_tts",
    "record_native_audio",
}


@dataclass(slots=True)
class ProveedorSimulado:
    name: str = "mock-provider"

    def supports(self, job_type: str) -> bool:
        return job_type in SUPPORTED_JOB_TYPES

    def execute(
        self,
        request: SolicitudProveedor,
    ) -> ResultadoProveedor:
        if not self.supports(request.job_type):
            return ResultadoProveedor(
                success=False,
                provider=self.name,
                error=f"Tipo no soportado: {request.job_type}",
            )

        if request.payload.get("simulate_error"):
            return ResultadoProveedor(
                success=False,
                provider=self.name,
                error="Error simulado del proveedor.",
            )

        canonical = (
            f"{request.job_id}|{request.job_type}|"
            f"{request.resource_id}|{request.language}|"
            f"{request.payload}"
        ).encode("utf-8")

        digest = hashlib.sha256(canonical).hexdigest()
        media_bytes = (
            f"SGODA-MOCK-MEDIA:{digest}"
        ).encode("utf-8")

        media_type = {
            "generate_image": "image/png",
            "generate_tts": "audio/wav",
            "record_native_audio": "audio/wav",
        }[request.job_type]

        return ResultadoProveedor(
            success=True,
            provider=self.name,
            external_id=f"MOCK-{digest[:20].upper()}",
            media_bytes=media_bytes,
            media_type=media_type,
            metadata={
                "simulated": True,
                "job_type": request.job_type,
                "language": request.language,
            },
        )


@dataclass(slots=True)
class ProveedorExternoDeshabilitado:
    name: str
    required_environment_variable: str

    def supports(self, job_type: str) -> bool:
        return job_type in SUPPORTED_JOB_TYPES

    def execute(
        self,
        request: SolicitudProveedor,
    ) -> ResultadoProveedor:
        if not os.getenv(self.required_environment_variable):
            return ResultadoProveedor(
                success=False,
                provider=self.name,
                error=(
                    "Proveedor deshabilitado: falta la variable de "
                    f"entorno {self.required_environment_variable}."
                ),
            )

        return ResultadoProveedor(
            success=False,
            provider=self.name,
            error=(
                "El contrato del proveedor está configurado, pero la "
                "llamada externa no está habilitada en SPT-003B v0.1.0."
            ),
        )


def construir_proveedor(
    provider_name: str,
) -> Any:
    normalized = provider_name.strip().casefold()

    if normalized == "mock":
        return ProveedorSimulado()

    if normalized == "openai-image":
        return ProveedorExternoDeshabilitado(
            name="openai-image",
            required_environment_variable="OPENAI_API_KEY",
        )

    if normalized == "google-tts":
        return ProveedorExternoDeshabilitado(
            name="google-tts",
            required_environment_variable="GOOGLE_APPLICATION_CREDENTIALS",
        )

    if normalized == "azure-speech":
        return ProveedorExternoDeshabilitado(
            name="azure-speech",
            required_environment_variable="AZURE_SPEECH_KEY",
        )

    raise ValueError(f"Proveedor desconocido: {provider_name}")
'@

$StorageContent = @'
"""Almacenamiento local gobernado y actualización del RMR."""

from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .contracts import ResultadoPersistencia


class AlmacenamientoLocalRMR:
    def __init__(
        self,
        *,
        root: str | Path,
        rmr_database: str | Path | None = None,
    ) -> None:
        self.root = Path(root)
        self.rmr_database = (
            Path(rmr_database)
            if rmr_database is not None
            else None
        )

    @staticmethod
    def _extension(media_type: str) -> str:
        mapping = {
            "image/png": ".png",
            "image/jpeg": ".jpg",
            "audio/wav": ".wav",
            "audio/mpeg": ".mp3",
            "video/mp4": ".mp4",
        }
        return mapping.get(media_type, ".bin")

    def store(
        self,
        *,
        resource_id: str,
        media_bytes: bytes,
        media_type: str,
        metadata: dict[str, Any],
    ) -> ResultadoPersistencia:
        if not media_bytes:
            raise ValueError("No se puede almacenar contenido vacío.")

        digest = hashlib.sha256(media_bytes).hexdigest()
        extension = self._extension(media_type)
        relative = Path(resource_id[:2]) / f"{resource_id}{extension}"
        target = self.root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(media_bytes)

        metadata_path = target.with_suffix(
            target.suffix + ".metadata.json"
        )
        metadata_payload = {
            "resource_id": resource_id,
            "sha256": digest,
            "size_bytes": len(media_bytes),
            "media_type": media_type,
            "stored_at_utc": datetime.now(
                timezone.utc
            ).isoformat(),
            "metadata": metadata,
        }
        metadata_path.write_text(
            json.dumps(
                metadata_payload,
                ensure_ascii=False,
                indent=2,
            ) + "\n",
            encoding="utf-8",
        )

        uri = target.as_posix()

        if self.rmr_database is not None:
            self._update_rmr(
                resource_id=resource_id,
                uri=uri,
                sha256=digest,
                size_bytes=len(media_bytes),
                media_type=media_type,
            )

        return ResultadoPersistencia(
            resource_id=resource_id,
            uri=uri,
            sha256=digest,
            size_bytes=len(media_bytes),
            media_type=media_type,
            metadata=metadata,
        )

    def _update_rmr(
        self,
        *,
        resource_id: str,
        uri: str,
        sha256: str,
        size_bytes: int,
        media_type: str,
    ) -> None:
        connection = sqlite3.connect(self.rmr_database)
        try:
            columns = {
                row[1]
                for row in connection.execute(
                    "PRAGMA table_info(media_resources)"
                ).fetchall()
            }

            updates: list[str] = []
            values: list[Any] = []

            candidates = {
                "uri": uri,
                "storage_uri": uri,
                "sha256": sha256,
                "size_bytes": size_bytes,
                "media_type": media_type,
                "status": "available",
            }

            for column, value in candidates.items():
                if column in columns:
                    updates.append(f"{column}=?")
                    values.append(value)

            if updates:
                values.append(resource_id)
                connection.execute(
                    f"""
                    UPDATE media_resources
                    SET {", ".join(updates)}
                    WHERE resource_id=?
                    """,
                    values,
                )
                connection.commit()
        finally:
            connection.close()
'@

$N8nContent = @'
"""Publicación de eventos compatible con n8n."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class PublicadorEventosArchivo:
    def __init__(self, output_path: str | Path) -> None:
        self.output_path = Path(output_path)

    def publish(
        self,
        *,
        event_type: str,
        payload: dict[str, Any],
    ) -> None:
        self.output_path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        envelope = {
            "event_type": event_type,
            "occurred_at_utc": datetime.now(
                timezone.utc
            ).isoformat(),
            "source": "sgoda.automation.adapters",
            "payload": payload,
            "n8n_compatible": True,
        }

        with self.output_path.open(
            "a",
            encoding="utf-8",
        ) as stream:
            stream.write(
                json.dumps(
                    envelope,
                    ensure_ascii=False,
                )
                + "\n"
            )
'@

$ProcessorContent = @'
"""Procesador institucional de trabajos SPT-003A."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from sgoda.automation.job_queue import ColaTrabajosMultimedia

from .contracts import SolicitudProveedor
from .n8n import PublicadorEventosArchivo
from .providers import construir_proveedor
from .storage import AlmacenamientoLocalRMR


class ProcesadorTrabajosMultimedia:
    def __init__(
        self,
        *,
        queue: ColaTrabajosMultimedia,
        provider: Any,
        storage: AlmacenamientoLocalRMR,
        events: PublicadorEventosArchivo,
        worker_id: str = "SPT-003B-worker",
    ) -> None:
        self.queue = queue
        self.provider = provider
        self.storage = storage
        self.events = events
        self.worker_id = worker_id

    def process_batch(
        self,
        limit: int = 10,
    ) -> dict[str, int]:
        leased = self.queue.lease(
            worker_id=self.worker_id,
            limit=limit,
        )

        summary = {
            "leased": len(leased),
            "completed": 0,
            "retried": 0,
            "failed": 0,
        }

        for job in leased:
            request = SolicitudProveedor(
                job_id=job.job_id,
                job_type=job.job_type,
                resource_id=job.resource_id,
                oda_id=job.oda_id,
                language=job.language,
                payload=job.payload,
            )

            result = self.provider.execute(request)

            if not result.success:
                self.queue.fail(
                    job.job_id,
                    result.error or "Proveedor sin detalle de error",
                    retry_delay_seconds=0,
                )

                state = (
                    "failed"
                    if self.queue.count("failed") > summary["failed"]
                    else "retry"
                )

                if state == "failed":
                    summary["failed"] += 1
                else:
                    summary["retried"] += 1

                self.events.publish(
                    event_type="MultimediaJobFailed",
                    payload={
                        "job_id": job.job_id,
                        "resource_id": job.resource_id,
                        "provider": result.provider,
                        "error": result.error,
                        "state": state,
                    },
                )
                continue

            if result.media_bytes is None or result.media_type is None:
                self.queue.fail(
                    job.job_id,
                    "El proveedor no devolvió contenido multimedia.",
                    retry_delay_seconds=0,
                )
                summary["retried"] += 1
                continue

            stored = self.storage.store(
                resource_id=job.resource_id,
                media_bytes=result.media_bytes,
                media_type=result.media_type,
                metadata={
                    **result.metadata,
                    "provider": result.provider,
                    "external_id": result.external_id,
                    "job_id": job.job_id,
                },
            )

            completion = {
                "provider": result.provider,
                "external_id": result.external_id,
                "storage": asdict(stored),
            }

            self.queue.complete(job.job_id, completion)
            summary["completed"] += 1

            self.events.publish(
                event_type="MultimediaJobCompleted",
                payload={
                    "job_id": job.job_id,
                    "resource_id": job.resource_id,
                    "provider": result.provider,
                    "storage": asdict(stored),
                },
            )

        return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--jobs",
        default=(
            "artifacts/automation/SPT-003A/"
            "multimedia-jobs.sqlite3"
        ),
    )
    parser.add_argument(
        "--storage",
        default="artifacts/automation/SPT-003B/media",
    )
    parser.add_argument(
        "--events",
        default=(
            "artifacts/automation/SPT-003B/"
            "multimedia-events.jsonl"
        ),
    )
    parser.add_argument(
        "--rmr",
        default="artifacts/media/ADR-010/rmr.sqlite3",
    )
    parser.add_argument("--provider", default="mock")
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument(
        "--summary",
        default=(
            "artifacts/automation/SPT-003B/"
            "processing-summary.json"
        ),
    )
    args = parser.parse_args()

    queue = ColaTrabajosMultimedia(args.jobs)
    provider = construir_proveedor(args.provider)
    storage = AlmacenamientoLocalRMR(
        root=args.storage,
        rmr_database=args.rmr,
    )
    events = PublicadorEventosArchivo(args.events)

    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=provider,
        storage=storage,
        events=events,
    )

    summary = processor.process_batch(limit=args.limit)

    summary_path = Path(args.summary)
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        json.dumps(
            summary,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    print("SPT-003B ejecutado correctamente.")
    print(f"Proveedor: {args.provider}")
    print(f"Leased: {summary['leased']}")
    print(f"Completados: {summary['completed']}")
    print(f"Reintentos: {summary['retried']}")
    print(f"Fallidos: {summary['failed']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Adaptadores multimedia SPT-003B."""

from .contracts import (
    ResultadoPersistencia,
    ResultadoProveedor,
    SolicitudProveedor,
)
from .n8n import PublicadorEventosArchivo
from .processor import ProcesadorTrabajosMultimedia
from .providers import (
    ProveedorExternoDeshabilitado,
    ProveedorSimulado,
    construir_proveedor,
)
from .storage import AlmacenamientoLocalRMR

__all__ = [
    "AlmacenamientoLocalRMR",
    "ProcesadorTrabajosMultimedia",
    "ProveedorExternoDeshabilitado",
    "ProveedorSimulado",
    "PublicadorEventosArchivo",
    "ResultadoPersistencia",
    "ResultadoProveedor",
    "SolicitudProveedor",
    "construir_proveedor",
]
'@

$TestContent = @'
"""Pruebas SPT-003B de adaptadores multimedia."""

import json
from pathlib import Path

from sgoda.automation.adapters.contracts import SolicitudProveedor
from sgoda.automation.adapters.n8n import PublicadorEventosArchivo
from sgoda.automation.adapters.processor import (
    ProcesadorTrabajosMultimedia,
)
from sgoda.automation.adapters.providers import (
    ProveedorExternoDeshabilitado,
    ProveedorSimulado,
    construir_proveedor,
)
from sgoda.automation.adapters.storage import (
    AlmacenamientoLocalRMR,
)
from sgoda.automation.job_queue import ColaTrabajosMultimedia
from sgoda.automation.models import TrabajoMultimedia


def _job(
    index: int,
    *,
    job_type: str = "generate_image",
    payload: dict | None = None,
) -> TrabajoMultimedia:
    return TrabajoMultimedia(
        job_id=f"JOB-{index:04d}",
        resource_id=f"RMR-{index:04d}",
        oda_id=f"ODA-{index:04d}",
        canonical_id=f"LEX-{index:04d}",
        job_type=job_type,
        language="es" if job_type == "generate_tts" else None,
        payload=payload or {},
    )


def test_SPT_003B_proveedor_mock_imagen() -> None:
    provider = ProveedorSimulado()
    request = SolicitudProveedor(
        job_id="JOB-1",
        job_type="generate_image",
        resource_id="RMR-1",
        oda_id="ODA-1",
        language=None,
        payload={"prompt": "árbol"},
    )

    result = provider.execute(request)

    assert result.success is True
    assert result.media_type == "image/png"
    assert result.media_bytes
    assert result.external_id.startswith("MOCK-")


def test_SPT_003B_proveedor_mock_tts() -> None:
    provider = ProveedorSimulado()
    request = SolicitudProveedor(
        job_id="JOB-2",
        job_type="generate_tts",
        resource_id="RMR-2",
        oda_id="ODA-2",
        language="es",
        payload={"text": "ejemplo"},
    )

    result = provider.execute(request)

    assert result.success is True
    assert result.media_type == "audio/wav"


def test_SPT_003B_proveedor_no_soportado() -> None:
    provider = ProveedorSimulado()
    request = SolicitudProveedor(
        job_id="JOB-3",
        job_type="unknown",
        resource_id="RMR-3",
        oda_id="ODA-3",
        language=None,
    )

    result = provider.execute(request)

    assert result.success is False
    assert "no soportado" in result.error


def test_SPT_003B_credenciales_no_expuestas(
    monkeypatch,
) -> None:
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    provider = ProveedorExternoDeshabilitado(
        name="openai-image",
        required_environment_variable="OPENAI_API_KEY",
    )

    result = provider.execute(
        SolicitudProveedor(
            job_id="JOB-4",
            job_type="generate_image",
            resource_id="RMR-4",
            oda_id="ODA-4",
            language=None,
        )
    )

    assert result.success is False
    assert "OPENAI_API_KEY" in result.error


def test_SPT_003B_almacenamiento_sha256(
    tmp_path: Path,
) -> None:
    storage = AlmacenamientoLocalRMR(root=tmp_path / "media")
    result = storage.store(
        resource_id="RMR-0001",
        media_bytes=b"contenido",
        media_type="image/png",
        metadata={"source": "test"},
    )

    assert Path(result.uri).is_file()
    assert len(result.sha256) == 64
    assert result.size_bytes == len(b"contenido")


def test_SPT_003B_evento_n8n_jsonl(
    tmp_path: Path,
) -> None:
    path = tmp_path / "events.jsonl"
    publisher = PublicadorEventosArchivo(path)

    publisher.publish(
        event_type="MultimediaJobCompleted",
        payload={"job_id": "JOB-1"},
    )

    line = path.read_text(encoding="utf-8").strip()
    payload = json.loads(line)

    assert payload["n8n_compatible"] is True
    assert payload["event_type"] == "MultimediaJobCompleted"


def test_SPT_003B_procesa_lote_completo(
    tmp_path: Path,
) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many([
        _job(1),
        _job(2, job_type="generate_tts"),
        _job(3, job_type="record_native_audio"),
    ])

    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=construir_proveedor("mock"),
        storage=AlmacenamientoLocalRMR(
            root=tmp_path / "media"
        ),
        events=PublicadorEventosArchivo(
            tmp_path / "events.jsonl"
        ),
    )

    summary = processor.process_batch(limit=10)

    assert summary["leased"] == 3
    assert summary["completed"] == 3
    assert queue.count("completed") == 3


def test_SPT_003B_reintenta_error_proveedor(
    tmp_path: Path,
) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many([
        _job(
            1,
            payload={"simulate_error": True},
        )
    ])

    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=ProveedorSimulado(),
        storage=AlmacenamientoLocalRMR(
            root=tmp_path / "media"
        ),
        events=PublicadorEventosArchivo(
            tmp_path / "events.jsonl"
        ),
    )

    summary = processor.process_batch(limit=1)

    assert summary["leased"] == 1
    assert summary["retried"] == 1
    assert queue.count("pending") == 1


def test_SPT_003B_fabrica_proveedores() -> None:
    assert construir_proveedor("mock").name == "mock-provider"
    assert construir_proveedor("openai-image").name == "openai-image"
    assert construir_proveedor("google-tts").name == "google-tts"


def test_SPT_003B_procesamiento_masivo_1000(
    tmp_path: Path,
) -> None:
    queue = ColaTrabajosMultimedia(tmp_path / "jobs.sqlite3")
    queue.initialize()
    queue.upsert_many(
        _job(index)
        for index in range(1000)
    )

    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=ProveedorSimulado(),
        storage=AlmacenamientoLocalRMR(
            root=tmp_path / "media"
        ),
        events=PublicadorEventosArchivo(
            tmp_path / "events.jsonl"
        ),
    )

    total_completed = 0

    while queue.count("pending") > 0:
        summary = processor.process_batch(limit=250)
        total_completed += summary["completed"]

    assert total_completed == 1000
    assert queue.count("completed") == 1000
'@

$PolicyContent = @'
{
  "increment_code": "SPT-003B",
  "version": "0.1.0",
  "external_calls_enabled": false,
  "default_provider": "mock",
  "supported_adapters": [
    "image_generation",
    "tts_es",
    "tts_en",
    "native_puinave_recording",
    "rmr_storage",
    "n8n_events"
  ],
  "credential_policy": {
    "storage": "environment_variables_only",
    "commit_secrets": false,
    "log_secrets": false
  },
  "human_review_required": true,
  "providers_prepared": [
    "openai-image",
    "google-tts",
    "azure-speech"
  ],
  "governed_by": "SGD-114-v2.0.1"
}
'@

$ProvidersConfigContent = @'
{
  "active_provider": "mock",
  "providers": {
    "mock": {
      "enabled": true,
      "external_calls": false
    },
    "openai-image": {
      "enabled": false,
      "environment_variable": "OPENAI_API_KEY"
    },
    "google-tts": {
      "enabled": false,
      "environment_variable": "GOOGLE_APPLICATION_CREDENTIALS"
    },
    "azure-speech": {
      "enabled": false,
      "environment_variable": "AZURE_SPEECH_KEY"
    }
  }
}
'@

$ComponentContent = @'
{
  "increment_code": "SPT-003B",
  "component_type": "ai_multimedia_adapters",
  "version": "0.1.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.automation.adapters.processor",
  "tests": [
    "tests/automation/test_SPT_003B_ai_multimedia_adapters.py"
  ],
  "governed_by": "SGD-114-v2.0.1"
}
'@

$DocContent = @'
# SPT-003B — Adaptadores de IA y Procesamiento Multimedia

## Objetivo

Conectar la cola SPT-003A con proveedores intercambiables de imagen,
TTS, grabación nativa, almacenamiento RMR y eventos n8n.

## Principios

- proveedores desacoplados;
- claves únicamente mediante variables de entorno;
- ningún secreto en el repositorio;
- simulación reproducible durante pruebas;
- persistencia con SHA-256;
- eventos JSONL compatibles con n8n;
- revisión humana obligatoria.

## Estado de proveedores

En v0.1.0 los contratos externos quedan preparados, pero deshabilitados.
El proveedor `mock` permite probar el flujo completo sin costos ni
dependencias externas.

## Próximo incremento

SPT-003C habilitará un proveedor real seleccionado, con límites,
presupuesto, consentimiento, validación cultural y operación piloto.
'@

$SecurityContent = @'
# SPT-003B — Seguridad de credenciales

Las claves nunca se escriben en archivos versionados.

Variables preparadas:

- `OPENAI_API_KEY`
- `GOOGLE_APPLICATION_CREDENTIALS`
- `AZURE_SPEECH_KEY`

Las pruebas eliminan o simulan variables y no ejecutan llamadas externas.

La activación productiva requiere:

1. aprobación institucional;
2. presupuesto;
3. selección de proveedor;
4. política de privacidad;
5. revisión cultural;
6. límites de consumo;
7. auditoría de resultados.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [string]$Provider = "mock",
    [int]$Limit = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.automation.adapters.processor `
    --jobs "artifacts/automation/SPT-003A/multimedia-jobs.sqlite3" `
    --storage "artifacts/automation/SPT-003B/media" `
    --events "artifacts/automation/SPT-003B/multimedia-events.jsonl" `
    --rmr "artifacts/media/ADR-010/rmr.sqlite3" `
    --provider $Provider `
    --limit $Limit `
    --summary "artifacts/automation/SPT-003B/processing-summary.json"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-003B terminó con errores."
}
'@

Write-Step "Instalando SPT-003B"

Write-Utf8NoBom -Path $ContractsPath -Content $ContractsContent
Write-Utf8NoBom -Path $ProvidersPath -Content $ProvidersContent
Write-Utf8NoBom -Path $StoragePath -Content $StorageContent
Write-Utf8NoBom -Path $N8nPath -Content $N8nContent
Write-Utf8NoBom -Path $ProcessorPath -Content $ProcessorContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $ProvidersConfigPath -Content $ProvidersConfigContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent
Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $SecurityPath -Content $SecurityContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Evidence = [ordered]@{
    increment_code = "SPT-003B"
    version = "0.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    external_calls = $false
    provider_for_tests = "mock"
    components = @(
        "src/sgoda/automation/adapters/contracts.py",
        "src/sgoda/automation/adapters/providers.py",
        "src/sgoda/automation/adapters/storage.py",
        "src/sgoda/automation/adapters/n8n.py",
        "src/sgoda/automation/adapters/processor.py",
        "tests/automation/test_SPT_003B_ai_multimedia_adapters.py",
        "config/automation/SPT-003B-policy.json",
        "config/automation/SPT-003B-providers.example.json",
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003B-Adaptadores-IA-Multimedia.md",
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003B-Seguridad-Credenciales-Proveedores.md",
        "scripts/Invoke-SPT003B-AdapterValidation.ps1"
    )
}
Write-JsonUtf8 -Path $EvidencePath -Data $Evidence

$Trace = [ordered]@{
    increment_code = "SPT-003B"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/automation/adapters/"
    )
    tests = @(
        "tests/automation/test_SPT_003B_ai_multimedia_adapters.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003B-Adaptadores-IA-Multimedia.md",
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003B-Seguridad-Credenciales-Proveedores.md"
    )
    evidence = @(
        "artifacts/pmo/SPT-003B/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando importaciones"

& python -c "from sgoda.automation.adapters import ProveedorSimulado, ProcesadorTrabajosMultimedia; print(ProveedorSimulado.__name__, ProcesadorTrabajosMultimedia.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SPT-003B."
}

Write-Step "Ejecutando 10 pruebas específicas SPT-003B"

& python -m pytest `
    "tests/automation/test_SPT_003B_ai_multimedia_adapters.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPT-003B fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Ejecutando piloto local controlado"

& python -m sgoda.automation.adapters.processor `
    --jobs "artifacts/automation/SPT-003A/multimedia-jobs.sqlite3" `
    --storage "artifacts/automation/SPT-003B/media" `
    --events "artifacts/automation/SPT-003B/multimedia-events.jsonl" `
    --rmr "artifacts/media/ADR-010/rmr.sqlite3" `
    --provider "mock" `
    --limit 4 `
    --summary "artifacts/automation/SPT-003B/processing-summary.json"

if ($LASTEXITCODE -ne 0) {
    throw "El piloto local SPT-003B falló."
}

$SummaryPath = Join-Path $ArtifactsDir "processing-summary.json"
Assert-Path -Path $SummaryPath -Description "processing-summary.json"

$Summary = Get-Content -LiteralPath $SummaryPath -Raw |
    ConvertFrom-Json

if ([int]$Summary.completed -ne 4) {
    throw "El piloto debía completar 4 trabajos."
}

Write-Step "Publicando release técnico"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

foreach ($Artifact in @(
    $SummaryPath,
    (Join-Path $ArtifactsDir "multimedia-events.jsonl"),
    $PolicyPath,
    $ProvidersConfigPath,
    $DocPath,
    $SecurityPath
)) {
    Assert-Path -Path $Artifact -Description $Artifact
    Copy-Item `
        -LiteralPath $Artifact `
        -Destination (Join-Path $ReleaseDir (Split-Path $Artifact -Leaf)) `
        -Force
}

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-003B" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SPT-003B no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "SPT-003B no contiene passed=true."
}

$Dashboard = [ordered]@{
    increment_code = "SPT-003B"
    version = "0.1.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    adapters = 6
    providers_prepared = 3
    active_test_provider = "mock"
    external_calls = $false
    pilot_leased = $Summary.leased
    pilot_completed = $Summary.completed
    pilot_retried = $Summary.retried
    pilot_failed = $Summary.failed
    specific_tests = 10
    expected_total_tests = 121
    credential_policy = "environment_variables_only"
    n8n_ready = $true
    quality_gate = "approved"
    release = "SPT-003B-v0.1.0"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SPT-003B implementado y validado." -ForegroundColor Green
Write-Host "Pruebas específicas: 10 APROBADAS." -ForegroundColor Green
Write-Host "Suite total esperada desde 111: 121 pruebas." -ForegroundColor Cyan
Write-Host "Piloto local: 4 trabajos COMPLETADOS." -ForegroundColor Green
Write-Host "Proveedor de pruebas: MOCK." -ForegroundColor Green
Write-Host "Credenciales: VARIABLES DE ENTORNO." -ForegroundColor Green
Write-Host "Servicios externos: DESHABILITADOS." -ForegroundColor Yellow
Write-Host "n8n: PREPARADO." -ForegroundColor Green
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-003B-v0.1.0" -ForegroundColor Cyan
