<#
.SYNOPSIS
    Instala SPT-016 v1.0.0 — Motor de Analítica del Aprendizaje.

.DESCRIPTION
    Implementa analítica educativa nativa para SGODA-PUINAVE.

    Incluye:
      - eventos de aprendizaje;
      - progreso y dominio por estudiante, competencia y entrada LEX;
      - analítica de evaluaciones SPT-015;
      - analítica de recursos multimedia SPT-014;
      - tendencias y alertas pedagógicas;
      - recomendaciones para SPT-008 y SPT-018;
      - paneles y exportación JSON;
      - demostración AMDA;
      - evidencia dinámica mediante SGD-114F;
      - suite completa;
      - SGD-114D, SGD-114E, SGD-115 y SGD-116;
      - release y publicación condicionada mediante SPB-007.
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

function Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path
    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )

    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path" -ForegroundColor Green
}

function Write-Json {
    param([string]$Path, [object]$Value)

    Write-Utf8 `
        -Path $Path `
        -Content (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
}

function Run {
    param([string]$Description, [scriptblock]$Action)

    Step $Description
    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

function Backup-File {
    param(
        [string]$Source,
        [string]$BackupDirectory,
        [string]$Root
    )

    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        $Relative = $Source.Replace($Root, "")
        $Relative = $Relative.TrimStart(
            [char[]]@([char]92, [char]47)
        )
        $Relative = $Relative.Replace(
            [string][char]92,
            "__"
        ).Replace("/", "__")

        Copy-Item `
            -LiteralPath $Source `
            -Destination (Join-Path $BackupDirectory $Relative) `
            -Force
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\learning_analytics"
$TestsDir = Join-Path $ProjectRoot "tests\learning_analytics"
$ConfigDir = Join-Path $ProjectRoot "config\learning_analytics"
$DocsDir = Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-016"
$ArtifactDir = Join-Path $ProjectRoot "artifacts\learning_analytics\SPT-016"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-016"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-016-v1.0.0"
$BackupDir = Join-Path $PmoDir ("backups\pre-SPT016-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "models.py"
$RepositoryPath = Join-Path $SourceDir "repository.py"
$MetricsPath = Join-Path $SourceDir "metrics.py"
$TrendsPath = Join-Path $SourceDir "trends.py"
$RecommendationsPath = Join-Path $SourceDir "recommendations.py"
$ServicePath = Join-Path $SourceDir "service.py"
$ExporterPath = Join-Path $SourceDir "exporter.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path $TestsDir "test_SPT_016_learning_analytics_engine.py"
$ComponentPath = Join-Path $ConfigDir "SPT-016-component.json"
$PolicyPath = Join-Path $ConfigDir "SPT-016-policy.json"
$SchemaPath = Join-Path $ConfigDir "SPT-016-event-schema.json"
$InvokePath = Join-Path $ProjectRoot "scripts\Invoke-SPT016-LearningAnalytics.ps1"

$SpecificXml = Join-Path $ReportsDir "SPT-016-specific.xml"
$SpecificJson = Join-Path $ReportsDir "SPT-016-specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "SPT-016-specific-summary.md"
$FullXml = Join-Path $ReportsDir "SPT-016-full-suite.xml"
$FullJson = Join-Path $ReportsDir "SPT-016-full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "SPT-016-full-suite-summary.md"

$DemoRequest = Join-Path $ArtifactDir "demo-request.json"
$DemoOutput = Join-Path $ArtifactDir "demo-output.json"
$EvidencePath = Join-Path $PmoDir "SPT-016-implementation-evidence.json"

$PolicyJson = Join-Path $PmoDir "SPT-016-policy-result.json"
$PolicyMd = Join-Path $PmoDir "SPT-016-policy-result.md"
$NativeJson = Join-Path $PmoDir "SPT-016-native-result.json"
$NativeMd = Join-Path $PmoDir "SPT-016-native-result.md"

Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\adaptive_assessment\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\multimedia_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\dictionary_manager\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1"),
    (Join-Path $ProjectRoot "src\sgoda\governance\adaptive_policy_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File $Required
}

Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null

foreach ($Affected in @(
    $ModelsPath,
    $RepositoryPath,
    $MetricsPath,
    $TrendsPath,
    $RecommendationsPath,
    $ServicePath,
    $ExporterPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $SchemaPath,
    $InvokePath
)) {
    Backup-File $Affected $BackupDir $ProjectRoot
}

$Models = @'
"""Modelos de analítica del aprendizaje."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class LearningEvent:
    event_id: str
    learner_id: str
    event_type: str
    entry_id: str = ""
    competency: str = ""
    score: float | None = None
    duration_seconds: float | None = None
    resource_id: str = ""
    timestamp: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class AnalyticsCommand:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class AnalyticsResult:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True
'@

$Repository = @'
"""Repositorio de eventos de aprendizaje."""

from __future__ import annotations

from .models import LearningEvent


class LearningEventRepository:
    def __init__(self) -> None:
        self._events: dict[str, LearningEvent] = {}

    def add(self, event: LearningEvent) -> LearningEvent:
        if event.event_id in self._events:
            raise ValueError(
                f"El evento ya existe: {event.event_id}"
            )

        self._events[event.event_id] = event
        return event

    def all(self) -> tuple[LearningEvent, ...]:
        return tuple(
            self._events[key]
            for key in sorted(self._events)
        )

    def for_learner(
        self,
        learner_id: str,
    ) -> tuple[LearningEvent, ...]:
        return tuple(
            event
            for event in self.all()
            if event.learner_id == learner_id
        )

    def for_entry(
        self,
        learner_id: str,
        entry_id: str,
    ) -> tuple[LearningEvent, ...]:
        return tuple(
            event
            for event in self.for_learner(learner_id)
            if event.entry_id == entry_id
        )

    def for_competency(
        self,
        learner_id: str,
        competency: str,
    ) -> tuple[LearningEvent, ...]:
        return tuple(
            event
            for event in self.for_learner(learner_id)
            if event.competency == competency
        )
'@

$Metrics = @'
"""Cálculo de métricas educativas."""

from __future__ import annotations

from .models import LearningEvent


def scored_events(
    events: tuple[LearningEvent, ...],
) -> tuple[LearningEvent, ...]:
    return tuple(
        event
        for event in events
        if event.score is not None
    )


def mastery(
    events: tuple[LearningEvent, ...],
) -> float:
    scored = scored_events(events)

    if not scored:
        return 0.0

    return round(
        sum(float(event.score) for event in scored)
        / len(scored),
        4,
    )


def engagement(
    events: tuple[LearningEvent, ...],
) -> dict[str, float | int]:
    durations = [
        float(event.duration_seconds)
        for event in events
        if event.duration_seconds is not None
    ]

    return {
        "events": len(events),
        "duration_seconds": round(sum(durations), 4),
        "resource_views": sum(
            1
            for event in events
            if event.event_type == "resource_viewed"
        ),
        "assessments": sum(
            1
            for event in events
            if event.event_type == "assessment_completed"
        ),
    }


def progress(
    events: tuple[LearningEvent, ...],
) -> dict[str, float | int]:
    return {
        "mastery": mastery(events),
        **engagement(events),
    }
'@

$Trends = @'
"""Tendencias y alertas pedagógicas."""

from __future__ import annotations

from .models import LearningEvent


def score_trend(
    events: tuple[LearningEvent, ...],
) -> str:
    scores = [
        float(event.score)
        for event in events
        if event.score is not None
    ]

    if len(scores) < 2:
        return "insufficient_data"

    if scores[-1] > scores[0]:
        return "improving"

    if scores[-1] < scores[0]:
        return "declining"

    return "stable"


def alerts(
    events: tuple[LearningEvent, ...],
) -> tuple[dict[str, str], ...]:
    scores = [
        float(event.score)
        for event in events
        if event.score is not None
    ]
    generated = []

    if len(scores) >= 2 and sum(scores) / len(scores) < 0.55:
        generated.append(
            {
                "code": "LOW_MASTERY",
                "severity": "warning",
                "message": "Dominio inferior al umbral institucional.",
            }
        )

    if not any(
        event.event_type == "resource_viewed"
        for event in events
    ):
        generated.append(
            {
                "code": "NO_MULTIMEDIA_USAGE",
                "severity": "info",
                "message": "No se registra uso de recursos multimedia.",
            }
        )

    return tuple(generated)
'@

$Recommendations = @'
"""Recomendaciones para tutor e IA pedagógica."""

from __future__ import annotations

from .metrics import mastery
from .models import LearningEvent
from .trends import score_trend


def recommend(
    events: tuple[LearningEvent, ...],
) -> dict[str, object]:
    level = mastery(events)
    trend = score_trend(events)

    if level >= 0.85:
        action = "advance"
        message = "Avanzar a actividades de mayor dificultad."
    elif level >= 0.55:
        action = "practice"
        message = "Continuar práctica guiada."
    else:
        action = "reinforce"
        message = "Reforzar léxico y multimedia antes de evaluar."

    return {
        "action": action,
        "message": message,
        "mastery": level,
        "trend": trend,
        "target_components": ["SPT-008", "SPT-018"],
        "no_invention": True,
    }
'@

$Exporter = @'
"""Exportación de paneles analíticos."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def export_dashboard(
    path: str | Path,
    payload: dict[str, Any],
) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )
'@

$Service = @'
"""Servicio principal de SPT-016."""

from __future__ import annotations

from typing import Any

from .exporter import export_dashboard
from .metrics import progress
from .models import (
    AnalyticsCommand,
    AnalyticsResult,
    LearningEvent,
)
from .recommendations import recommend
from .repository import LearningEventRepository
from .trends import alerts, score_trend


_ALLOWED_EVENT_TYPES = {
    "resource_viewed",
    "assessment_completed",
    "word_practiced",
    "lesson_completed",
    "conversation_completed",
}


def _event_from_payload(payload: dict[str, Any]) -> LearningEvent:
    score = payload.get("score")
    duration = payload.get("duration_seconds")

    return LearningEvent(
        event_id=str(payload.get("event_id") or "").strip(),
        learner_id=str(payload.get("learner_id") or "").strip(),
        event_type=str(payload.get("event_type") or "").strip(),
        entry_id=str(payload.get("entry_id") or "").strip(),
        competency=str(payload.get("competency") or "").strip(),
        score=float(score) if score is not None else None,
        duration_seconds=(
            float(duration)
            if duration is not None
            else None
        ),
        resource_id=str(payload.get("resource_id") or "").strip(),
        timestamp=str(payload.get("timestamp") or "").strip(),
        metadata=dict(payload.get("metadata") or {}),
    )


def _event_to_dict(event: LearningEvent) -> dict[str, Any]:
    return {
        "event_id": event.event_id,
        "learner_id": event.learner_id,
        "event_type": event.event_type,
        "entry_id": event.entry_id,
        "competency": event.competency,
        "score": event.score,
        "duration_seconds": event.duration_seconds,
        "resource_id": event.resource_id,
        "timestamp": event.timestamp,
        "metadata": dict(event.metadata),
    }


def _validate(payload: dict[str, Any]) -> tuple[str, ...]:
    errors = []
    event_id = str(payload.get("event_id") or "").strip()
    learner_id = str(payload.get("learner_id") or "").strip()
    event_type = str(payload.get("event_type") or "").strip()

    if not event_id.startswith("EVT-"):
        errors.append("event_id debe iniciar con EVT-.")

    if not learner_id:
        errors.append("learner_id es obligatorio.")

    if event_type not in _ALLOWED_EVENT_TYPES:
        errors.append("event_type no está permitido.")

    score = payload.get("score")
    if score is not None:
        try:
            value = float(score)
            if value < 0 or value > 1:
                errors.append("score debe estar entre 0 y 1.")
        except (TypeError, ValueError):
            errors.append("score debe ser numérico.")

    return tuple(errors)


class LearningAnalyticsEngine:
    def __init__(
        self,
        repository: LearningEventRepository | None = None,
    ) -> None:
        self.repository = repository or LearningEventRepository()

    def execute(
        self,
        command: AnalyticsCommand,
    ) -> AnalyticsResult:
        handlers = {
            "record_event": self._record_event,
            "learner_dashboard": self._learner_dashboard,
            "entry_analytics": self._entry_analytics,
            "competency_analytics": self._competency_analytics,
            "recommendation": self._recommendation,
            "export_dashboard": self._export_dashboard,
            "stats": self._stats,
        }

        handler = handlers.get(command.operation)

        if handler is None:
            return AnalyticsResult(
                operation=command.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(command.payload)

    def _record_event(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        errors = _validate(payload)

        if errors:
            return AnalyticsResult(
                operation="record_event",
                status="invalid_event",
                data={"errors": list(errors)},
                warnings=errors,
            )

        event = _event_from_payload(payload)

        try:
            self.repository.add(event)
        except ValueError as error:
            return AnalyticsResult(
                operation="record_event",
                status="duplicate_id",
                data={"event_id": event.event_id},
                warnings=(str(error),),
            )

        return AnalyticsResult(
            operation="record_event",
            status="ok",
            data=_event_to_dict(event),
        )

    def _dashboard_data(
        self,
        learner_id: str,
    ) -> dict[str, Any]:
        events = self.repository.for_learner(learner_id)

        return {
            "learner_id": learner_id,
            "progress": progress(events),
            "trend": score_trend(events),
            "alerts": list(alerts(events)),
            "recommendation": recommend(events),
            "events": [
                _event_to_dict(event)
                for event in events
            ],
        }

    def _learner_dashboard(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()

        return AnalyticsResult(
            operation="learner_dashboard",
            status="ok",
            data=self._dashboard_data(learner_id),
        )

    def _entry_analytics(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        entry_id = str(payload.get("entry_id") or "").strip()
        events = self.repository.for_entry(
            learner_id,
            entry_id,
        )

        return AnalyticsResult(
            operation="entry_analytics",
            status="ok",
            data={
                "learner_id": learner_id,
                "entry_id": entry_id,
                "progress": progress(events),
                "trend": score_trend(events),
                "alerts": list(alerts(events)),
            },
        )

    def _competency_analytics(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        competency = str(
            payload.get("competency") or ""
        ).strip()
        events = self.repository.for_competency(
            learner_id,
            competency,
        )

        return AnalyticsResult(
            operation="competency_analytics",
            status="ok",
            data={
                "learner_id": learner_id,
                "competency": competency,
                "progress": progress(events),
                "trend": score_trend(events),
                "alerts": list(alerts(events)),
            },
        )

    def _recommendation(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        events = self.repository.for_learner(learner_id)

        return AnalyticsResult(
            operation="recommendation",
            status="ok",
            data={
                "learner_id": learner_id,
                **recommend(events),
            },
        )

    def _export_dashboard(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        path = str(payload.get("path") or "").strip()
        dashboard = self._dashboard_data(learner_id)
        export_dashboard(
            path,
            {
                "schema": "SPT-016",
                "version": "1.0.0",
                "dashboard": dashboard,
            },
        )

        return AnalyticsResult(
            operation="export_dashboard",
            status="ok",
            data={
                "learner_id": learner_id,
                "path": path,
            },
        )

    def _stats(
        self,
        payload: dict[str, Any],
    ) -> AnalyticsResult:
        events = self.repository.all()

        return AnalyticsResult(
            operation="stats",
            status="ok",
            data={
                "events": len(events),
                "learners": len(
                    {event.learner_id for event in events}
                ),
                "entries": len(
                    {
                        event.entry_id
                        for event in events
                        if event.entry_id
                    }
                ),
                "competencies": len(
                    {
                        event.competency
                        for event in events
                        if event.competency
                    }
                ),
            },
        )
'@

$Cli = @'
"""CLI de SPT-016."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import AnalyticsCommand
from .service import LearningAnalyticsEngine


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

    engine = LearningAnalyticsEngine()

    for event in request.get("events", []):
        engine.execute(
            AnalyticsCommand(
                operation="record_event",
                payload=dict(event),
            )
        )

    response = engine.execute(
        AnalyticsCommand(
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

    print("SPT-016 ejecutado correctamente.")
    print(f"Operación: {response.operation}")
    print(f"Estado: {response.status}")
    print(f"Resultado: {target}")

    return 0 if response.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""SPT-016 — Motor de Analítica del Aprendizaje."""

from .metrics import engagement, mastery, progress
from .models import (
    AnalyticsCommand,
    AnalyticsResult,
    LearningEvent,
)
from .recommendations import recommend
from .repository import LearningEventRepository
from .service import LearningAnalyticsEngine
from .trends import alerts, score_trend

__all__ = [
    "AnalyticsCommand",
    "AnalyticsResult",
    "LearningAnalyticsEngine",
    "LearningEvent",
    "LearningEventRepository",
    "alerts",
    "engagement",
    "mastery",
    "progress",
    "recommend",
    "score_trend",
]
'@

$Tests = @'
from __future__ import annotations

from pathlib import Path

from sgoda.learning_analytics import (
    AnalyticsCommand,
    LearningAnalyticsEngine,
    LearningEvent,
    alerts,
    mastery,
    progress,
    recommend,
    score_trend,
)


def _event(
    event_id: str = "EVT-001",
    event_type: str = "assessment_completed",
    score: float | None = 1.0,
    duration: float | None = 30.0,
) -> dict:
    return {
        "event_id": event_id,
        "learner_id": "LEARNER-001",
        "event_type": event_type,
        "entry_id": "LEX-001",
        "competency": "vocabulary",
        "score": score,
        "duration_seconds": duration,
        "resource_id": "MED-001",
        "timestamp": "2026-08-02T22:00:00-05:00",
    }


def test_registers_event() -> None:
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    assert result.status == "ok"


def test_rejects_invalid_event_id() -> None:
    payload = _event()
    payload["event_id"] = "BAD"
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=payload,
        )
    )
    assert result.status == "invalid_event"


def test_rejects_missing_learner() -> None:
    payload = _event()
    payload["learner_id"] = ""
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=payload,
        )
    )
    assert result.status == "invalid_event"


def test_rejects_invalid_type() -> None:
    payload = _event()
    payload["event_type"] = "other"
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=payload,
        )
    )
    assert result.status == "invalid_event"


def test_rejects_invalid_score() -> None:
    payload = _event()
    payload["score"] = 2
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(
            operation="record_event",
            payload=payload,
        )
    )
    assert result.status == "invalid_event"


def test_detects_duplicate() -> None:
    engine = LearningAnalyticsEngine()
    command = AnalyticsCommand(
        operation="record_event",
        payload=_event(),
    )
    engine.execute(command)
    assert engine.execute(command).status == "duplicate_id"


def test_mastery_without_events() -> None:
    assert mastery(()) == 0.0


def test_mastery_average() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=1.0),
        LearningEvent("2", "L", "assessment_completed", score=0.5),
    )
    assert mastery(events) == 0.75


def test_progress_counts_events() -> None:
    events = (
        LearningEvent(
            "1",
            "L",
            "resource_viewed",
            duration_seconds=10,
        ),
    )
    assert progress(events)["events"] == 1
    assert progress(events)["duration_seconds"] == 10


def test_trend_improving() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=0.2),
        LearningEvent("2", "L", "assessment_completed", score=0.8),
    )
    assert score_trend(events) == "improving"


def test_trend_declining() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=0.8),
        LearningEvent("2", "L", "assessment_completed", score=0.2),
    )
    assert score_trend(events) == "declining"


def test_alerts_low_mastery() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=0.2),
        LearningEvent("2", "L", "assessment_completed", score=0.4),
    )
    assert any(
        item["code"] == "LOW_MASTERY"
        for item in alerts(events)
    )


def test_recommend_reinforcement() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=0.2),
    )
    assert recommend(events)["action"] == "reinforce"


def test_recommend_advance() -> None:
    events = (
        LearningEvent("1", "L", "assessment_completed", score=1.0),
    )
    assert recommend(events)["action"] == "advance"


def test_dashboard() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(
            operation="learner_dashboard",
            payload={"learner_id": "LEARNER-001"},
        )
    )
    assert result.status == "ok"
    assert result.data["progress"]["mastery"] == 1.0


def test_entry_analytics() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(
            operation="entry_analytics",
            payload={
                "learner_id": "LEARNER-001",
                "entry_id": "LEX-001",
            },
        )
    )
    assert result.data["entry_id"] == "LEX-001"


def test_competency_analytics() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(
            operation="competency_analytics",
            payload={
                "learner_id": "LEARNER-001",
                "competency": "vocabulary",
            },
        )
    )
    assert result.data["competency"] == "vocabulary"


def test_recommendation_operation() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(
            operation="recommendation",
            payload={"learner_id": "LEARNER-001"},
        )
    )
    assert result.data["action"] == "advance"


def test_export_dashboard(tmp_path: Path) -> None:
    target = tmp_path / "dashboard.json"
    engine = LearningAnalyticsEngine()
    result = engine.execute(
        AnalyticsCommand(
            operation="export_dashboard",
            payload={
                "learner_id": "LEARNER-001",
                "path": str(target),
            },
        )
    )
    assert result.status == "ok"
    assert target.exists()


def test_stats() -> None:
    engine = LearningAnalyticsEngine()
    engine.execute(
        AnalyticsCommand(
            operation="record_event",
            payload=_event(),
        )
    )
    result = engine.execute(
        AnalyticsCommand(operation="stats")
    )
    assert result.data["events"] == 1


def test_no_invention() -> None:
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(operation="stats")
    )
    assert result.no_invention is True


def test_unknown_operation() -> None:
    result = LearningAnalyticsEngine().execute(
        AnalyticsCommand(operation="unknown")
    )
    assert result.status == "unsupported_operation"
'@

$Component = @'
{
  "increment_code": "SPT-016",
  "name": "Motor de Analítica del Aprendizaje",
  "component_type": "learning_analytics_engine",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica IV",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "SPT-013A",
    "SPT-013B",
    "SPT-014",
    "SPT-015",
    "SPT-008",
    "SPT-012",
    "SGD-114F",
    "SGD-114D",
    "SGD-114E",
    "SGD-115A",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/learning_analytics/models.py",
    "src/sgoda/learning_analytics/repository.py",
    "src/sgoda/learning_analytics/metrics.py",
    "src/sgoda/learning_analytics/trends.py",
    "src/sgoda/learning_analytics/recommendations.py",
    "src/sgoda/learning_analytics/exporter.py",
    "src/sgoda/learning_analytics/service.py",
    "src/sgoda/learning_analytics/cli.py"
  ],
  "tests": [
    "tests/learning_analytics/test_SPT_016_learning_analytics_engine.py"
  ],
  "documentation": [
    "docs/08_Fase_Tecnologica_IV/SPT-016/SPT-016-Arquitectura.md",
    "docs/08_Fase_Tecnologica_IV/SPT-016/SPT-016-Metricas.md",
    "docs/08_Fase_Tecnologica_IV/SPT-016/SPT-016-Eventos-SPA.md"
  ]
}
'@

$Policy = @'
{
  "component": "SPT-016",
  "version": "1.0.0",
  "source_of_test_truth": "SGD-114F",
  "no_manual_test_counts": true,
  "no_invention": true,
  "local_first": true,
  "free_open_technology": true,
  "mandatory_proprietary_dependencies": [],
  "event_types": [
    "resource_viewed",
    "assessment_completed",
    "word_practiced",
    "lesson_completed",
    "conversation_completed"
  ],
  "spa_ready_events": [
    "analytics.event.recorded",
    "analytics.progress.updated",
    "analytics.alert.generated",
    "analytics.recommendation.generated"
  ]
}
'@

$Schema = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SPT-016 Learning Event",
  "type": "object",
  "required": [
    "event_id",
    "learner_id",
    "event_type"
  ],
  "properties": {
    "event_id": {
      "type": "string",
      "pattern": "^EVT-"
    },
    "learner_id": {
      "type": "string",
      "minLength": 1
    },
    "event_type": {
      "type": "string"
    },
    "score": {
      "type": ["number", "null"],
      "minimum": 0,
      "maximum": 1
    }
  }
}
'@

$Docs = @{
    (Join-Path $DocsDir "SPT-016-Arquitectura.md") = @'
# SPT-016 — Arquitectura

SPT-016 recibe eventos de SPT-012, SPT-013B, SPT-014 y SPT-015. Calcula
progreso, dominio, participación, tendencias, alertas y recomendaciones para
SPT-008 y SPT-018.
'@

    (Join-Path $DocsDir "SPT-016-Metricas.md") = @'
# SPT-016 — Métricas

El motor registra dominio, cantidad de eventos, duración, uso multimedia,
evaluaciones, tendencia y alertas. Todos los resultados derivan de eventos
reales y mantienen `no_invention=true`.
'@

    (Join-Path $DocsDir "SPT-016-Eventos-SPA.md") = @'
# SPT-016 — Preparación para SPA

SPT-016 queda preparado para emitir:

- analytics.event.recorded
- analytics.progress.updated
- analytics.alert.generated
- analytics.recommendation.generated

La automatización SPA se implementará después del cierre de las fases IV y V.
'@
}

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [string]$Output = "artifacts/learning_analytics/SPT-016/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.learning_analytics.cli `
    --request-file "$RequestFile" `
    --output "$Output"

exit $LASTEXITCODE
'@

Step "Instalando SPT-016"

Write-Utf8 $ModelsPath $Models
Write-Utf8 $RepositoryPath $Repository
Write-Utf8 $MetricsPath $Metrics
Write-Utf8 $TrendsPath $Trends
Write-Utf8 $RecommendationsPath $Recommendations
Write-Utf8 $ExporterPath $Exporter
Write-Utf8 $ServicePath $Service
Write-Utf8 $CliPath $Cli
Write-Utf8 $InitPath $Init
Write-Utf8 $TestPath $Tests
Write-Utf8 $ComponentPath $Component
Write-Utf8 $PolicyPath $Policy
Write-Utf8 $SchemaPath $Schema
Write-Utf8 $InvokePath $Invoke

foreach ($Document in $Docs.GetEnumerator()) {
    Write-Utf8 $Document.Key $Document.Value
}

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/learning_analytics/models.py" `
        "src/sgoda/learning_analytics/repository.py" `
        "src/sgoda/learning_analytics/metrics.py" `
        "src/sgoda/learning_analytics/trends.py" `
        "src/sgoda/learning_analytics/recommendations.py" `
        "src/sgoda/learning_analytics/exporter.py" `
        "src/sgoda/learning_analytics/service.py" `
        "src/sgoda/learning_analytics/cli.py" `
        "src/sgoda/learning_analytics/__init__.py" `
        "tests/learning_analytics/test_SPT_016_learning_analytics_engine.py"
}

Run "Ejecutando pruebas específicas mediante SGD-114F" {
    & (Join-Path $ProjectRoot "scripts\Invoke-InstitutionalPytest.ps1") `
        -Component "SPT-016" `
        -TestPath "tests/learning_analytics/test_SPT_016_learning_analytics_engine.py" `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific" `
        -EvidencePath "$EvidencePath" `
        -EvidenceKey "specific_tests"
}

$SpecificSummary = Get-Content `
    -LiteralPath $SpecificJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$SpecificSummary.approved) {
    throw "Las pruebas específicas SPT-016 no fueron aprobadas."
}

if (-not $SkipFullSuite) {
    Run "Ejecutando suite completa con evidencia JUnit" {
        python -m pytest `
            --junitxml="$FullXml"
    }

    Run "Sincronizando suite completa mediante SGD-114F" {
        python -m sgoda.governance.test_evidence.cli `
            --junit "$FullXml" `
            --component "SGODA-PUINAVE" `
            --scope "full_suite" `
            --output-json "$FullJson" `
            --output-md "$FullMd" `
            --evidence "$EvidencePath" `
            --evidence-key "full_suite"
    }

    $FullSummary = Get-Content `
        -LiteralPath $FullJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$FullSummary.approved) {
        throw "La suite completa no fue aprobada."
    }
}

Step "Ejecutando demostración institucional AMDA"

Write-Json `
    -Path $DemoRequest `
    -Value ([ordered]@{
        events = @(
            [ordered]@{
                event_id = "EVT-001"
                learner_id = "LEARNER-001"
                event_type = "resource_viewed"
                entry_id = "LEX-001"
                competency = "vocabulary"
                duration_seconds = 45
                resource_id = "MED-001"
                timestamp = "2026-08-02T22:00:00-05:00"
            },
            [ordered]@{
                event_id = "EVT-002"
                learner_id = "LEARNER-001"
                event_type = "assessment_completed"
                entry_id = "LEX-001"
                competency = "vocabulary"
                score = 0.5
                duration_seconds = 20
                timestamp = "2026-08-02T22:05:00-05:00"
            },
            [ordered]@{
                event_id = "EVT-003"
                learner_id = "LEARNER-001"
                event_type = "assessment_completed"
                entry_id = "LEX-001"
                competency = "vocabulary"
                score = 1.0
                duration_seconds = 15
                timestamp = "2026-08-02T22:10:00-05:00"
            }
        )
        operation = "learner_dashboard"
        payload = [ordered]@{
            learner_id = "LEARNER-001"
        }
    })

Run "Generando panel analítico AMDA" {
    python -m sgoda.learning_analytics.cli `
        --request-file "$DemoRequest" `
        --output "$DemoOutput"
}

$Demo = Get-Content `
    -LiteralPath $DemoOutput `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración SPT-016 no fue aprobada."
}

if ([double]$Demo.data.progress.mastery -ne 0.75) {
    throw "El dominio analítico esperado para AMDA no fue 0.75."
}

if ($Demo.data.trend -ne "improving") {
    throw "La tendencia esperada para AMDA no fue improving."
}

Step "Generando evidencia y release"

$Evidence = Get-Content `
    -LiteralPath $EvidencePath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$Evidence.increment_code = "SPT-016"
$Evidence.version = "1.0.0"
$Evidence.status = "implemented_and_tested"
$Evidence.generated_at_utc = [DateTime]::UtcNow.ToString("o")
$Evidence.demo = [ordered]@{
    status = $Demo.status
    learner_id = $Demo.data.learner_id
    mastery = $Demo.data.progress.mastery
    trend = $Demo.data.trend
    recommendation = $Demo.data.recommendation.action
}
$Evidence.source_of_test_truth = "SGD-114F / pytest JUnit XML"
$Evidence.backup = $BackupDir

Write-Json $EvidencePath $Evidence

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

foreach ($ReleaseFile in @(
    $ModelsPath,
    $RepositoryPath,
    $MetricsPath,
    $TrendsPath,
    $RecommendationsPath,
    $ExporterPath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $SchemaPath,
    $InvokePath,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $DemoRequest,
    $DemoOutput,
    $EvidencePath
)) {
    Require-File $ReleaseFile
    Copy-Item -LiteralPath $ReleaseFile -Destination $ReleaseDir -Force
}

if (-not $SkipFullSuite) {
    foreach ($File in @($FullXml, $FullJson, $FullMd)) {
        Require-File $File
        Copy-Item -LiteralPath $File -Destination $ReleaseDir -Force
    }
}

foreach ($Document in $Docs.Keys) {
    Require-File $Document
    Copy-Item -LiteralPath $Document -Destination $ReleaseDir -Force
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SPT-016"
        version = "1.0.0"
        status = "implemented_and_tested"
        files = @(
            Get-ChildItem -LiteralPath $ReleaseDir -File |
                Select-Object -ExpandProperty Name
        )
    })

Step "Evaluando SPT-016 mediante SGD-114D"

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$ProjectRoot" `
    --increment "SPT-016" `
    --output-json "$PolicyJson" `
    --output-md "$PolicyMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114D no aprobó SPT-016."
}

Step "Evaluando arquitectura nativa mediante SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$NativeJson" `
    --output-md "$NativeMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SPT-016."
}

Run "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Run "Regenerando SGD-116" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

if ($Publish) {
    Step "Publicando mediante SPB-007"

    & (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1") `
        -Publish `
        -CommitMessage "feat(analytics): implement SPT-016 learning analytics engine" `
        -EvidenceCommitMessage "chore(analytics): publish SPT-016 synchronized evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SPT-016 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Motor de Analítica del Aprendizaje: OPERATIVO." -ForegroundColor Green
Write-Host "Eventos de aprendizaje: IMPLEMENTADOS." -ForegroundColor Green
Write-Host "Progreso y dominio: IMPLEMENTADOS." -ForegroundColor Green
Write-Host "Tendencias y alertas: IMPLEMENTADAS." -ForegroundColor Green
Write-Host "Recomendaciones pedagógicas: IMPLEMENTADAS." -ForegroundColor Green
Write-Host "Preparación para SPA: IMPLEMENTADA." -ForegroundColor Green
Write-Host (
    "Pruebas específicas sincronizadas: " +
    "$($SpecificSummary.passed)/$($SpecificSummary.executed) APROBADAS."
) -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host (
        "Suite completa sincronizada: " +
        "$($FullSummary.passed)/$($FullSummary.executed) APROBADAS."
    ) -ForegroundColor Green
}

Write-Host "Demostración AMDA: APROBADA." -ForegroundColor Green
Write-Host "SGD-114D: APROBADO." -ForegroundColor Green
Write-Host "SGD-114E: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-016-v1.0.0" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Publicación no solicitada. Reejecute con -Publish." `
        -ForegroundColor Yellow
}
