<#
.SYNOPSIS
    Instala SPT-014 v1.0.0 — Motor Multimedia Inteligente.

.DESCRIPTION
    Implementa el motor multimedia nativo de la Fase Tecnológica IV.

    Incluye:
      - modelo institucional de recursos multimedia;
      - asociación con entradas léxicas SPT-013B;
      - imágenes, audios Puinave/español/inglés/italiano y video;
      - validación de tipo, formato, ruta y estado;
      - manifiestos multimedia JSON;
      - selección de recursos por entrada e idioma;
      - construcción de paquetes ODA multimedia;
      - detección de faltantes y duplicados;
      - importación y exportación;
      - CLI y demostración AMDA;
      - pruebas específicas y suite completa;
      - SGD-114D, SGD-114E, SGD-115 y SGD-116;
      - evidencia, release y publicación condicionada.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.

.PARAMETER Publish
    Publica mediante SPB-007 únicamente si todos los gates aprueban.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Publish -and $SkipFullSuite) {
    throw "No se permite publicar con -SkipFullSuite."
}

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

    Write-Host "Creado/actualizado: $Path ($($Info.Length) bytes)" `
        -ForegroundColor Green
}

function Write-Json {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )

    Write-Utf8 `
        -Path $Path `
        -Content (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\multimedia_engine"
$TestsDir = Join-Path $ProjectRoot "tests\multimedia_engine"
$ConfigDir = Join-Path $ProjectRoot "config\multimedia_engine"
$DocsDir = Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-014"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\multimedia_engine\SPT-014"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-014"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-014-v1.0.0"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SPT014-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "models.py"
$ValidationPath = Join-Path $SourceDir "validation.py"
$RepositoryPath = Join-Path $SourceDir "repository.py"
$ManifestPath = Join-Path $SourceDir "manifest.py"
$OdaPath = Join-Path $SourceDir "oda.py"
$ServicePath = Join-Path $SourceDir "service.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SPT_014_intelligent_multimedia_engine.py"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SPT-014-component.json"

$PolicyPath = Join-Path `
    $ConfigDir `
    "SPT-014-policy.json"

$SchemaPath = Join-Path `
    $ConfigDir `
    "SPT-014-media-schema.json"

$InvokePath = Join-Path `
    $ScriptsDir `
    "Invoke-SPT014-MultimediaEngine.ps1"

$DemoRequestPath = Join-Path $ArtifactsDir "demo-request.json"
$DemoOutputPath = Join-Path $ArtifactsDir "demo-output.json"

$PolicyJson = Join-Path $PmoDir "SPT-014-policy-result.json"
$PolicyMd = Join-Path $PmoDir "SPT-014-policy-result.md"
$NativeJson = Join-Path $PmoDir "SPT-014-native-result.json"
$NativeMd = Join-Path $PmoDir "SPT-014-native-result.md"
$EvidencePath = Join-Path $PmoDir "SPT-014-implementation-evidence.json"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\learning_foundation\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\dictionary_manager\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\learning_platform\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\adaptive_policy_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_cli.py"),
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
    $ValidationPath,
    $RepositoryPath,
    $ManifestPath,
    $OdaPath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $SchemaPath,
    $InvokePath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Models = @'
"""Modelos institucionales del Motor Multimedia Inteligente."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class MediaResource:
    resource_id: str
    entry_id: str
    media_type: str
    language: str
    uri: str
    format: str
    validated: bool = False
    autoplay: bool = False
    duration_seconds: float | None = None
    checksum: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class MultimediaCommand:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class MultimediaResult:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True
'@

$Validation = @'
"""Validación institucional de recursos multimedia."""

from __future__ import annotations

from pathlib import PurePosixPath
from typing import Any


_ALLOWED_TYPES = {
    "image",
    "audio_puinave",
    "audio_spanish",
    "audio_english_us",
    "audio_italian",
    "video",
}

_ALLOWED_FORMATS = {
    "image": {"png", "jpg", "jpeg", "webp"},
    "audio_puinave": {"wav", "mp3", "ogg", "flac"},
    "audio_spanish": {"wav", "mp3", "ogg", "flac"},
    "audio_english_us": {"wav", "mp3", "ogg", "flac"},
    "audio_italian": {"wav", "mp3", "ogg", "flac"},
    "video": {"mp4", "webm"},
}


def normalize_text(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def validate_media_payload(
    payload: dict[str, Any],
) -> tuple[str, ...]:
    errors = []

    resource_id = normalize_text(payload.get("resource_id"))
    entry_id = normalize_text(payload.get("entry_id"))
    media_type = normalize_text(payload.get("media_type"))
    uri = normalize_text(payload.get("uri"))
    media_format = normalize_text(payload.get("format")).casefold()

    if not resource_id.startswith("MED-"):
        errors.append("resource_id debe iniciar con MED-.")

    if not entry_id.startswith("LEX-"):
        errors.append("entry_id debe iniciar con LEX-.")

    if media_type not in _ALLOWED_TYPES:
        errors.append("media_type no está permitido.")

    if not uri:
        errors.append("La URI del recurso es obligatoria.")
    elif PurePosixPath(uri.replace("\\", "/")).is_absolute():
        errors.append("La URI debe ser relativa al repositorio.")

    allowed = _ALLOWED_FORMATS.get(media_type, set())
    if media_format not in allowed:
        errors.append(
            f"Formato no permitido para {media_type}: {media_format}"
        )

    duration = payload.get("duration_seconds")
    if duration is not None:
        try:
            if float(duration) < 0:
                errors.append("duration_seconds no puede ser negativo.")
        except (TypeError, ValueError):
            errors.append("duration_seconds debe ser numérico.")

    return tuple(errors)
'@

$Repository = @'
"""Repositorio de recursos multimedia."""

from __future__ import annotations

from .models import MediaResource


class MediaRepository:
    def __init__(self) -> None:
        self._resources: dict[str, MediaResource] = {}

    def add(self, resource: MediaResource) -> MediaResource:
        if resource.resource_id in self._resources:
            raise ValueError(
                f"El recurso ya existe: {resource.resource_id}"
            )

        self._resources[resource.resource_id] = resource
        return resource

    def upsert(self, resource: MediaResource) -> MediaResource:
        self._resources[resource.resource_id] = resource
        return resource

    def get(self, resource_id: str) -> MediaResource | None:
        return self._resources.get(
            str(resource_id or "").strip()
        )

    def all(self) -> tuple[MediaResource, ...]:
        return tuple(
            self._resources[key]
            for key in sorted(self._resources)
        )

    def for_entry(
        self,
        entry_id: str,
        validated_only: bool = False,
    ) -> tuple[MediaResource, ...]:
        items = [
            item
            for item in self.all()
            if item.entry_id == entry_id
        ]

        if validated_only:
            items = [
                item
                for item in items
                if item.validated
            ]

        return tuple(items)

    def find_duplicates(self) -> tuple[dict[str, str], ...]:
        seen = {}
        duplicates = []

        for item in self.all():
            key = (
                item.entry_id,
                item.media_type,
                item.language,
                item.uri.casefold(),
            )

            if key in seen:
                duplicates.append(
                    {
                        "first": seen[key],
                        "duplicate": item.resource_id,
                    }
                )
            else:
                seen[key] = item.resource_id

        return tuple(duplicates)
'@

$Manifest = @'
"""Importación y exportación de manifiestos multimedia."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import MediaResource
from .validation import normalize_text


def media_from_dict(payload: dict[str, Any]) -> MediaResource:
    duration = payload.get("duration_seconds")

    return MediaResource(
        resource_id=normalize_text(payload.get("resource_id")),
        entry_id=normalize_text(payload.get("entry_id")),
        media_type=normalize_text(payload.get("media_type")),
        language=normalize_text(payload.get("language")),
        uri=normalize_text(payload.get("uri")).replace("\\", "/"),
        format=normalize_text(payload.get("format")).casefold(),
        validated=bool(payload.get("validated", False)),
        autoplay=bool(payload.get("autoplay", False)),
        duration_seconds=(
            float(duration)
            if duration is not None
            else None
        ),
        checksum=normalize_text(payload.get("checksum")),
        metadata=dict(payload.get("metadata") or {}),
    )


def media_to_dict(resource: MediaResource) -> dict[str, Any]:
    return {
        "resource_id": resource.resource_id,
        "entry_id": resource.entry_id,
        "media_type": resource.media_type,
        "language": resource.language,
        "uri": resource.uri,
        "format": resource.format,
        "validated": resource.validated,
        "autoplay": resource.autoplay,
        "duration_seconds": resource.duration_seconds,
        "checksum": resource.checksum,
        "metadata": dict(resource.metadata),
    }


def load_manifest(path: str | Path) -> tuple[MediaResource, ...]:
    payload = json.loads(
        Path(path).read_text(encoding="utf-8-sig")
    )
    records = (
        payload.get("resources", [])
        if isinstance(payload, dict)
        else payload
    )

    if not isinstance(records, list):
        raise ValueError(
            "El manifiesto debe contener una lista de recursos."
        )

    return tuple(
        media_from_dict(item)
        for item in records
        if isinstance(item, dict)
    )


def export_manifest(
    path: str | Path,
    resources: tuple[MediaResource, ...],
) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            {
                "schema": "SPT-014",
                "version": "1.0.0",
                "resources": [
                    media_to_dict(item)
                    for item in resources
                ],
            },
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )
'@

$Oda = @'
"""Construcción de paquetes multimedia para ODA."""

from __future__ import annotations

from typing import Any

from .manifest import media_to_dict
from .models import MediaResource


_REQUIRED_TYPES = {
    "image",
    "audio_puinave",
    "audio_spanish",
    "audio_english_us",
}


def build_multimedia_oda(
    entry_id: str,
    resources: tuple[MediaResource, ...],
) -> dict[str, Any]:
    validated = tuple(
        item
        for item in resources
        if item.validated
    )
    available_types = {
        item.media_type
        for item in validated
    }
    missing = sorted(
        _REQUIRED_TYPES - available_types
    )

    return {
        "oda_id": f"ODA-MEDIA-{entry_id}",
        "entry_id": entry_id,
        "resources": [
            media_to_dict(item)
            for item in validated
        ],
        "required_types": sorted(_REQUIRED_TYPES),
        "missing_types": missing,
        "complete": len(missing) == 0,
        "validated_only": True,
        "no_invention": True,
    }
'@

$Service = @'
"""Servicio principal de SPT-014."""

from __future__ import annotations

from typing import Any

from .manifest import (
    export_manifest,
    load_manifest,
    media_from_dict,
    media_to_dict,
)
from .models import MultimediaCommand, MultimediaResult
from .oda import build_multimedia_oda
from .repository import MediaRepository
from .validation import validate_media_payload


class IntelligentMultimediaEngine:
    def __init__(
        self,
        repository: MediaRepository | None = None,
    ) -> None:
        self.repository = repository or MediaRepository()

    def execute(
        self,
        command: MultimediaCommand,
    ) -> MultimediaResult:
        handlers = {
            "register": self._register,
            "upsert": self._upsert,
            "get": self._get,
            "for_entry": self._for_entry,
            "build_oda": self._build_oda,
            "import_manifest": self._import_manifest,
            "export_manifest": self._export_manifest,
            "audit": self._audit,
            "stats": self._stats,
        }

        handler = handlers.get(command.operation)

        if handler is None:
            return MultimediaResult(
                operation=command.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(command.payload)

    def _register(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        errors = validate_media_payload(payload)

        if errors:
            return MultimediaResult(
                operation="register",
                status="invalid_resource",
                data={"errors": list(errors)},
                warnings=errors,
            )

        resource = media_from_dict(payload)

        try:
            self.repository.add(resource)
        except ValueError as error:
            return MultimediaResult(
                operation="register",
                status="duplicate_id",
                data={"resource_id": resource.resource_id},
                warnings=(str(error),),
            )

        return MultimediaResult(
            operation="register",
            status="ok",
            data=media_to_dict(resource),
        )

    def _upsert(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        errors = validate_media_payload(payload)

        if errors:
            return MultimediaResult(
                operation="upsert",
                status="invalid_resource",
                data={"errors": list(errors)},
                warnings=errors,
            )

        resource = self.repository.upsert(
            media_from_dict(payload)
        )

        return MultimediaResult(
            operation="upsert",
            status="ok",
            data=media_to_dict(resource),
        )

    def _get(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        resource_id = str(
            payload.get("resource_id") or ""
        ).strip()
        resource = self.repository.get(resource_id)

        if resource is None:
            return MultimediaResult(
                operation="get",
                status="not_found",
                data={"resource_id": resource_id},
            )

        return MultimediaResult(
            operation="get",
            status="ok",
            data=media_to_dict(resource),
        )

    def _for_entry(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        entry_id = str(payload.get("entry_id") or "").strip()
        validated_only = bool(
            payload.get("validated_only", False)
        )
        resources = self.repository.for_entry(
            entry_id,
            validated_only=validated_only,
        )

        return MultimediaResult(
            operation="for_entry",
            status="ok",
            data={
                "entry_id": entry_id,
                "total": len(resources),
                "resources": [
                    media_to_dict(item)
                    for item in resources
                ],
            },
        )

    def _build_oda(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        entry_id = str(payload.get("entry_id") or "").strip()
        resources = self.repository.for_entry(
            entry_id,
            validated_only=False,
        )

        return MultimediaResult(
            operation="build_oda",
            status="ok",
            data=build_multimedia_oda(
                entry_id,
                resources,
            ),
        )

    def _import_manifest(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        path = str(payload.get("path") or "").strip()
        imported = 0
        rejected = []

        for resource in load_manifest(path):
            raw = media_to_dict(resource)
            errors = validate_media_payload(raw)

            if errors:
                rejected.append(
                    {
                        "resource_id": resource.resource_id,
                        "errors": list(errors),
                    }
                )
                continue

            self.repository.upsert(resource)
            imported += 1

        return MultimediaResult(
            operation="import_manifest",
            status="ok",
            data={
                "imported": imported,
                "rejected": rejected,
            },
        )

    def _export_manifest(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        path = str(payload.get("path") or "").strip()
        export_manifest(path, self.repository.all())

        return MultimediaResult(
            operation="export_manifest",
            status="ok",
            data={
                "path": path,
                "total": len(self.repository.all()),
            },
        )

    def _audit(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        duplicates = self.repository.find_duplicates()
        invalid = []

        for resource in self.repository.all():
            errors = validate_media_payload(
                media_to_dict(resource)
            )

            if errors:
                invalid.append(
                    {
                        "resource_id": resource.resource_id,
                        "errors": list(errors),
                    }
                )

        approved = not duplicates and not invalid

        return MultimediaResult(
            operation="audit",
            status="ok" if approved else "not_approved",
            data={
                "approved": approved,
                "duplicates": list(duplicates),
                "invalid": invalid,
            },
        )

    def _stats(
        self,
        payload: dict[str, Any],
    ) -> MultimediaResult:
        resources = self.repository.all()

        return MultimediaResult(
            operation="stats",
            status="ok",
            data={
                "total": len(resources),
                "validated": sum(
                    1 for item in resources if item.validated
                ),
                "pending_validation": sum(
                    1 for item in resources if not item.validated
                ),
                "images": sum(
                    1
                    for item in resources
                    if item.media_type == "image"
                ),
                "audio": sum(
                    1
                    for item in resources
                    if item.media_type.startswith("audio_")
                ),
                "video": sum(
                    1
                    for item in resources
                    if item.media_type == "video"
                ),
            },
        )
'@

$Cli = @'
"""CLI del Motor Multimedia Inteligente."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import MultimediaCommand
from .service import IntelligentMultimediaEngine


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request-file", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    request = json.loads(
        Path(args.request_file).read_text(
            encoding="utf-8-sig"
        )
    )

    engine = IntelligentMultimediaEngine()
    preload = request.get("preload", [])

    for item in preload:
        engine.execute(
            MultimediaCommand(
                operation="upsert",
                payload=dict(item),
            )
        )

    response = engine.execute(
        MultimediaCommand(
            operation=str(request["operation"]),
            payload=dict(request.get("payload") or {}),
        )
    )

    result = {
        "operation": response.operation,
        "status": response.status,
        "data": response.data,
        "warnings": list(response.warnings),
        "no_invention": response.no_invention,
    }

    target = Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            result,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    print("SPT-014 ejecutado correctamente.")
    print(f"Operación: {response.operation}")
    print(f"Estado: {response.status}")
    print(f"Resultado: {target}")

    return 0 if response.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""SPT-014 — Motor Multimedia Inteligente."""

from .manifest import (
    export_manifest,
    load_manifest,
    media_from_dict,
    media_to_dict,
)
from .models import (
    MediaResource,
    MultimediaCommand,
    MultimediaResult,
)
from .oda import build_multimedia_oda
from .repository import MediaRepository
from .service import IntelligentMultimediaEngine

__all__ = [
    "IntelligentMultimediaEngine",
    "MediaRepository",
    "MediaResource",
    "MultimediaCommand",
    "MultimediaResult",
    "build_multimedia_oda",
    "export_manifest",
    "load_manifest",
    "media_from_dict",
    "media_to_dict",
]
'@

$Tests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.multimedia_engine import (
    IntelligentMultimediaEngine,
    MultimediaCommand,
)


def _resource(
    resource_id: str = "MED-001",
    media_type: str = "image",
    language: str = "und",
    uri: str = "media/images/LEX-001.webp",
    media_format: str = "webp",
    validated: bool = True,
) -> dict:
    return {
        "resource_id": resource_id,
        "entry_id": "LEX-001",
        "media_type": media_type,
        "language": language,
        "uri": uri,
        "format": media_format,
        "validated": validated,
    }


def test_SPT_014_registers_resource() -> None:
    engine = IntelligentMultimediaEngine()
    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    assert result.status == "ok"
    assert result.data["resource_id"] == "MED-001"


def test_SPT_014_rejects_invalid_resource_id() -> None:
    engine = IntelligentMultimediaEngine()
    payload = _resource()
    payload["resource_id"] = "BAD"

    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=payload,
        )
    )

    assert result.status == "invalid_resource"


def test_SPT_014_rejects_invalid_entry_id() -> None:
    engine = IntelligentMultimediaEngine()
    payload = _resource()
    payload["entry_id"] = "BAD"

    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=payload,
        )
    )

    assert result.status == "invalid_resource"


def test_SPT_014_rejects_invalid_format() -> None:
    engine = IntelligentMultimediaEngine()
    payload = _resource()
    payload["format"] = "exe"

    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=payload,
        )
    )

    assert result.status == "invalid_resource"


def test_SPT_014_rejects_absolute_uri() -> None:
    engine = IntelligentMultimediaEngine()
    payload = _resource()
    payload["uri"] = "/root/private/file.webp"

    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=payload,
        )
    )

    assert result.status == "invalid_resource"


def test_SPT_014_detects_duplicate_id() -> None:
    engine = IntelligentMultimediaEngine()
    command = MultimediaCommand(
        operation="register",
        payload=_resource(),
    )
    engine.execute(command)

    result = engine.execute(command)

    assert result.status == "duplicate_id"


def test_SPT_014_gets_resource() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(
            operation="get",
            payload={"resource_id": "MED-001"},
        )
    )

    assert result.status == "ok"


def test_SPT_014_lists_resources_for_entry() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(
            operation="for_entry",
            payload={"entry_id": "LEX-001"},
        )
    )

    assert result.data["total"] == 1


def test_SPT_014_filters_validated_resources() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(validated=False),
        )
    )

    result = engine.execute(
        MultimediaCommand(
            operation="for_entry",
            payload={
                "entry_id": "LEX-001",
                "validated_only": True,
            },
        )
    )

    assert result.data["total"] == 0


def test_SPT_014_builds_incomplete_oda() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(
            operation="build_oda",
            payload={"entry_id": "LEX-001"},
        )
    )

    assert result.status == "ok"
    assert result.data["complete"] is False
    assert "audio_puinave" in result.data["missing_types"]


def test_SPT_014_builds_complete_oda() -> None:
    engine = IntelligentMultimediaEngine()
    resources = [
        _resource(),
        _resource(
            "MED-002",
            "audio_puinave",
            "pu",
            "media/audio/LEX-001-pu.wav",
            "wav",
        ),
        _resource(
            "MED-003",
            "audio_spanish",
            "es",
            "media/audio/LEX-001-es.wav",
            "wav",
        ),
        _resource(
            "MED-004",
            "audio_english_us",
            "en-US",
            "media/audio/LEX-001-en.wav",
            "wav",
        ),
    ]

    for item in resources:
        engine.execute(
            MultimediaCommand(
                operation="register",
                payload=item,
            )
        )

    result = engine.execute(
        MultimediaCommand(
            operation="build_oda",
            payload={"entry_id": "LEX-001"},
        )
    )

    assert result.data["complete"] is True
    assert result.data["missing_types"] == []


def test_SPT_014_imports_manifest(tmp_path: Path) -> None:
    path = tmp_path / "manifest.json"
    path.write_text(
        json.dumps({"resources": [_resource()]}),
        encoding="utf-8",
    )

    engine = IntelligentMultimediaEngine()
    result = engine.execute(
        MultimediaCommand(
            operation="import_manifest",
            payload={"path": str(path)},
        )
    )

    assert result.data["imported"] == 1


def test_SPT_014_exports_manifest(tmp_path: Path) -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )
    target = tmp_path / "export.json"

    result = engine.execute(
        MultimediaCommand(
            operation="export_manifest",
            payload={"path": str(target)},
        )
    )

    assert result.status == "ok"
    assert target.exists()


def test_SPT_014_audit_passes_clean_repository() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(operation="audit")
    )

    assert result.status == "ok"
    assert result.data["approved"] is True


def test_SPT_014_reports_stats() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(operation="stats")
    )

    assert result.data["total"] == 1
    assert result.data["images"] == 1


def test_SPT_014_preserves_no_invention() -> None:
    result = IntelligentMultimediaEngine().execute(
        MultimediaCommand(operation="stats")
    )

    assert result.no_invention is True


def test_SPT_014_rejects_unknown_operation() -> None:
    result = IntelligentMultimediaEngine().execute(
        MultimediaCommand(operation="unknown")
    )

    assert result.status == "unsupported_operation"


def test_SPT_014_is_deterministic() -> None:
    engine = IntelligentMultimediaEngine()
    request = MultimediaCommand(operation="stats")

    assert engine.execute(request) == engine.execute(request)
'@

$Component = @'
{
  "increment_code": "SPT-014",
  "name": "Motor Multimedia Inteligente",
  "component_type": "intelligent_multimedia_engine",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica IV",
  "native_ecosystem": true,
  "ecosystem_role": "native_component",
  "technology_policy": "free_open_optional_proprietary",
  "mandatory_proprietary_dependencies": [],
  "institutional_terminology": "integrado nativamente al ecosistema SGODA-PUINAVE",
  "dependencies": [
    "SPT-013A",
    "SPT-013B",
    "SPT-012",
    "SPT-002",
    "SPT-003A",
    "SPT-003B",
    "SPT-003C",
    "SGD-114D",
    "SGD-114E",
    "SGD-115A",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/multimedia_engine/models.py",
    "src/sgoda/multimedia_engine/validation.py",
    "src/sgoda/multimedia_engine/repository.py",
    "src/sgoda/multimedia_engine/manifest.py",
    "src/sgoda/multimedia_engine/oda.py",
    "src/sgoda/multimedia_engine/service.py",
    "src/sgoda/multimedia_engine/cli.py"
  ],
  "tests": [
    "tests/multimedia_engine/test_SPT_014_intelligent_multimedia_engine.py"
  ],
  "documentation": [
    "docs/08_Fase_Tecnologica_IV/SPT-014/SPT-014-Arquitectura.md",
    "docs/08_Fase_Tecnologica_IV/SPT-014/SPT-014-Politica-Multimedia.md",
    "docs/08_Fase_Tecnologica_IV/SPT-014/SPT-014-ODA-Multimedia.md"
  ]
}
'@

$Policy = @'
{
  "component": "SPT-014",
  "version": "1.0.0",
  "validated_media_only_for_oda": true,
  "relative_repository_uris_only": true,
  "no_invention": true,
  "local_first": true,
  "free_open_technology": true,
  "mandatory_proprietary_dependencies": [],
  "required_oda_media": [
    "image",
    "audio_puinave",
    "audio_spanish",
    "audio_english_us"
  ]
}
'@

$Schema = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SPT-014 Media Resource",
  "type": "object",
  "required": [
    "resource_id",
    "entry_id",
    "media_type",
    "uri",
    "format"
  ],
  "properties": {
    "resource_id": {
      "type": "string",
      "pattern": "^MED-"
    },
    "entry_id": {
      "type": "string",
      "pattern": "^LEX-"
    },
    "media_type": {
      "enum": [
        "image",
        "audio_puinave",
        "audio_spanish",
        "audio_english_us",
        "audio_italian",
        "video"
      ]
    },
    "uri": {
      "type": "string",
      "minLength": 1
    },
    "format": {
      "type": "string"
    },
    "validated": {
      "type": "boolean"
    }
  }
}
'@

$Docs = @{
    (Join-Path $DocsDir "SPT-014-Arquitectura.md") = @'
# SPT-014 — Arquitectura

SPT-014 administra recursos multimedia asociados a las entradas léxicas de
SPT-013B. El motor opera localmente, conserva rutas relativas al repositorio
y entrega recursos validados a SPT-012 y a los ODA.
'@

    (Join-Path $DocsDir "SPT-014-Politica-Multimedia.md") = @'
# SPT-014 — Política multimedia

Se admiten imágenes, audios Puinave, español, inglés americano, italiano y
video. Los ODA únicamente consumen recursos validados.

No se admiten dependencias propietarias obligatorias ni rutas absolutas
externas al repositorio.
'@

    (Join-Path $DocsDir "SPT-014-ODA-Multimedia.md") = @'
# SPT-014 — ODA multimedia

Un paquete ODA multimedia completo requiere:

- imagen;
- audio Puinave;
- audio español;
- audio inglés americano.

Los recursos opcionales incluyen audio italiano y video. El motor reporta
automáticamente los tipos faltantes.
'@
}

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [string]$Output = "artifacts/multimedia_engine/SPT-014/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.multimedia_engine.cli `
    --request-file "$RequestFile" `
    --output "$Output"

exit $LASTEXITCODE
'@

Write-Step "Instalando SPT-014"

Write-Utf8 -Path $ModelsPath -Content $Models
Write-Utf8 -Path $ValidationPath -Content $Validation
Write-Utf8 -Path $RepositoryPath -Content $Repository
Write-Utf8 -Path $ManifestPath -Content $Manifest
Write-Utf8 -Path $OdaPath -Content $Oda
Write-Utf8 -Path $ServicePath -Content $Service
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $InitPath -Content $Init
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $SchemaPath -Content $Schema
Write-Utf8 -Path $InvokePath -Content $Invoke

foreach ($Document in $Docs.GetEnumerator()) {
    Write-Utf8 `
        -Path $Document.Key `
        -Content $Document.Value
}

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/multimedia_engine/models.py" `
        "src/sgoda/multimedia_engine/validation.py" `
        "src/sgoda/multimedia_engine/repository.py" `
        "src/sgoda/multimedia_engine/manifest.py" `
        "src/sgoda/multimedia_engine/oda.py" `
        "src/sgoda/multimedia_engine/service.py" `
        "src/sgoda/multimedia_engine/cli.py" `
        "src/sgoda/multimedia_engine/__init__.py" `
        "tests/multimedia_engine/test_SPT_014_intelligent_multimedia_engine.py"
}

Invoke-Checked "Ejecutando 18 pruebas específicas SPT-014" {
    python -m pytest `
        "tests/multimedia_engine/test_SPT_014_intelligent_multimedia_engine.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Ejecutando demostración institucional AMDA"

