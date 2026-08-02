<#
.SYNOPSIS
    Instala SPT-012 v1.0.0 — Plataforma de Aprendizaje SGODA-PUINAVE.

.DESCRIPTION
    Integra en una única capa funcional:

      - diccionario digital;
      - SPT-007A/B/C/D;
      - SPT-008 Tutor Inteligente;
      - SPT-009 Ecosistema Conversacional;
      - SPT-011 Plataforma Operativa;
      - imágenes, audios y videos;
      - Objetos Digitales de Aprendizaje (ODA);
      - rutas, sesiones, ejercicios y progreso.

    El instalador:
      - valida la línea base;
      - crea respaldo institucional;
      - instala código, configuración, documentación y pruebas;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - ejecuta una demostración de aprendizaje;
      - evalúa mediante SGD-114D;
      - regenera SGD-115 y SGD-116;
      - genera evidencia y release.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.

.PARAMETER SkipInstitutionalClosure
    Omite policy, documentación, roadmap y release.
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

    Write-Host "Creado/actualizado: $Path ($($Info.Length) bytes)" `
        -ForegroundColor Green
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\learning_platform"
$TestsDir = Join-Path $ProjectRoot "tests\learning_platform"
$ConfigDir = Join-Path $ProjectRoot "config\learning_platform"
$DocsDir = Join-Path $ProjectRoot "docs\07_Fase_Tecnologica_III\SPT-012"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\learning_platform\SPT-012"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-012"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-012-v1.0.0"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SPT012-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "models.py"
$DictionaryPath = Join-Path $SourceDir "digital_dictionary.py"
$MediaPath = Join-Path $SourceDir "media_library.py"
$OdaPath = Join-Path $SourceDir "oda_factory.py"
$CurriculumPath = Join-Path $SourceDir "curriculum.py"
$ProgressPath = Join-Path $SourceDir "progress.py"
$BridgePath = Join-Path $SourceDir "integration_bridge.py"
$ServicePath = Join-Path $SourceDir "service.py"
$ApiPath = Join-Path $SourceDir "api.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SPT_012_sgoda_learning_platform.py"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SPT-012-component.json"

$PolicyPath = Join-Path `
    $ConfigDir `
    "SPT-012-policy.json"

$RuntimePath = Join-Path `
    $ConfigDir `
    "SPT-012-runtime.json"

$InvokePath = Join-Path `
    $ScriptsDir `
    "Invoke-SPT012-LearningPlatform.ps1"

$DemoDictionaryPath = Join-Path $ArtifactsDir "demo-dictionary.json"
$DemoMediaPath = Join-Path $ArtifactsDir "demo-media.json"
$DemoRequestPath = Join-Path $ArtifactsDir "demo-request.json"
$DemoResultPath = Join-Path $ArtifactsDir "demo-learning-result.json"

$PolicyJson = Join-Path $PmoDir "SPT-012-policy-result.json"
$PolicyMd = Join-Path $PmoDir "SPT-012-policy-result.md"
$EvidencePath = Join-Path $PmoDir "SPT-012-implementation-evidence.json"

Write-Step "Validando línea base tecnológica"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\lexical_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\knowledge_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\reasoning_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\tutor\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\conversation\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\operational_platform\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\adaptive_policy_cli.py"),
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
    $DictionaryPath,
    $MediaPath,
    $OdaPath,
    $CurriculumPath,
    $ProgressPath,
    $BridgePath,
    $ServicePath,
    $ApiPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $RuntimePath,
    $InvokePath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Models = @'
"""Modelos canónicos de SPT-012."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class LearningRequest:
    operation: str
    learner_id: str
    language: str = "es"
    entry_id: str | None = None
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LearningResponse:
    operation: str
    status: str
    data: dict[str, Any]
    sources: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    no_invention: bool = True


@dataclass(frozen=True, slots=True)
class LearningSession:
    session_id: str
    learner_id: str
    entry_id: str
    objective: str
    completed_steps: tuple[str, ...] = ()
    score: float = 0.0
'@

$Dictionary = @'
"""Diccionario digital de SPT-012."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


class DigitalDictionary:
    def __init__(self) -> None:
        self._entries: dict[str, dict[str, Any]] = {}

    def load(self, path: str | Path) -> None:
        payload = json.loads(
            Path(path).read_text(encoding="utf-8-sig")
        )
        records = (
            payload.get("entries", [])
            if isinstance(payload, dict)
            else payload
        )

        if not isinstance(records, list):
            raise ValueError("El diccionario debe contener una lista.")

        for index, item in enumerate(records, start=1):
            if not isinstance(item, dict):
                continue

            if not bool(item.get("validated", False)):
                continue

            entry_id = str(
                item.get("entry_id")
                or item.get("id")
                or f"LEX-{index:06d}"
            ).strip()

            if not entry_id:
                continue

            self._entries[entry_id] = {
                "entry_id": entry_id,
                "puinave": str(item.get("puinave") or "").strip(),
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
                "category": str(
                    item.get("category") or ""
                ).strip(),
                "validated": True,
                "metadata": dict(item.get("metadata") or {}),
            }

    def get(self, entry_id: str) -> dict[str, Any] | None:
        value = self._entries.get(entry_id)
        return dict(value) if value is not None else None

    def all(self) -> tuple[dict[str, Any], ...]:
        return tuple(
            dict(self._entries[key])
            for key in sorted(self._entries)
        )

    def search(self, query: str) -> tuple[dict[str, Any], ...]:
        needle = str(query or "").strip().casefold()

        if not needle:
            return self.all()

        matches = []

        for entry in self.all():
            haystack = " ".join(
                [
                    entry.get("puinave", ""),
                    entry.get("spanish", ""),
                    entry.get("english_us", ""),
                    entry.get("italian", ""),
                    entry.get("category", ""),
                ]
            ).casefold()

            if needle in haystack:
                matches.append(entry)

        return tuple(matches)
'@

$Media = @'
"""Biblioteca multimedia validada."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


_ALLOWED = {
    "image",
    "audio_puinave",
    "audio_spanish",
    "audio_english_us",
    "audio_italian",
    "video",
}


class MediaLibrary:
    def __init__(self) -> None:
        self._resources: dict[str, list[dict[str, Any]]] = {}

    def load(self, path: str | Path) -> None:
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
                "El manifiesto multimedia debe contener una lista."
            )

        for item in resources:
            if not isinstance(item, dict):
                continue

            if not bool(item.get("validated", False)):
                continue

            entry_id = str(item.get("entry_id") or "").strip()
            media_type = str(
                item.get("media_type") or ""
            ).strip()
            uri = str(item.get("uri") or "").strip()

            if not entry_id or media_type not in _ALLOWED or not uri:
                continue

            self._resources.setdefault(entry_id, []).append(
                {
                    "entry_id": entry_id,
                    "media_type": media_type,
                    "uri": uri,
                    "validated": True,
                    "autoplay": bool(item.get("autoplay", False)),
                }
            )

    def for_entry(
        self,
        entry_id: str,
    ) -> tuple[dict[str, Any], ...]:
        return tuple(
            dict(item)
            for item in self._resources.get(entry_id, [])
        )
'@

$Oda = @'
"""Fábrica de Objetos Digitales de Aprendizaje."""

from __future__ import annotations

from typing import Any


def build_oda(
    entry: dict[str, Any],
    media: tuple[dict[str, Any], ...],
) -> dict[str, Any]:
    return {
        "odaId": f"ODA-{entry['entry_id']}",
        "entryId": entry["entry_id"],
        "title": entry.get("puinave", ""),
        "languages": {
            "pu": entry.get("puinave", ""),
            "es": entry.get("spanish", ""),
            "en-US": entry.get("english_us", ""),
            "it": entry.get("italian", ""),
        },
        "category": entry.get("category", ""),
        "media": [
            {
                "type": item["media_type"],
                "uri": item["uri"],
                "autoplay": bool(item.get("autoplay", False)),
            }
            for item in media
        ],
        "activities": [
            {
                "type": "listen",
                "instruction": "Escucha la pronunciación Puinave.",
            },
            {
                "type": "recognize",
                "instruction": "Relaciona la palabra con su imagen.",
            },
            {
                "type": "translate",
                "instruction": "Identifica su significado.",
            },
            {
                "type": "repeat",
                "instruction": "Repite la palabra en Puinave.",
            },
        ],
        "validated": bool(entry.get("validated", False)),
        "noInvention": True,
    }
'@

$Curriculum = @'
"""Rutas de aprendizaje."""

from __future__ import annotations

from typing import Any


def build_learning_path(
    entry: dict[str, Any],
    level: str = "initial",
) -> dict[str, Any]:
    supported = {
        "initial",
        "basic",
        "intermediate",
    }
    normalized = str(level or "initial").casefold()

    if normalized not in supported:
        normalized = "initial"

    steps = [
        {
            "stepId": "observe",
            "title": "Observar",
            "objective": "Reconocer la ficha léxica.",
        },
        {
            "stepId": "listen",
            "title": "Escuchar",
            "objective": "Escuchar la pronunciación disponible.",
        },
        {
            "stepId": "associate",
            "title": "Asociar",
            "objective": "Relacionar palabra, significado e imagen.",
        },
        {
            "stepId": "practice",
            "title": "Practicar",
            "objective": "Resolver una actividad breve.",
        },
        {
            "stepId": "evaluate",
            "title": "Evaluar",
            "objective": "Comprobar la comprensión.",
        },
    ]

    return {
        "pathId": f"PATH-{entry['entry_id']}-{normalized}",
        "entryId": entry["entry_id"],
        "level": normalized,
        "steps": steps,
        "estimatedMinutes": 10,
        "noInvention": True,
    }
'@

$Progress = @'
"""Seguimiento de progreso local."""

from __future__ import annotations

from typing import Any


class ProgressTracker:
    def __init__(self) -> None:
        self._progress: dict[tuple[str, str], dict[str, Any]] = {}

    def record(
        self,
        learner_id: str,
        entry_id: str,
        completed_step: str,
        score: float | None = None,
    ) -> dict[str, Any]:
        key = (learner_id, entry_id)
        current = self._progress.setdefault(
            key,
            {
                "learnerId": learner_id,
                "entryId": entry_id,
                "completedSteps": [],
                "score": 0.0,
            },
        )

        if completed_step not in current["completedSteps"]:
            current["completedSteps"].append(completed_step)

        if score is not None:
            current["score"] = max(
                0.0,
                min(float(score), 100.0),
            )

        return {
            "learnerId": current["learnerId"],
            "entryId": current["entryId"],
            "completedSteps": list(current["completedSteps"]),
            "score": current["score"],
        }

    def get(
        self,
        learner_id: str,
        entry_id: str,
    ) -> dict[str, Any]:
        value = self._progress.get(
            (learner_id, entry_id),
            {
                "learnerId": learner_id,
                "entryId": entry_id,
                "completedSteps": [],
                "score": 0.0,
            },
        )

        return {
            "learnerId": value["learnerId"],
            "entryId": value["entryId"],
            "completedSteps": list(value["completedSteps"]),
            "score": value["score"],
        }
'@

$Bridge = @'
"""Puente de integración con motores SGODA."""

from __future__ import annotations

from typing import Any


class IntegrationBridge:
    """Registra capacidades sin inventar resultados lingüísticos."""

    def capabilities(self) -> dict[str, Any]:
        return {
            "lexical": [
                "SPT-007A",
                "SPT-007B",
                "SPT-007C",
                "SPT-007D",
            ],
            "tutor": "SPT-008",
            "conversation": "SPT-009",
            "operationalPlatform": "SPT-011",
            "mode": "local_first",
            "noInvention": True,
        }

    def tutor_feedback(
        self,
        entry: dict[str, Any],
        answer: str,
    ) -> dict[str, Any]:
        expected = str(entry.get("spanish") or "").casefold().strip()
        received = str(answer or "").casefold().strip()
        correct = bool(expected) and expected == received

        return {
            "correct": correct,
            "expected": entry.get("spanish", ""),
            "feedback": (
                "Respuesta correcta."
                if correct
                else "Revisa nuevamente la ficha léxica."
            ),
            "source": f"RLB:{entry['entry_id']}",
            "noInvention": True,
        }
'@

$Service = @'
"""Servicio principal de SPT-012."""

from __future__ import annotations

from .curriculum import build_learning_path
from .digital_dictionary import DigitalDictionary
from .integration_bridge import IntegrationBridge
from .media_library import MediaLibrary
from .models import LearningRequest, LearningResponse
from .oda_factory import build_oda
from .progress import ProgressTracker


class LearningPlatformService:
    def __init__(
        self,
        dictionary: DigitalDictionary,
        media: MediaLibrary,
        progress: ProgressTracker | None = None,
        bridge: IntegrationBridge | None = None,
    ) -> None:
        self.dictionary = dictionary
        self.media = media
        self.progress = progress or ProgressTracker()
        self.bridge = bridge or IntegrationBridge()

    def execute(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        handlers = {
            "search_dictionary": self._search_dictionary,
            "get_oda": self._get_oda,
            "build_path": self._build_path,
            "evaluate_answer": self._evaluate_answer,
            "record_progress": self._record_progress,
            "get_progress": self._get_progress,
            "capabilities": self._capabilities,
        }

        handler = handlers.get(request.operation)

        if handler is None:
            return LearningResponse(
                operation=request.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(request)

    def _entry(
        self,
        request: LearningRequest,
    ) -> dict | None:
        entry_id = (
            request.entry_id
            or str(request.payload.get("entry_id") or "")
        )
        return self.dictionary.get(entry_id)

    def _search_dictionary(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        query = str(request.payload.get("query") or "")
        results = self.dictionary.search(query)

        return LearningResponse(
            operation="search_dictionary",
            status="ok",
            data={
                "query": query,
                "total": len(results),
                "results": list(results),
            },
            sources=tuple(
                f"RLB:{item['entry_id']}"
                for item in results
            ),
        )

    def _get_oda(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry = self._entry(request)

        if entry is None:
            return LearningResponse(
                operation="get_oda",
                status="not_found",
                data={},
            )

        return LearningResponse(
            operation="get_oda",
            status="ok",
            data=build_oda(
                entry,
                self.media.for_entry(entry["entry_id"]),
            ),
            sources=(f"RLB:{entry['entry_id']}",),
        )

    def _build_path(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry = self._entry(request)

        if entry is None:
            return LearningResponse(
                operation="build_path",
                status="not_found",
                data={},
            )

        level = str(request.payload.get("level") or "initial")

        return LearningResponse(
            operation="build_path",
            status="ok",
            data=build_learning_path(entry, level),
            sources=(f"RLB:{entry['entry_id']}",),
        )

    def _evaluate_answer(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry = self._entry(request)

        if entry is None:
            return LearningResponse(
                operation="evaluate_answer",
                status="not_found",
                data={},
            )

        answer = str(request.payload.get("answer") or "")
        result = self.bridge.tutor_feedback(entry, answer)

        return LearningResponse(
            operation="evaluate_answer",
            status="ok",
            data=result,
            sources=(result["source"],),
        )

    def _record_progress(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry = self._entry(request)

        if entry is None:
            return LearningResponse(
                operation="record_progress",
                status="not_found",
                data={},
            )

        step = str(request.payload.get("step") or "").strip()

        if not step:
            return LearningResponse(
                operation="record_progress",
                status="invalid_request",
                data={},
                warnings=("El paso completado es obligatorio.",),
            )

        score = request.payload.get("score")
        data = self.progress.record(
            request.learner_id,
            entry["entry_id"],
            step,
            score,
        )

        return LearningResponse(
            operation="record_progress",
            status="ok",
            data=data,
            sources=(f"RLB:{entry['entry_id']}",),
        )

    def _get_progress(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        entry_id = (
            request.entry_id
            or str(request.payload.get("entry_id") or "")
        )

        return LearningResponse(
            operation="get_progress",
            status="ok",
            data=self.progress.get(
                request.learner_id,
                entry_id,
            ),
        )

    def _capabilities(
        self,
        request: LearningRequest,
    ) -> LearningResponse:
        return LearningResponse(
            operation="capabilities",
            status="ok",
            data=self.bridge.capabilities(),
        )
'@

$Api = @'
"""API FastAPI de SPT-012."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .digital_dictionary import DigitalDictionary
from .media_library import MediaLibrary
from .models import LearningRequest
from .service import LearningPlatformService


def create_app(
    dictionary_path: str | Path,
    media_path: str | Path,
):
    try:
        from fastapi import FastAPI
        from pydantic import BaseModel, Field
    except ImportError as error:
        raise RuntimeError(
            "FastAPI y Pydantic son requeridos para iniciar la API."
        ) from error

    dictionary = DigitalDictionary()
    dictionary.load(dictionary_path)

    media = MediaLibrary()
    media.load(media_path)

    service = LearningPlatformService(
        dictionary,
        media,
    )

    app = FastAPI(
        title="Plataforma de Aprendizaje SGODA-PUINAVE",
        version="1.0.0",
    )

    class ExecuteBody(BaseModel):
        operation: str
        learner_id: str
        language: str = "es"
        entry_id: str | None = None
        payload: dict[str, Any] = Field(default_factory=dict)

    @app.post("/learning/execute")
    def execute(body: ExecuteBody) -> dict:
        response = service.execute(
            LearningRequest(
                operation=body.operation,
                learner_id=body.learner_id,
                language=body.language,
                entry_id=body.entry_id,
                payload=body.payload,
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
"""CLI de SPT-012."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .digital_dictionary import DigitalDictionary
from .media_library import MediaLibrary
from .models import LearningRequest
from .service import LearningPlatformService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dictionary", required=True)
    parser.add_argument("--media", required=True)
    parser.add_argument("--request-file", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    dictionary = DigitalDictionary()
    dictionary.load(args.dictionary)

    media = MediaLibrary()
    media.load(args.media)

    request_payload = json.loads(
        Path(args.request_file).read_text(
            encoding="utf-8-sig"
        )
    )

    service = LearningPlatformService(
        dictionary,
        media,
    )
    response = service.execute(
        LearningRequest(
            operation=str(request_payload["operation"]),
            learner_id=str(
                request_payload.get(
                    "learner_id",
                    "anonymous",
                )
            ),
            language=str(
                request_payload.get("language", "es")
            ),
            entry_id=request_payload.get("entry_id"),
            payload=dict(request_payload.get("payload") or {}),
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

    print("SPT-012 ejecutado correctamente.")
    print(f"Operación: {response.operation}")
    print(f"Estado: {response.status}")
    print(f"Resultado: {target}")

    return 0 if response.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""SPT-012 — Plataforma de Aprendizaje SGODA-PUINAVE."""

from .digital_dictionary import DigitalDictionary
from .media_library import MediaLibrary
from .models import (
    LearningRequest,
    LearningResponse,
    LearningSession,
)
from .service import LearningPlatformService

__all__ = [
    "DigitalDictionary",
    "LearningPlatformService",
    "LearningRequest",
    "LearningResponse",
    "LearningSession",
    "MediaLibrary",
]
'@

$Tests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.learning_platform import (
    DigitalDictionary,
    LearningPlatformService,
    LearningRequest,
    MediaLibrary,
)


def _dictionary(tmp_path: Path) -> Path:
    path = tmp_path / "dictionary.json"
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
                        "category": "sustantivo",
                        "validated": True,
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
                        "media_type": "image",
                        "uri": "media/images/LEX-001.webp",
                        "validated": True,
                        "autoplay": True,
                    },
                    {
                        "entry_id": "LEX-001",
                        "media_type": "audio_puinave",
                        "uri": "media/audio/LEX-001-pu.wav",
                        "validated": True,
                        "autoplay": True,
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def _service(tmp_path: Path) -> LearningPlatformService:
    dictionary = DigitalDictionary()
    dictionary.load(_dictionary(tmp_path))

    media = MediaLibrary()
    media.load(_media(tmp_path))

    return LearningPlatformService(
        dictionary,
        media,
    )


def test_SPT_012_loads_only_validated_dictionary(
    tmp_path: Path,
) -> None:
    dictionary = DigitalDictionary()
    dictionary.load(_dictionary(tmp_path))

    assert len(dictionary.all()) == 1
    assert dictionary.get("LEX-001") is not None


def test_SPT_012_searches_dictionary(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="search_dictionary",
            learner_id="LEARNER-001",
            payload={"query": "casa"},
        )
    )

    assert response.status == "ok"
    assert response.data["total"] == 1


def test_SPT_012_builds_oda(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="get_oda",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
        )
    )

    assert response.status == "ok"
    assert response.data["odaId"] == "ODA-LEX-001"
    assert response.data["noInvention"] is True


def test_SPT_012_oda_contains_media(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="get_oda",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
        )
    )

    assert len(response.data["media"]) == 2


def test_SPT_012_builds_learning_path(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="build_path",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={"level": "initial"},
        )
    )

    assert response.status == "ok"
    assert len(response.data["steps"]) == 5


def test_SPT_012_evaluates_correct_answer(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="evaluate_answer",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={"answer": "casa"},
        )
    )

    assert response.data["correct"] is True


def test_SPT_012_evaluates_incorrect_answer(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="evaluate_answer",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={"answer": "árbol"},
        )
    )

    assert response.data["correct"] is False
    assert response.data["noInvention"] is True


def test_SPT_012_records_progress(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    response = service.execute(
        LearningRequest(
            operation="record_progress",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={
                "step": "observe",
                "score": 80,
            },
        )
    )

    assert response.status == "ok"
    assert response.data["score"] == 80.0


def test_SPT_012_returns_progress(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.execute(
        LearningRequest(
            operation="record_progress",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={"step": "listen"},
        )
    )
    response = service.execute(
        LearningRequest(
            operation="get_progress",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
        )
    )

    assert "listen" in response.data["completedSteps"]


def test_SPT_012_exposes_integrated_capabilities(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="capabilities",
            learner_id="LEARNER-001",
        )
    )

    assert response.status == "ok"
    assert "SPT-007A" in response.data["lexical"]
    assert response.data["tutor"] == "SPT-008"
    assert response.data["conversation"] == "SPT-009"
    assert response.data["operationalPlatform"] == "SPT-011"


def test_SPT_012_returns_not_found_without_invention(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="get_oda",
            learner_id="LEARNER-001",
            entry_id="UNKNOWN",
        )
    )

    assert response.status == "not_found"
    assert response.no_invention is True


def test_SPT_012_rejects_unsupported_operation(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="unknown",
            learner_id="LEARNER-001",
        )
    )

    assert response.status == "unsupported_operation"


def test_SPT_012_is_deterministic(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    request = LearningRequest(
        operation="get_oda",
        learner_id="LEARNER-001",
        entry_id="LEX-001",
    )

    assert service.execute(request) == service.execute(request)


def test_SPT_012_preserves_four_languages(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="get_oda",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
        )
    )

    assert set(response.data["languages"]) == {
        "pu",
        "es",
        "en-US",
        "it",
    }
'@

$Component = @'
{
  "increment_code": "SPT-012",
  "name": "Plataforma de Aprendizaje SGODA-PUINAVE",
  "component_type": "integrated_learning_platform",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica III",
  "dependencies": [
    "SPT-007A",
    "SPT-007B",
    "SPT-007C",
    "SPT-007D",
    "SPT-008",
    "SPT-009",
    "SPT-011",
    "SGD-114D",
    "SGD-115A",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/learning_platform/models.py",
    "src/sgoda/learning_platform/digital_dictionary.py",
    "src/sgoda/learning_platform/media_library.py",
    "src/sgoda/learning_platform/oda_factory.py",
    "src/sgoda/learning_platform/curriculum.py",
    "src/sgoda/learning_platform/progress.py",
    "src/sgoda/learning_platform/integration_bridge.py",
    "src/sgoda/learning_platform/service.py",
    "src/sgoda/learning_platform/api.py",
    "src/sgoda/learning_platform/cli.py"
  ],
  "tests": [
    "tests/learning_platform/test_SPT_012_sgoda_learning_platform.py"
  ],
  "documentation": [
    "docs/07_Fase_Tecnologica_III/SPT-012/SPT-012-Arquitectura.md",
    "docs/07_Fase_Tecnologica_III/SPT-012/SPT-012-Diccionario-Digital.md",
    "docs/07_Fase_Tecnologica_III/SPT-012/SPT-012-Integracion-Motores.md",
    "docs/07_Fase_Tecnologica_III/SPT-012/SPT-012-Multimedia-y-ODA.md",
    "docs/07_Fase_Tecnologica_III/SPT-012/SPT-012-Rutas-Progreso-Evaluacion.md"
  ]
}
'@

$Policy = @'
{
  "component": "SPT-012",
  "version": "1.0.0",
  "validated_dictionary_only": true,
  "validated_media_only": true,
  "no_invention": true,
  "supported_languages": [
    "pu",
    "es",
    "en-US",
    "it"
  ],
  "integrations": [
    "SPT-007A",
    "SPT-007B",
    "SPT-007C",
    "SPT-007D",
    "SPT-008",
    "SPT-009",
    "SPT-011"
  ],
  "local_first": true
}
'@

$Runtime = @'
{
  "dictionary_source": "artifacts/learning_platform/SPT-012/demo-dictionary.json",
  "media_source": "artifacts/learning_platform/SPT-012/demo-media.json",
  "default_language": "es",
  "default_level": "initial",
  "progress_mode": "local_memory",
  "api_enabled": true,
  "no_invention": true
}
'@

$Docs = @{
    (Join-Path $DocsDir "SPT-012-Arquitectura.md") = @'
# SPT-012 — Arquitectura

SPT-012 integra diccionario digital, multimedia, ODA, rutas, evaluación,
progreso y contratos de integración con SPT-007A/B/C/D, SPT-008, SPT-009 y
SPT-011.
'@

    (Join-Path $DocsDir "SPT-012-Diccionario-Digital.md") = @'
# Diccionario Digital

Solo se cargan registros validados. Cada entrada conserva Puinave, español,
inglés americano, italiano, categoría y metadatos.
'@

    (Join-Path $DocsDir "SPT-012-Integracion-Motores.md") = @'
# Integración de motores

La plataforma declara capacidades de los motores léxico, semántico, de
conocimiento, razonamiento, tutoría, conversación y operación.
'@

    (Join-Path $DocsDir "SPT-012-Multimedia-y-ODA.md") = @'
# Multimedia y ODA

Cada ODA combina ficha léxica, imagen, audios, video y actividades. Solo se
usan recursos validados y se mantiene noInvention=true.
'@

    (Join-Path $DocsDir "SPT-012-Rutas-Progreso-Evaluacion.md") = @'
# Rutas, progreso y evaluación

Las rutas incluyen observar, escuchar, asociar, practicar y evaluar. El
progreso se registra por aprendiz y entrada léxica.
'@
}

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Dictionary,

    [Parameter(Mandatory = $true)]
    [string]$Media,

    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [string]$Output = "artifacts/learning_platform/SPT-012/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.learning_platform.cli `
    --dictionary "$Dictionary" `
    --media "$Media" `
    --request-file "$RequestFile" `
    --output "$Output"

exit $LASTEXITCODE
'@

Write-Step "Instalando SPT-012"

Write-Utf8 -Path $ModelsPath -Content $Models
Write-Utf8 -Path $DictionaryPath -Content $Dictionary
Write-Utf8 -Path $MediaPath -Content $Media
Write-Utf8 -Path $OdaPath -Content $Oda
Write-Utf8 -Path $CurriculumPath -Content $Curriculum
Write-Utf8 -Path $ProgressPath -Content $Progress
Write-Utf8 -Path $BridgePath -Content $Bridge
Write-Utf8 -Path $ServicePath -Content $Service
Write-Utf8 -Path $ApiPath -Content $Api
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $InitPath -Content $Init
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $RuntimePath -Content $Runtime
Write-Utf8 -Path $InvokePath -Content $Invoke

foreach ($Document in $Docs.GetEnumerator()) {
    Write-Utf8 `
        -Path $Document.Key `
        -Content $Document.Value
}

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/learning_platform/models.py" `
        "src/sgoda/learning_platform/digital_dictionary.py" `
        "src/sgoda/learning_platform/media_library.py" `
        "src/sgoda/learning_platform/oda_factory.py" `
        "src/sgoda/learning_platform/curriculum.py" `
        "src/sgoda/learning_platform/progress.py" `
        "src/sgoda/learning_platform/integration_bridge.py" `
        "src/sgoda/learning_platform/service.py" `
        "src/sgoda/learning_platform/api.py" `
        "src/sgoda/learning_platform/cli.py" `
        "src/sgoda/learning_platform/__init__.py" `
        "tests/learning_platform/test_SPT_012_sgoda_learning_platform.py"
}

