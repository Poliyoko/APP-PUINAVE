<#
.SYNOPSIS
    Instala SPT-011 v1.0.0 — Plataforma Operativa SGODA-PUINAVE.

.DESCRIPTION
    Inicia la Fase Tecnológica III y convierte SPT-010 en una plataforma
    operativa preparada para integración real con:

      - FastAPI;
      - PostgreSQL;
      - Flutter;
      - n8n;
      - Repositorio Léxico Base;
      - multimedia local;
      - motores SPT-006A y SPT-007A/B/C/D;
      - Tutor SPT-008;
      - Ecosistema Conversacional SPT-009.

    El instalador:
      - valida la línea base;
      - crea respaldo institucional;
      - instala código, configuración, scripts y documentación;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - ejecuta una demostración operativa;
      - regenera SGD-116;
      - evalúa mediante SGD-114C;
      - regenera SGD-115;
      - genera evidencias;
      - crea el release técnico.

.PARAMETER ProjectRoot
    Raíz del repositorio. Por defecto, la carpeta actual.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.

.PARAMETER SkipInstitutionalClosure
    Omite SGD-116, SGD-114C, SGD-115 y release.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$SkipInstitutionalClosure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-Json {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Value | ConvertTo-Json -Depth 100

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Step $Description
    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

function Backup-File {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [Parameter(Mandatory = $true)][string]$Root
    )

    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        $RelativeName = $Source.Replace($Root, "")
        $RelativeName = $RelativeName.TrimStart(
            [char[]]@([char]92, [char]47)
        )
        $RelativeName = $RelativeName.Replace(
            [string][char]92,
            "__"
        )
        $RelativeName = $RelativeName.Replace("/", "__")

        Copy-Item `
            -LiteralPath $Source `
            -Destination (Join-Path $BackupDirectory $RelativeName) `
            -Force
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\operational_platform"
$TestsDir = Join-Path $ProjectRoot "tests\operational_platform"
$ConfigDir = Join-Path $ProjectRoot "config\operational_platform"
$DocsDir = Join-Path $ProjectRoot "docs\07_Fase_Tecnologica_III\SPT-011"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\operational_platform\SPT-011"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-011"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-011-v1.0.0"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SPT011-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "models.py"
$SettingsPath = Join-Path $SourceDir "settings.py"
$DatabasePath = Join-Path $SourceDir "database.py"
$RlbPath = Join-Path $SourceDir "rlb_adapter.py"
$MediaPath = Join-Path $SourceDir "media_adapter.py"
$N8nPath = Join-Path $SourceDir "n8n_contracts.py"
$FlutterPath = Join-Path $SourceDir "flutter_contracts.py"
$ServicePath = Join-Path $SourceDir "service.py"
$ApiPath = Join-Path $SourceDir "api.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SPT_011_operational_sgoda_platform.py"

$PolicyPath = Join-Path `
    $ConfigDir `
    "SPT-011-operational-policy.json"

$RuntimeConfigPath = Join-Path `
    $ConfigDir `
    "SPT-011-runtime.json"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SPT-011-component.json"

$InvokePath = Join-Path `
    $ScriptsDir `
    "Invoke-SPT011-OperationalPlatform.ps1"

$DemoRlbPath = Join-Path $ArtifactsDir "demo-rlb.json"
$DemoMediaPath = Join-Path $ArtifactsDir "demo-media.json"
$DemoResultPath = Join-Path $ArtifactsDir "demo-operational-result.json"

$EvidencePath = Join-Path `
    $PmoDir `
    "SPT-011-implementation-evidence.json"

$GateJson = Join-Path $PmoDir "SPT-011-policy-result.json"
$GateMd = Join-Path $PmoDir "SPT-011-policy-result.md"

Write-Step "Validando línea base de SPT-010"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\platform\facade.py"),
    (Join-Path $ProjectRoot "src\sgoda\platform\runtime.py"),
    (Join-Path $ProjectRoot "src\sgoda\platform\api.py"),
    (Join-Path $ProjectRoot "src\sgoda\knowledge_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\reasoning_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\tutor\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\conversation\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\policy_cli.py"),
    (Join-Path $ProjectRoot "config\governance\SGD-114C-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File -Path $Required
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Affected in @(
    $ModelsPath,
    $SettingsPath,
    $DatabasePath,
    $RlbPath,
    $MediaPath,
    $N8nPath,
    $FlutterPath,
    $ServicePath,
    $ApiPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $PolicyPath,
    $RuntimeConfigPath,
    $ComponentPath,
    $InvokePath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Models = @'
"""Modelos canónicos de SPT-011."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class OperationalRequest:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)
    session_id: str = "anonymous"
    language: str = "es"
    entry_id: str | None = None


@dataclass(frozen=True, slots=True)
class OperationalResponse:
    operation: str
    status: str
    data: dict[str, Any]
    sources: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    no_invention: bool = True


@dataclass(frozen=True, slots=True)
class RuntimeStatus:
    database_mode: str
    rlb_loaded: bool
    media_loaded: bool
    n8n_enabled: bool
    flutter_contract_enabled: bool
    api_enabled: bool
'@

$Settings = @'
"""Configuración local de SPT-011."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class OperationalSettings:
    database_url: str
    database_mode: str
    api_host: str
    api_port: int
    n8n_enabled: bool
    n8n_base_url: str
    flutter_contract_enabled: bool
    require_validated_entries: bool
    no_invention: bool

    @classmethod
    def from_json(
        cls,
        path: str | Path,
    ) -> "OperationalSettings":
        payload = json.loads(
            Path(path).read_text(encoding="utf-8-sig")
        )

        return cls(
            database_url=str(
                payload.get(
                    "database_url",
                    "sqlite:///artifacts/operational_platform/sgoda.db",
                )
            ),
            database_mode=str(
                payload.get("database_mode", "local")
            ),
            api_host=str(payload.get("api_host", "127.0.0.1")),
            api_port=int(payload.get("api_port", 8000)),
            n8n_enabled=bool(payload.get("n8n_enabled", False)),
            n8n_base_url=str(
                payload.get(
                    "n8n_base_url",
                    "http://127.0.0.1:5678",
                )
            ),
            flutter_contract_enabled=bool(
                payload.get("flutter_contract_enabled", True)
            ),
            require_validated_entries=bool(
                payload.get("require_validated_entries", True)
            ),
            no_invention=bool(payload.get("no_invention", True)),
        )
'@

$Database = @'
"""Abstracción de persistencia operativa.

La versión 1.0.0 utiliza memoria local determinista y define el contrato
para PostgreSQL sin requerir un servidor durante las pruebas.
"""

from __future__ import annotations

from collections.abc import Iterable
from typing import Any


class OperationalRepository:
    def __init__(self) -> None:
        self._entries: dict[str, dict[str, Any]] = {}
        self._media: dict[str, list[dict[str, Any]]] = {}

    def upsert_entry(self, record: dict[str, Any]) -> None:
        entry_id = str(record.get("entry_id") or "").strip()

        if not entry_id:
            raise ValueError("entry_id es obligatorio.")

        self._entries[entry_id] = dict(record)

    def upsert_entries(
        self,
        records: Iterable[dict[str, Any]],
    ) -> None:
        for record in records:
            self.upsert_entry(record)

    def get_entry(
        self,
        entry_id: str,
    ) -> dict[str, Any] | None:
        value = self._entries.get(entry_id)
        return dict(value) if value is not None else None

    def all_entries(self) -> tuple[dict[str, Any], ...]:
        return tuple(
            dict(self._entries[key])
            for key in sorted(self._entries)
        )

    def attach_media(
        self,
        entry_id: str,
        media: dict[str, Any],
    ) -> None:
        if entry_id not in self._entries:
            raise KeyError(
                f"No existe el registro léxico: {entry_id}"
            )

        self._media.setdefault(entry_id, []).append(
            dict(media)
        )

    def media_for(
        self,
        entry_id: str,
    ) -> tuple[dict[str, Any], ...]:
        return tuple(
            dict(item)
            for item in self._media.get(entry_id, [])
        )

    def count(self) -> int:
        return len(self._entries)
'@

$RlbAdapter = @'
"""Adaptador del Repositorio Léxico Base."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def load_rlb(
    path: str | Path,
    validated_only: bool = True,
) -> tuple[dict[str, Any], ...]:
    payload = json.loads(
        Path(path).read_text(encoding="utf-8-sig")
    )

    records = (
        payload.get("entries", [])
        if isinstance(payload, dict)
        else payload
    )

    if not isinstance(records, list):
        raise ValueError("El RLB debe contener una lista.")

    normalized = []

    for index, item in enumerate(records, start=1):
        if not isinstance(item, dict):
            continue

        validated = bool(item.get("validated", False))

        if validated_only and not validated:
            continue

        entry_id = str(
            item.get("entry_id")
            or item.get("id")
            or f"LEX-{index:06d}"
        ).strip()

        if not entry_id:
            continue

        normalized.append(
            {
                "entry_id": entry_id,
                "puinave": str(
                    item.get("puinave") or ""
                ).strip(),
                "spanish": str(
                    item.get("spanish")
                    or item.get("espanol")
                    or ""
                ).strip(),
                "english_us": str(
                    item.get("english_us")
                    or item.get("english")
                    or ""
                ).strip(),
                "italian": str(
                    item.get("italian")
                    or item.get("italiano")
                    or ""
                ).strip(),
                "validated": validated,
                "category": str(
                    item.get("category") or ""
                ).strip(),
                "metadata": {
                    key: value
                    for key, value in item.items()
                    if key not in {
                        "entry_id",
                        "id",
                        "puinave",
                        "spanish",
                        "espanol",
                        "english_us",
                        "english",
                        "italian",
                        "italiano",
                        "validated",
                        "category",
                    }
                },
            }
        )

    return tuple(normalized)
'@

$MediaAdapter = @'
"""Adaptador de recursos multimedia."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ALLOWED_MEDIA_TYPES = {
    "audio_puinave",
    "audio_spanish",
    "audio_english_us",
    "audio_italian",
    "image",
    "video",
}


def load_media_manifest(
    path: str | Path,
) -> tuple[dict[str, Any], ...]:
    payload = json.loads(
        Path(path).read_text(encoding="utf-8-sig")
    )

    resources = (
        payload.get("resources", [])
        if isinstance(payload, dict)
        else payload
    )

    if not isinstance(resources, list):
        raise ValueError(
            "El manifiesto multimedia debe ser una lista."
        )

    result = []

    for item in resources:
        if not isinstance(item, dict):
            continue

        media_type = str(
            item.get("media_type") or ""
        ).strip()

        if media_type not in ALLOWED_MEDIA_TYPES:
            continue

        entry_id = str(
            item.get("entry_id") or ""
        ).strip()
        uri = str(item.get("uri") or "").strip()

        if not entry_id or not uri:
            continue

        result.append(
            {
                "entry_id": entry_id,
                "media_type": media_type,
                "uri": uri,
                "validated": bool(
                    item.get("validated", False)
                ),
                "autoplay": bool(
                    item.get("autoplay", False)
                ),
            }
        )

    return tuple(result)
'@

$N8n = @'
"""Contratos de automatización n8n."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class N8nEvent:
    event_type: str
    payload: dict[str, Any]
    idempotency_key: str


def lexical_entry_event(
    entry_id: str,
    operation: str,
) -> N8nEvent:
    normalized_operation = operation.strip().casefold()

    if normalized_operation not in {
        "created",
        "updated",
        "validated",
        "enrichment_requested",
    }:
        raise ValueError(
            f"Operación n8n no permitida: {operation}"
        )

    return N8nEvent(
        event_type=f"sgoda.lexical.{normalized_operation}",
        payload={
            "entry_id": entry_id,
            "operation": normalized_operation,
        },
        idempotency_key=(
            f"sgoda:{entry_id}:{normalized_operation}"
        ),
    )
'@

$Flutter = @'
"""Contratos consumibles por Flutter."""

from __future__ import annotations

from typing import Any


def lexical_card(
    entry: dict[str, Any],
    media: tuple[dict[str, Any], ...],
) -> dict[str, Any]:
    return {
        "entryId": entry["entry_id"],
        "languages": {
            "pu": entry.get("puinave", ""),
            "es": entry.get("spanish", ""),
            "en-US": entry.get("english_us", ""),
            "it": entry.get("italian", ""),
        },
        "category": entry.get("category", ""),
        "validated": bool(entry.get("validated", False)),
        "media": [
            {
                "type": item["media_type"],
                "uri": item["uri"],
                "validated": bool(
                    item.get("validated", False)
                ),
                "autoplay": bool(
                    item.get("autoplay", False)
                ),
            }
            for item in media
        ],
        "noInvention": True,
    }


def health_contract(status: dict[str, Any]) -> dict[str, Any]:
    return {
        "status": "ok" if status.get("healthy") else "degraded",
        "component": "SPT-011",
        "version": "1.0.0",
        "details": status,
    }
'@

$Service = @'
"""Servicio operativo de SPT-011."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .database import OperationalRepository
from .flutter_contracts import lexical_card
from .media_adapter import load_media_manifest
from .models import (
    OperationalRequest,
    OperationalResponse,
    RuntimeStatus,
)
from .n8n_contracts import lexical_entry_event
from .rlb_adapter import load_rlb
from .settings import OperationalSettings


class OperationalPlatformService:
    def __init__(
        self,
        settings: OperationalSettings,
        repository: OperationalRepository | None = None,
    ) -> None:
        self.settings = settings
        self.repository = repository or OperationalRepository()
        self._rlb_loaded = False
        self._media_loaded = False

    def load_sources(
        self,
        rlb_path: str | Path,
        media_path: str | Path | None = None,
    ) -> RuntimeStatus:
        entries = load_rlb(
            rlb_path,
            validated_only=self.settings.require_validated_entries,
        )
        self.repository.upsert_entries(entries)
        self._rlb_loaded = True

        if media_path:
            for media in load_media_manifest(media_path):
                if (
                    self.settings.require_validated_entries
                    and not media.get("validated", False)
                ):
                    continue

                entry_id = media["entry_id"]

                if self.repository.get_entry(entry_id) is None:
                    continue

                self.repository.attach_media(
                    entry_id,
                    media,
                )

            self._media_loaded = True

        return self.runtime_status()

    def runtime_status(self) -> RuntimeStatus:
        return RuntimeStatus(
            database_mode=self.settings.database_mode,
            rlb_loaded=self._rlb_loaded,
            media_loaded=self._media_loaded,
            n8n_enabled=self.settings.n8n_enabled,
            flutter_contract_enabled=(
                self.settings.flutter_contract_enabled
            ),
            api_enabled=True,
        )

    def execute(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        handlers = {
            "health": self._health,
            "get_lexical_card": self._get_lexical_card,
            "list_entries": self._list_entries,
            "n8n_event": self._n8n_event,
        }

        handler = handlers.get(request.operation)

        if handler is None:
            return OperationalResponse(
                operation=request.operation,
                status="unsupported_operation",
                data={},
                warnings=(
                    "La operación no está soportada.",
                ),
            )

        return handler(request)

    def _health(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        status = self.runtime_status()

        healthy = (
            status.rlb_loaded
            and status.flutter_contract_enabled
            and status.api_enabled
        )

        return OperationalResponse(
            operation="health",
            status="ok" if healthy else "degraded",
            data={
                "healthy": healthy,
                "database_mode": status.database_mode,
                "rlb_loaded": status.rlb_loaded,
                "media_loaded": status.media_loaded,
                "n8n_enabled": status.n8n_enabled,
                "flutter_contract_enabled": (
                    status.flutter_contract_enabled
                ),
                "api_enabled": status.api_enabled,
                "entry_count": self.repository.count(),
            },
        )

    def _get_lexical_card(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        entry_id = (
            request.entry_id
            or str(request.payload.get("entry_id") or "")
        )

        entry = self.repository.get_entry(entry_id)

        if entry is None:
            return OperationalResponse(
                operation="get_lexical_card",
                status="not_found",
                data={},
            )

        card = lexical_card(
            entry,
            self.repository.media_for(entry_id),
        )

        return OperationalResponse(
            operation="get_lexical_card",
            status="ok",
            data=card,
            sources=(f"RLB:{entry_id}",),
        )

    def _list_entries(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        entries = self.repository.all_entries()

        return OperationalResponse(
            operation="list_entries",
            status="ok",
            data={
                "total": len(entries),
                "entries": list(entries),
            },
            sources=tuple(
                f"RLB:{item['entry_id']}"
                for item in entries
            ),
        )

    def _n8n_event(
        self,
        request: OperationalRequest,
    ) -> OperationalResponse:
        entry_id = (
            request.entry_id
            or str(request.payload.get("entry_id") or "")
        )
        operation = str(
            request.payload.get("event_operation") or ""
        )

        event = lexical_entry_event(
            entry_id,
            operation,
        )

        return OperationalResponse(
            operation="n8n_event",
            status="ok",
            data={
                "event_type": event.event_type,
                "payload": event.payload,
                "idempotency_key": event.idempotency_key,
                "delivery_enabled": self.settings.n8n_enabled,
            },
            sources=(f"RLB:{entry_id}",),
        )
'@

$Api = @'
"""API operativa FastAPI de SPT-011."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .models import OperationalRequest
from .service import OperationalPlatformService
from .settings import OperationalSettings


def create_app(
    settings_path: str | Path,
    rlb_path: str | Path,
    media_path: str | Path | None = None,
):
    try:
        from fastapi import FastAPI, HTTPException
        from pydantic import BaseModel, Field
    except ImportError as error:
        raise RuntimeError(
            "FastAPI y Pydantic son requeridos para iniciar la API."
        ) from error

    settings = OperationalSettings.from_json(settings_path)
    service = OperationalPlatformService(settings)
    service.load_sources(rlb_path, media_path)

    app = FastAPI(
        title="SGODA-PUINAVE Plataforma Operativa",
        version="1.0.0",
    )

    class ExecuteBody(BaseModel):
        operation: str
        payload: dict[str, Any] = Field(default_factory=dict)
        session_id: str = "anonymous"
        language: str = "es"
        entry_id: str | None = None

    @app.get("/health")
    def health() -> dict:
        response = service.execute(
            OperationalRequest(operation="health")
        )

        return {
            "status": response.status,
            "data": response.data,
            "no_invention": response.no_invention,
        }

    @app.get("/lexical/{entry_id}")
    def lexical(entry_id: str) -> dict:
        response = service.execute(
            OperationalRequest(
                operation="get_lexical_card",
                entry_id=entry_id,
            )
        )

        if response.status == "not_found":
            raise HTTPException(
                status_code=404,
                detail="Entrada léxica no encontrada.",
            )

        return {
            "status": response.status,
            "data": response.data,
            "sources": list(response.sources),
            "no_invention": response.no_invention,
        }

    @app.post("/execute")
    def execute(body: ExecuteBody) -> dict:
        response = service.execute(
            OperationalRequest(
                operation=body.operation,
                payload=body.payload,
                session_id=body.session_id,
                language=body.language,
                entry_id=body.entry_id,
            )
        )

        return {
            "operation": response.operation,
            "status": response.status,
            "data": response.data,
            "sources": list(response.sources),
            "warnings": list(response.warnings),
            "no_invention": response.no_invention,
        }

    return app
'@

$Cli = @'
"""CLI operativa de SPT-011."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import OperationalRequest
from .service import OperationalPlatformService
from .settings import OperationalSettings


def _load_json(raw: str) -> dict:
    payload = json.loads(raw)

    if not isinstance(payload, dict):
        raise ValueError(
            "El payload debe ser un objeto JSON."
        )

    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--settings", required=True)
    parser.add_argument("--rlb", required=True)
    parser.add_argument("--media")
    parser.add_argument("--operation", required=True)
    parser.add_argument("--payload", default="{}")
    parser.add_argument("--entry")
    parser.add_argument("--session", default="anonymous")
    parser.add_argument("--language", default="es")
    parser.add_argument("--output")
    args = parser.parse_args()

    service = OperationalPlatformService(
        OperationalSettings.from_json(args.settings)
    )
    service.load_sources(
        args.rlb,
        args.media,
    )

    response = service.execute(
        OperationalRequest(
            operation=args.operation,
            payload=_load_json(args.payload),
            session_id=args.session,
            language=args.language,
            entry_id=args.entry,
        )
    )

    result = {
        "operation": response.operation,
        "status": response.status,
        "data": response.data,
        "sources": list(response.sources),
        "warnings": list(response.warnings),
        "no_invention": response.no_invention,
    }

    serialized = json.dumps(
        result,
        indent=2,
        ensure_ascii=False,
    )

    if args.output:
        target = Path(args.output)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            serialized + "\n",
            encoding="utf-8",
        )
    else:
        print(serialized)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""SPT-011 — Plataforma Operativa SGODA-PUINAVE."""

from .database import OperationalRepository
from .models import (
    OperationalRequest,
    OperationalResponse,
    RuntimeStatus,
)
from .service import OperationalPlatformService
from .settings import OperationalSettings

__all__ = [
    "OperationalPlatformService",
    "OperationalRepository",
    "OperationalRequest",
    "OperationalResponse",
    "OperationalSettings",
    "RuntimeStatus",
]
'@

$Tests = @'
from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.operational_platform import (
    OperationalPlatformService,
    OperationalRequest,
    OperationalSettings,
)
from sgoda.operational_platform.n8n_contracts import (
    lexical_entry_event,
)
from sgoda.operational_platform.rlb_adapter import load_rlb


def _settings(tmp_path: Path) -> Path:
    path = tmp_path / "settings.json"
    path.write_text(
        json.dumps(
            {
                "database_url": "sqlite:///demo.db",
                "database_mode": "local",
                "api_host": "127.0.0.1",
                "api_port": 8000,
                "n8n_enabled": False,
                "flutter_contract_enabled": True,
                "require_validated_entries": True,
                "no_invention": True,
            }
        ),
        encoding="utf-8",
    )
    return path


def _rlb(tmp_path: Path) -> Path:
    path = tmp_path / "rlb.json"
    path.write_text(
        json.dumps(
            {
                "entries": [
                    {
                        "entry_id": "LEX-001",
                        "puinave": "AMDA",
                        "spanish": "casa",
                        "english_us": "house",
                        "italian": "casa",
                        "validated": True,
                        "category": "sustantivo",
                    },
                    {
                        "entry_id": "LEX-999",
                        "puinave": "NO-VALIDADO",
                        "validated": False,
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def _media(tmp_path: Path) -> Path:
    path = tmp_path / "media.json"
    path.write_text(
        json.dumps(
            {
                "resources": [
                    {
                        "entry_id": "LEX-001",
                        "media_type": "audio_puinave",
                        "uri": "media/audio/LEX-001-pu.wav",
                        "validated": True,
                        "autoplay": True,
                    },
                    {
                        "entry_id": "LEX-001",
                        "media_type": "image",
                        "uri": "media/images/LEX-001.webp",
                        "validated": True,
                        "autoplay": True,
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def _service(tmp_path: Path) -> OperationalPlatformService:
    service = OperationalPlatformService(
        OperationalSettings.from_json(
            _settings(tmp_path)
        )
    )
    service.load_sources(
        _rlb(tmp_path),
        _media(tmp_path),
    )
    return service


def test_SPT_011_loads_validated_rlb(tmp_path: Path) -> None:
    records = load_rlb(_rlb(tmp_path), validated_only=True)

    assert len(records) == 1
    assert records[0]["entry_id"] == "LEX-001"


def test_SPT_011_reports_healthy_runtime(tmp_path: Path) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(operation="health")
    )

    assert response.status == "ok"
    assert response.data["healthy"] is True
    assert response.data["entry_count"] == 1


def test_SPT_011_builds_flutter_lexical_card(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="LEX-001",
        )
    )

    assert response.status == "ok"
    assert response.data["languages"]["pu"] == "AMDA"
    assert response.data["languages"]["en-US"] == "house"
    assert response.data["noInvention"] is True


def test_SPT_011_includes_validated_media(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="LEX-001",
        )
    )

    assert len(response.data["media"]) == 2
    assert response.data["media"][0]["validated"] is True


def test_SPT_011_returns_not_found_without_invention(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="UNKNOWN",
        )
    )

    assert response.status == "not_found"
    assert response.no_invention is True
    assert response.data == {}


def test_SPT_011_lists_entries(tmp_path: Path) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(operation="list_entries")
    )

    assert response.status == "ok"
    assert response.data["total"] == 1


def test_SPT_011_builds_n8n_event(tmp_path: Path) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="n8n_event",
            entry_id="LEX-001",
            payload={"event_operation": "validated"},
        )
    )

    assert response.status == "ok"
    assert response.data["event_type"] == (
        "sgoda.lexical.validated"
    )
    assert response.data["delivery_enabled"] is False


def test_SPT_011_n8n_event_is_idempotent() -> None:
    first = lexical_entry_event(
        "LEX-001",
        "validated",
    )
    second = lexical_entry_event(
        "LEX-001",
        "validated",
    )

    assert first == second


def test_SPT_011_rejects_unknown_n8n_operation() -> None:
    with pytest.raises(ValueError):
        lexical_entry_event(
            "LEX-001",
            "unknown",
        )


def test_SPT_011_rejects_unsupported_operation(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(operation="unknown")
    )

    assert response.status == "unsupported_operation"
    assert response.warnings


def test_SPT_011_is_deterministic(tmp_path: Path) -> None:
    service = _service(tmp_path)
    request = OperationalRequest(
        operation="get_lexical_card",
        entry_id="LEX-001",
    )

    assert service.execute(request) == service.execute(request)


def test_SPT_011_preserves_four_languages(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="LEX-001",
        )
    )

    assert set(response.data["languages"]) == {
        "pu",
        "es",
        "en-US",
        "it",
    }


def test_SPT_011_runtime_status_is_explicit(
    tmp_path: Path,
) -> None:
    status = _service(tmp_path).runtime_status()

    assert status.database_mode == "local"
    assert status.rlb_loaded is True
    assert status.media_loaded is True
    assert status.api_enabled is True


def test_SPT_011_settings_are_loaded(tmp_path: Path) -> None:
    settings = OperationalSettings.from_json(
        _settings(tmp_path)
    )

    assert settings.api_port == 8000
    assert settings.no_invention is True
'@

$Policy = @'
{
  "component": "SPT-011",
  "version": "1.0.0",
  "name": "Plataforma Operativa SGODA-PUINAVE",
  "phase": "Fase Tecnológica III",
  "local_first": true,
  "no_invention": true,
  "paid_services_required": false,
  "validated_entries_only": true,
  "supported_languages": [
    "pu",
    "es",
    "en-US",
    "it"
  ],
  "operational_integrations": [
    "FastAPI",
    "PostgreSQL",
    "Flutter",
    "n8n",
    "RLB",
    "Multimedia"
  ],
  "database": {
    "production_target": "PostgreSQL",
    "test_mode": "local_memory"
  }
}
'@

$RuntimeConfig = @'
{
  "database_url": "postgresql://sgoda:change-me@127.0.0.1:5432/sgoda",
  "database_mode": "local",
  "api_host": "127.0.0.1",
  "api_port": 8000,
  "n8n_enabled": false,
  "n8n_base_url": "http://127.0.0.1:5678",
  "flutter_contract_enabled": true,
  "require_validated_entries": true,
  "no_invention": true
}
'@

$Component = @'
{
  "increment_code": "SPT-011",
  "name": "Plataforma Operativa SGODA-PUINAVE",
  "component_type": "operational_digital_platform",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica III",
  "dependencies": [
    "SPT-010",
    "SPT-006A",
    "SPT-007A",
    "SPT-007B",
    "SPT-007C",
    "SPT-007D",
    "SPT-008",
    "SPT-009",
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/operational_platform/models.py",
    "src/sgoda/operational_platform/settings.py",
    "src/sgoda/operational_platform/database.py",
    "src/sgoda/operational_platform/rlb_adapter.py",
    "src/sgoda/operational_platform/media_adapter.py",
    "src/sgoda/operational_platform/n8n_contracts.py",
    "src/sgoda/operational_platform/flutter_contracts.py",
    "src/sgoda/operational_platform/service.py",
    "src/sgoda/operational_platform/api.py",
    "src/sgoda/operational_platform/cli.py"
  ],
  "tests": [
    "tests/operational_platform/test_SPT_011_operational_sgoda_platform.py"
  ],
  "documentation": [
    "docs/07_Fase_Tecnologica_III/SPT-011/SPT-011-Arquitectura-Plataforma-Operativa.md",
    "docs/07_Fase_Tecnologica_III/SPT-011/SPT-011-Integracion-FastAPI-PostgreSQL.md",
    "docs/07_Fase_Tecnologica_III/SPT-011/SPT-011-Contrato-Flutter.md",
    "docs/07_Fase_Tecnologica_III/SPT-011/SPT-011-Automatizacion-n8n.md",
    "docs/07_Fase_Tecnologica_III/SPT-011/SPT-011-Operacion-RLB-Multimedia.md",
    "docs/07_Fase_Tecnologica_III/SPT-011/SPT-011-Pruebas-Criterios-Aceptacion.md"
  ]
}
'@

$Docs = @{
    (Join-Path $DocsDir "SPT-011-Arquitectura-Plataforma-Operativa.md") = @'
# SPT-011 — Arquitectura de la Plataforma Operativa

SPT-011 inaugura la Fase Tecnológica III. La arquitectura separa contratos,
persistencia, RLB, multimedia, automatización n8n, contratos Flutter, servicio,
API y CLI.

La versión 1.0.0 opera localmente y deja PostgreSQL como destino productivo.
'@

    (Join-Path $DocsDir "SPT-011-Integracion-FastAPI-PostgreSQL.md") = @'
# Integración FastAPI y PostgreSQL

La API expone salud, fichas léxicas y ejecución operativa.

Las pruebas utilizan un repositorio local determinista. La conexión real a
PostgreSQL deberá activarse mediante configuración segura, migraciones y
credenciales externas al repositorio.
'@

    (Join-Path $DocsDir "SPT-011-Contrato-Flutter.md") = @'
# Contrato Flutter

La ficha léxica devuelve las lenguas pu, es, en-US e it, multimedia validada,
categoría, estado de validación y `noInvention=true`.

El contrato usa nombres JSON compatibles con Flutter.
'@

    (Join-Path $DocsDir "SPT-011-Automatizacion-n8n.md") = @'
# Automatización n8n

SPT-011 define eventos idempotentes para creación, actualización, validación
y solicitud de enriquecimiento de registros léxicos.

La entrega de eventos permanece deshabilitada hasta configurar una instancia
n8n autorizada.
'@

    (Join-Path $DocsDir "SPT-011-Operacion-RLB-Multimedia.md") = @'
# Operación del RLB y Multimedia

La plataforma carga únicamente registros validados. Los audios, imágenes y
videos deben declarar registro léxico, tipo, ruta y estado de validación.

No se generan palabras, traducciones ni relaciones culturales inexistentes.
'@

    (Join-Path $DocsDir "SPT-011-Pruebas-Criterios-Aceptacion.md") = @'
# Pruebas y criterios de aceptación

El incremento exige:

- pruebas específicas aprobadas;
- suite completa aprobada;
- demostración operativa aprobada;
- SGD-116 aprobado;
- SGD-114C aprobado;
- SGD-115 actualizado;
- release creado;
- publicación SPB-007;
- Git limpio.
'@
}

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Settings,

    [Parameter(Mandatory = $true)]
    [string]$Rlb,

    [string]$Media,

    [Parameter(Mandatory = $true)]
    [string]$Operation,

    [string]$Entry,

    [string]$Payload = "{}",

    [string]$Output = "artifacts/operational_platform/SPT-011/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.operational_platform.cli",
    "--settings",
    $Settings,
    "--rlb",
    $Rlb,
    "--operation",
    $Operation,
    "--payload",
    $Payload,
    "--output",
    $Output
)

if ($Media) {
    $Arguments += @("--media", $Media)
}

if ($Entry) {
    $Arguments += @("--entry", $Entry)
}

& python @Arguments
exit $LASTEXITCODE
'@

Write-Step "Instalando SPT-011"

Write-Utf8 -Path $ModelsPath -Content $Models
Write-Utf8 -Path $SettingsPath -Content $Settings
Write-Utf8 -Path $DatabasePath -Content $Database
Write-Utf8 -Path $RlbPath -Content $RlbAdapter
Write-Utf8 -Path $MediaPath -Content $MediaAdapter
Write-Utf8 -Path $N8nPath -Content $N8n
Write-Utf8 -Path $FlutterPath -Content $Flutter
Write-Utf8 -Path $ServicePath -Content $Service
Write-Utf8 -Path $ApiPath -Content $Api
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $InitPath -Content $Init
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $RuntimeConfigPath -Content $RuntimeConfig
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $InvokePath -Content $Invoke

foreach ($Document in $Docs.GetEnumerator()) {
    Write-Utf8 `
        -Path $Document.Key `
        -Content $Document.Value
}

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/operational_platform/models.py" `
        "src/sgoda/operational_platform/settings.py" `
        "src/sgoda/operational_platform/database.py" `
        "src/sgoda/operational_platform/rlb_adapter.py" `
        "src/sgoda/operational_platform/media_adapter.py" `
        "src/sgoda/operational_platform/n8n_contracts.py" `
        "src/sgoda/operational_platform/flutter_contracts.py" `
        "src/sgoda/operational_platform/service.py" `
        "src/sgoda/operational_platform/api.py" `
        "src/sgoda/operational_platform/cli.py" `
        "src/sgoda/operational_platform/__init__.py" `
        "tests/operational_platform/test_SPT_011_operational_sgoda_platform.py"
}