$DemoResources = @(
    [ordered]@{
        resource_id = "MED-001"
        entry_id = "LEX-001"
        media_type = "image"
        language = "und"
        uri = "media/images/LEX-001.webp"
        format = "webp"
        validated = $true
    },
    [ordered]@{
        resource_id = "MED-002"
        entry_id = "LEX-001"
        media_type = "audio_puinave"
        language = "pu"
        uri = "media/audio/LEX-001-pu.wav"
        format = "wav"
        validated = $true
    },
    [ordered]@{
        resource_id = "MED-003"
        entry_id = "LEX-001"
        media_type = "audio_spanish"
        language = "es"
        uri = "media/audio/LEX-001-es.wav"
        format = "wav"
        validated = $true
    },
    [ordered]@{
        resource_id = "MED-004"
        entry_id = "LEX-001"
        media_type = "audio_english_us"
        language = "en-US"
        uri = "media/audio/LEX-001-en.wav"
        format = "wav"
        validated = $true
    }
)

Write-Json `
    -Path $DemoRequestPath `
    -Value ([ordered]@{
        preload = $DemoResources
        operation = "build_oda"
        payload = [ordered]@{
            entry_id = "LEX-001"
        }
    })

Invoke-Checked "Construyendo ODA multimedia AMDA" {
    python -m sgoda.multimedia_engine.cli `
        --request-file "$DemoRequestPath" `
        --output "$DemoOutputPath"
}