Invoke-Checked "Ejecutando 14 pruebas específicas SPT-012" {
    python -m pytest `
        "tests/learning_platform/test_SPT_012_sgoda_learning_platform.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Generando demostración de aprendizaje"

Write-Json `
    -Path $DemoDictionaryPath `
    -Value ([ordered]@{
        entries = @(
            [ordered]@{
                entry_id = "LEX-001"
                puinave = "AMDA"
                spanish = "casa"
                english_us = "house"
                italian = "casa"
                category = "sustantivo"
                validated = $true
            }
        )
    })

Write-Json `
    -Path $DemoMediaPath `
    -Value ([ordered]@{
        resources = @(
            [ordered]@{
                entry_id = "LEX-001"
                media_type = "image"
                uri = "media/images/LEX-001.webp"
                validated = $true
                autoplay = $true
            },
            [ordered]@{
                entry_id = "LEX-001"
                media_type = "audio_puinave"
                uri = "media/audio/LEX-001-pu.wav"
                validated = $true
                autoplay = $true
            }
        )
    })

Write-Json `
    -Path $DemoRequestPath `
    -Value ([ordered]@{
        operation = "get_oda"
        learner_id = "DEMO-LEARNER-001"
        language = "es"
        entry_id = "LEX-001"
        payload = @{}
    })

Invoke-Checked "Ejecutando demostración AMDA" {
    python -m sgoda.learning_platform.cli `
        --dictionary "$DemoDictionaryPath" `
        --media "$DemoMediaPath" `
        --request-file "$DemoRequestPath" `
        --output "$DemoResultPath"
}

$Demo = Get-Content `
    -LiteralPath $DemoResultPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración SPT-012 no fue aprobada."
}