Invoke-Checked "Ejecutando 14 pruebas específicas SPT-011" {
    python -m pytest `
        "tests/operational_platform/test_SPT_011_operational_sgoda_platform.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Ejecutando demostración operativa"

Write-Json `
    -Path $DemoRlbPath `
    -Value ([ordered]@{
        entries = @(
            [ordered]@{
                entry_id = "LEX-001"
                puinave = "AMDA"
                spanish = "casa"
                english_us = "house"
                italian = "casa"
                validated = $true
                category = "sustantivo"
            }
        )
    })

Write-Json `
    -Path $DemoMediaPath `
    -Value ([ordered]@{
        resources = @(
            [ordered]@{
                entry_id = "LEX-001"
                media_type = "audio_puinave"
                uri = "media/audio/LEX-001-pu.wav"
                validated = $true
                autoplay = $true
            },
            [ordered]@{
                entry_id = "LEX-001"
                media_type = "image"
                uri = "media/images/LEX-001.webp"
                validated = $true
                autoplay = $true
            }
        )
    })

Invoke-Checked "Consultando ficha operativa AMDA" {
    python -m sgoda.operational_platform.cli `
        --settings "$RuntimeConfigPath" `
        --rlb "$DemoRlbPath" `
        --media "$DemoMediaPath" `
        --operation "get_lexical_card" `
        --entry "LEX-001" `
        --payload "{}" `
        --output "$DemoResultPath"
}