$Demo = Get-Content `
    -LiteralPath $DemoOutputPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración SPT-014 no fue aprobada."
}

if (-not [bool]$Demo.data.complete) {
    throw "El ODA multimedia AMDA quedó incompleto."
}

if (@($Demo.data.missing_types).Count -ne 0) {
    throw "La demostración reportó recursos faltantes."
}

Write-Step "Generando evidencia y release"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json `
    -Path $EvidencePath `
    -Value ([ordered]@{
        increment_code = "SPT-014"
        version = "1.0.0"
        status = "implemented_and_tested"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        specific_tests = 18
        full_suite_executed = (-not $SkipFullSuite)
        demo_status = $Demo.status
        demo_entry_id = $Demo.data.entry_id
        demo_oda_complete = [bool]$Demo.data.complete
        demo_resource_count = @($Demo.data.resources).Count
        missing_types = @($Demo.data.missing_types)
        no_invention = [bool]$Demo.no_invention
        backup = $BackupDir
    })

foreach ($ReleaseFile in @(
    $ModelsPath,
    $ValidationPath,
    $RepositoryPath,
    $ManifestPath,
    $OdaPath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $SchemaPath,
    $InvokePath,
    $DemoRequestPath,
    $DemoOutputPath,
    $EvidencePath
)) {
    Require-File -Path $ReleaseFile
    Copy-Item `
        -LiteralPath $ReleaseFile `
        -Destination $ReleaseDir `
        -Force
}