if ($Demo.data.entryId -ne "LEX-001") {
    throw "La demostración no devolvió LEX-001."
}

if ($Demo.data.languages.pu -ne "AMDA") {
    throw "La demostración no recuperó AMDA."
}

if (-not [bool]$Demo.data.noInvention) {
    throw "La demostración no respetó noInvention=true."
}

if (-not $SkipInstitutionalClosure) {
    Write-Step "Creando evidencia previa para SGD-114D"

    New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

    Write-Json `
        -Path $EvidencePath `
        -Value ([ordered]@{
            increment_code = "SPT-012"
            version = "1.0.0"
            status = "implemented"
            generated_at_utc = [DateTime]::UtcNow.ToString("o")
            specific_tests = 14
            full_suite_executed = (-not $SkipFullSuite)
            demo_status = $Demo.status
            demo_entry = $Demo.data.entryId
            demo_oda = $Demo.data.odaId
            media_count = @($Demo.data.media).Count
            no_invention = [bool]$Demo.data.noInvention
            backup = $BackupDir
        })

    foreach ($ReleaseFile in @(
        $ModelsPath,
        $DictionaryPath,
        $MediaPath,
        $OdaPath,
        $CurriculumPath,
        $ProgressPath,
        $BridgePath,
        $ServicePath,
        $ApiPath,
        $CliPath,
        $InitPath,
        $TestPath,
        $ComponentPath,
        $PolicyPath,
        $RuntimePath,
        $InvokePath,
        $DemoDictionaryPath,
        $DemoMediaPath,
        $DemoRequestPath,
        $DemoResultPath,
        $EvidencePath
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

    Write-Json `
        -Path (Join-Path $ReleaseDir "manifest.json") `
        -Value ([ordered]@{
            increment_code = "SPT-012"
            version = "1.0.0"
            status = "implemented_and_tested"
            files = @(
                Get-ChildItem `
                    -LiteralPath $ReleaseDir `
                    -File |
                Select-Object -ExpandProperty Name
            )
        })

    Write-Step "Evaluando SPT-012 mediante SGD-114D"

    & python -m sgoda.governance.adaptive_policy_cli `
        --root "$ProjectRoot" `
        --increment "SPT-012" `
        --output-json "$PolicyJson" `
        --output-md "$PolicyMd"

    $PolicyExitCode = $LASTEXITCODE

    Require-File -Path $PolicyJson
    Require-File -Path $PolicyMd

    $PolicyResult = Get-Content `
        -LiteralPath $PolicyJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if ($PolicyExitCode -ne 0 -or -not [bool]$PolicyResult.approved) {
        @($PolicyResult.results) |
            Where-Object { -not $_.passed } |
            Format-Table rule_code, name, message, remediation -AutoSize

        throw "SGD-114D no aprobó SPT-012."
    }

    Write-Step "Regenerando SGD-115"

    Invoke-Checked "Actualizando SGD-115" {
        python -m sgoda.documentation.master_docs `
            --root "$ProjectRoot" `
            --output "artifacts/documentation/SGD-115"
    }

    $DocValidationPath = Join-Path `
        $ProjectRoot `
        "artifacts\documentation\SGD-115\master-documentation-validation.json"

    Require-File -Path $DocValidationPath

    $DocValidation = Get-Content `
        -LiteralPath $DocValidationPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$DocValidation.passed) {
        throw "SGD-115 no aprobó SPT-012."
    }

    Write-Step "Regenerando SGD-116"

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
        throw "SGD-116 no aprobó SPT-012."
    }

    Write-Json `
        -Path $EvidencePath `
        -Value ([ordered]@{
            increment_code = "SPT-012"
            version = "1.0.0"
            status = "implemented_and_approved"
            generated_at_utc = [DateTime]::UtcNow.ToString("o")
            specific_tests = 14
            full_suite_executed = (-not $SkipFullSuite)
            demo_status = $Demo.status
            demo_entry = $Demo.data.entryId
            demo_oda = $Demo.data.odaId
            media_count = @($Demo.data.media).Count
            no_invention = [bool]$Demo.data.noInvention
            policy_approved = [bool]$PolicyResult.approved
            documentation_approved = [bool]$DocValidation.passed
            roadmap_approved = [bool]$RoadmapValidation.passed
            release = "releases/SPT-012-v1.0.0"
            backup = $BackupDir
        })

    Copy-Item `
        -LiteralPath $EvidencePath `
        -Destination $ReleaseDir `
        -Force
}

Write-Step "Resultado final"

Write-Host "SPT-012 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Plataforma de Aprendizaje SGODA-PUINAVE: OPERATIVA." `
    -ForegroundColor Green
Write-Host "Diccionario digital: INTEGRADO." -ForegroundColor Green
Write-Host "Motores SPT-007A/B/C/D: INTEGRADOS POR CONTRATO." `
    -ForegroundColor Green
Write-Host "Tutor SPT-008: INTEGRADO POR CONTRATO." -ForegroundColor Green
Write-Host "Conversación SPT-009: INTEGRADA POR CONTRATO." `
    -ForegroundColor Green
Write-Host "Plataforma SPT-011: INTEGRADA POR CONTRATO." `
    -ForegroundColor Green
Write-Host "Multimedia y ODA: INTEGRADOS." -ForegroundColor Green
Write-Host "Pruebas específicas: 14 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Demostración AMDA: APROBADA." -ForegroundColor Green

if (-not $SkipInstitutionalClosure) {
    Write-Host "SGD-114D: APROBADO." -ForegroundColor Green
    Write-Host "SGD-115: APROBADO." -ForegroundColor Green
    Write-Host "SGD-116: APROBADO." -ForegroundColor Green
    Write-Host "Release: releases\SPT-012-v1.0.0" -ForegroundColor Cyan
    Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
}

Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