$Demo = Get-Content `
    -LiteralPath $DemoResultPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración operativa no fue aprobada."
}

if ($Demo.data.languages.pu -ne "AMDA") {
    throw "La demostración no recuperó la palabra Puinave."
}

if (-not [bool]$Demo.data.noInvention) {
    throw "La demostración no respetó noInvention=true."
}

if (@($Demo.data.media).Count -lt 2) {
    throw "La demostración no recuperó los recursos multimedia."
}

if (-not $SkipInstitutionalClosure) {
    Write-Step "Regenerando Roadmap Maestro SGD-116"

    Invoke-Checked "Actualizando SGD-116" {
        python -m sgoda.roadmap.cli `
            --root "$ProjectRoot" `
            --output "artifacts/roadmap/SGD-116"
    }

    $RoadmapValidationPath = Join-Path `
        $ProjectRoot `
        "artifacts\roadmap\SGD-116\validation.json"

    Require-File -Path $RoadmapValidationPath

    $RoadmapValidation = Get-Content `
        -LiteralPath $RoadmapValidationPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$RoadmapValidation.passed) {
        throw "SGD-116 no aprobó SPT-011."
    }

    Write-Step "Evaluando SPT-011 mediante SGD-114C"

    New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

    & python -m sgoda.governance.policy_cli `
        --root "$ProjectRoot" `
        --policy "config/governance/SGD-114C-policy.json" `
        --increment "SPT-011" `
        --output-json "$GateJson" `
        --output-md "$GateMd"

    $GateExitCode = $LASTEXITCODE

    Require-File -Path $GateJson
    Require-File -Path $GateMd

    $Gate = Get-Content `
        -LiteralPath $GateJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if ($GateExitCode -ne 0 -or -not [bool]$Gate.approved) {
        @($Gate.results) |
            Where-Object { $_.blocking } |
            Format-Table rule, name, message, remediation -AutoSize

        throw "SGD-114C no aprobó SPT-011."
    }

    Write-Step "Regenerando Documentación Maestra SGD-115"

    Invoke-Checked "Actualizando SGD-115" {
        python -m sgoda.documentation.master_docs `
            --root "$ProjectRoot" `
            --output "artifacts/documentation/SGD-115"
    }

    Write-Step "Generando evidencia y release"

    Write-Json `
        -Path $EvidencePath `
        -Value ([ordered]@{
            increment_code = "SPT-011"
            version = "1.0.0"
            phase = "Fase Tecnológica III"
            status = "implemented"
            generated_at_utc = [DateTime]::UtcNow.ToString("o")
            capabilities = @(
                "operational_service",
                "rlb_adapter",
                "multimedia_adapter",
                "flutter_contract",
                "n8n_contract",
                "fastapi_contract",
                "postgresql_target",
                "local_test_repository",
                "no_invention"
            )
            specific_tests = 14
            full_suite_executed = (-not $SkipFullSuite)
            demo_status = $Demo.status
            demo_entry = $Demo.data.entryId
            demo_media_count = @($Demo.data.media).Count
            no_invention = [bool]$Demo.data.noInvention
            roadmap_approved = [bool]$RoadmapValidation.passed
            policy_approved = [bool]$Gate.approved
            policy_exit_code = $Gate.exit_code
            backup = $BackupDir
        })

    foreach ($ReleaseFile in @(
        $ModelsPath,
        $SettingsPath,
        $DatabasePath,
        $RlbPath,
        $MediaPath,
        $N8nPath,
        $FlutterPath,
        $ServicePath,
        $ApiPath,
        $CliPath,
        $InitPath,
        $TestPath,
        $PolicyPath,
        $RuntimeConfigPath,
        $ComponentPath,
        $InvokePath,
        $DemoRlbPath,
        $DemoMediaPath,
        $DemoResultPath,
        $EvidencePath,
        $GateJson,
        $GateMd
    )) {
        Require-File -Path $ReleaseFile

        Copy-Item `
            -LiteralPath $ReleaseFile `
            -Destination (
                Join-Path $ReleaseDir (Split-Path $ReleaseFile -Leaf)
            ) `
            -Force
    }

    foreach ($Document in $Docs.Keys) {
        Require-File -Path $Document

        Copy-Item `
            -LiteralPath $Document `
            -Destination (
                Join-Path $ReleaseDir (Split-Path $Document -Leaf)
            ) `
            -Force
    }
}

Write-Step "Resultado final"

Write-Host "SPT-011 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Fase Tecnológica III: INICIADA Y OPERATIVA." -ForegroundColor Green
Write-Host "Plataforma Operativa SGODA-PUINAVE: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Pruebas específicas: 14 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "RLB validado: INTEGRADO." -ForegroundColor Green
Write-Host "Multimedia validada: INTEGRADA." -ForegroundColor Green
Write-Host "Contrato Flutter: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Contrato n8n: IMPLEMENTADO." -ForegroundColor Green
Write-Host "API FastAPI: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Destino PostgreSQL: CONFIGURADO." -ForegroundColor Green
Write-Host "Persistencia local de pruebas: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Demostración AMDA: APROBADA." -ForegroundColor Green
Write-Host "No invención Puinave: APROBADA." -ForegroundColor Green

if (-not $SkipInstitutionalClosure) {
    Write-Host "SGD-116: APROBADO." -ForegroundColor Green
    Write-Host "SGD-114C: APROBADO." -ForegroundColor Green
    Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
    Write-Host "Release: releases\SPT-011-v1.0.0" -ForegroundColor Cyan
    Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
}

Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