foreach ($Document in $Docs.Keys) {
    Require-File -Path $Document
    Copy-Item `
        -LiteralPath $Document `
        -Destination $ReleaseDir `
        -Force
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SPT-014"
        version = "1.0.0"
        status = "implemented_and_tested"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
            Select-Object -ExpandProperty Name
        )
    })

Write-Step "Evaluando SPT-014 mediante SGD-114D"

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$ProjectRoot" `
    --increment "SPT-014" `
    --output-json "$PolicyJson" `
    --output-md "$PolicyMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114D no aprobó SPT-014."
}

Write-Step "Evaluando arquitectura nativa mediante SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$NativeJson" `
    --output-md "$NativeMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SPT-014."
}

Invoke-Checked "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Invoke-Checked "Regenerando SGD-116" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

if ($Publish) {
    Write-Step "Publicando mediante SPB-007"

    & (Join-Path `
        $ProjectRoot `
        "scripts\Invoke-SPB007-InstitutionalPublish.ps1") `
        -Publish `
        -CommitMessage (
            "feat(multimedia): implement SPT-014 intelligent multimedia engine"
        ) `
        -EvidenceCommitMessage (
            "chore(multimedia): publish SPT-014 evidence"
        )

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Write-Step "Resultado final"

Write-Host "SPT-014 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Motor Multimedia Inteligente: OPERATIVO." `
    -ForegroundColor Green
Write-Host "Asociación con SPT-013B: IMPLEMENTADA." `
    -ForegroundColor Green
Write-Host "Imágenes, audios y video: IMPLEMENTADOS." `
    -ForegroundColor Green
Write-Host "Validación multimedia: IMPLEMENTADA." `
    -ForegroundColor Green
Write-Host "Manifiestos JSON: IMPLEMENTADOS." `
    -ForegroundColor Green
Write-Host "Paquetes ODA multimedia: IMPLEMENTADOS." `
    -ForegroundColor Green
Write-Host "Pruebas específicas: 18 APROBADAS." `
    -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." `
        -ForegroundColor Green
}

Write-Host "Demostración AMDA: APROBADA." `
    -ForegroundColor Green
Write-Host "SGD-114D: APROBADO." -ForegroundColor Green
Write-Host "SGD-114E: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-014-v1.0.0" `
    -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" `
    -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" `
    -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." `
        -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host (
        "Publicación no solicitada. Reejecute el instalador " +
        "con -Publish después de revisar el resultado."
    ) -ForegroundColor Yellow
}
