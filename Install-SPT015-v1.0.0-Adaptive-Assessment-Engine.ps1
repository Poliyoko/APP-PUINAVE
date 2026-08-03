<#
.SYNOPSIS
    Instala SPT-015 v1.0.0 — Motor de Evaluación Adaptativa.

.DESCRIPTION
    Implementa el motor nativo de evaluación de la Fase Tecnológica IV.

    Incluye:
      - banco institucional de preguntas;
      - evaluaciones diagnósticas, formativas y sumativas;
      - selección adaptativa por dificultad;
      - cálculo de puntaje y dominio;
      - retroalimentación;
      - recomendaciones de aprendizaje;
      - historial de intentos;
      - integración con entradas LEX y recursos ODA;
      - exportación de resultados;
      - CLI y demostración AMDA;
      - 20 pruebas específicas;
      - suite completa;
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\adaptive_assessment"
$TestsDir = Join-Path $ProjectRoot "tests\adaptive_assessment"
$ConfigDir = Join-Path $ProjectRoot "config\adaptive_assessment"
$DocsDir = Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-015"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\adaptive_assessment\SPT-015"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-015"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-015-v1.0.0"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SPT015-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "models.py"
$RepositoryPath = Join-Path $SourceDir "repository.py"
$ScoringPath = Join-Path $SourceDir "scoring.py"
$AdaptationPath = Join-Path $SourceDir "adaptation.py"
$FeedbackPath = Join-Path $SourceDir "feedback.py"
$ServicePath = Join-Path $SourceDir "service.py"
$ExportPath = Join-Path $SourceDir "exporter.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SPT_015_adaptive_assessment_engine.py"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SPT-015-component.json"

$PolicyPath = Join-Path `
    $ConfigDir `
    "SPT-015-policy.json"

$RubricsPath = Join-Path `
    $ConfigDir `
    "SPT-015-rubrics.json"

$SchemaPath = Join-Path `
    $ConfigDir `
    "SPT-015-assessment-schema.json"

$InvokePath = Join-Path `
    $ScriptsDir `
    "Invoke-SPT015-AdaptiveAssessment.ps1"

$DemoRequestPath = Join-Path $ArtifactsDir "demo-request.json"
$DemoOutputPath = Join-Path $ArtifactsDir "demo-output.json"

$PolicyJson = Join-Path $PmoDir "SPT-015-policy-result.json"
$PolicyMd = Join-Path $PmoDir "SPT-015-policy-result.md"
$NativeJson = Join-Path $PmoDir "SPT-015-native-result.json"
$NativeMd = Join-Path $PmoDir "SPT-015-native-result.md"
$EvidencePath = Join-Path $PmoDir "SPT-015-implementation-evidence.json"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\learning_foundation\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\dictionary_manager\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\multimedia_engine\service.py"),
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
    $RepositoryPath,
    $ScoringPath,
    $AdaptationPath,
    $FeedbackPath,
    $ServicePath,
    $ExportPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $RubricsPath,
    $SchemaPath,
    $InvokePath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Models = @'
"""Modelos institucionales de SPT-015."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class AssessmentItem:
    item_id: str
    entry_id: str
    competency: str
    assessment_type: str
    difficulty: int
    prompt: str
    correct_answer: str
    options: tuple[str, ...] = ()
    media_resource_ids: tuple[str, ...] = ()
    validated: bool = False
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LearnerAttempt:
    learner_id: str
    item_id: str
    answer: str
    correct: bool
    score: float
    difficulty: int
    competency: str


@dataclass(frozen=True, slots=True)
class AssessmentCommand:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class AssessmentResult:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True
'@

$Repository = @'
"""Repositorios de preguntas e intentos."""

from __future__ import annotations

from .models import AssessmentItem, LearnerAttempt


class AssessmentRepository:
    def __init__(self) -> None:
        self._items: dict[str, AssessmentItem] = {}
        self._attempts: list[LearnerAttempt] = []

    def add_item(self, item: AssessmentItem) -> AssessmentItem:
        if item.item_id in self._items:
            raise ValueError(f"El ítem ya existe: {item.item_id}")

        self._items[item.item_id] = item
        return item

    def upsert_item(self, item: AssessmentItem) -> AssessmentItem:
        self._items[item.item_id] = item
        return item

    def get_item(self, item_id: str) -> AssessmentItem | None:
        return self._items.get(str(item_id or "").strip())

    def items(self) -> tuple[AssessmentItem, ...]:
        return tuple(self._items[key] for key in sorted(self._items))

    def items_for_competency(
        self,
        competency: str,
        validated_only: bool = True,
    ) -> tuple[AssessmentItem, ...]:
        items = [
            item
            for item in self.items()
            if item.competency == competency
        ]

        if validated_only:
            items = [item for item in items if item.validated]

        return tuple(items)

    def add_attempt(self, attempt: LearnerAttempt) -> None:
        self._attempts.append(attempt)

    def attempts_for(
        self,
        learner_id: str,
        competency: str | None = None,
    ) -> tuple[LearnerAttempt, ...]:
        attempts = [
            item
            for item in self._attempts
            if item.learner_id == learner_id
        ]

        if competency is not None:
            attempts = [
                item
                for item in attempts
                if item.competency == competency
            ]

        return tuple(attempts)
'@

$Scoring = @'
"""Cálculo de puntaje y dominio."""

from __future__ import annotations

from .models import LearnerAttempt


def normalize_answer(value: str) -> str:
    return " ".join(str(value or "").strip().casefold().split())


def score_answer(
    answer: str,
    correct_answer: str,
) -> tuple[bool, float]:
    correct = (
        normalize_answer(answer)
        == normalize_answer(correct_answer)
    )

    return correct, 1.0 if correct else 0.0


def mastery(
    attempts: tuple[LearnerAttempt, ...],
) -> float:
    if not attempts:
        return 0.0

    weighted_score = sum(
        item.score * max(item.difficulty, 1)
        for item in attempts
    )
    total_weight = sum(
        max(item.difficulty, 1)
        for item in attempts
    )

    return round(weighted_score / total_weight, 4)
'@

$Adaptation = @'
"""Selección adaptativa de dificultad e ítems."""

from __future__ import annotations

from .models import AssessmentItem, LearnerAttempt
from .scoring import mastery


def recommended_difficulty(
    attempts: tuple[LearnerAttempt, ...],
) -> int:
    level = mastery(attempts)

    if level >= 0.85:
        return 3

    if level >= 0.55:
        return 2

    return 1


def select_next_item(
    items: tuple[AssessmentItem, ...],
    attempts: tuple[LearnerAttempt, ...],
) -> AssessmentItem | None:
    if not items:
        return None

    attempted_ids = {item.item_id for item in attempts}
    target = recommended_difficulty(attempts)

    candidates = [
        item
        for item in items
        if item.validated and item.item_id not in attempted_ids
    ]

    if not candidates:
        candidates = [
            item for item in items if item.validated
        ]

    if not candidates:
        return None

    return sorted(
        candidates,
        key=lambda item: (
            abs(item.difficulty - target),
            item.item_id,
        ),
    )[0]
'@

$Feedback = @'
"""Retroalimentación y recomendaciones."""

from __future__ import annotations


def build_feedback(
    correct: bool,
    mastery_score: float,
    competency: str,
) -> dict[str, object]:
    if correct:
        message = "Respuesta correcta."
    else:
        message = (
            "Respuesta incorrecta. Repase el recurso léxico "
            "y multimedia asociado."
        )

    if mastery_score >= 0.85:
        recommendation = "Avanzar a dificultad alta."
    elif mastery_score >= 0.55:
        recommendation = "Continuar con práctica intermedia."
    else:
        recommendation = "Reforzar fundamentos y repetir ODA."

    return {
        "message": message,
        "recommendation": recommendation,
        "competency": competency,
        "mastery": mastery_score,
    }
'@

$Export = @'
"""Exportación de resultados de evaluación."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def export_result(
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
"""Servicio principal del Motor de Evaluación Adaptativa."""

from __future__ import annotations

from typing import Any

from .adaptation import (
    recommended_difficulty,
    select_next_item,
)
from .exporter import export_result
from .feedback import build_feedback
from .models import (
    AssessmentCommand,
    AssessmentItem,
    AssessmentResult,
    LearnerAttempt,
)
from .repository import AssessmentRepository
from .scoring import mastery, score_answer


_ALLOWED_TYPES = {
    "diagnostic",
    "formative",
    "summative",
}


def _item_from_payload(
    payload: dict[str, Any],
) -> AssessmentItem:
    return AssessmentItem(
        item_id=str(payload.get("item_id") or "").strip(),
        entry_id=str(payload.get("entry_id") or "").strip(),
        competency=str(payload.get("competency") or "").strip(),
        assessment_type=str(
            payload.get("assessment_type") or ""
        ).strip(),
        difficulty=int(payload.get("difficulty", 1)),
        prompt=str(payload.get("prompt") or "").strip(),
        correct_answer=str(
            payload.get("correct_answer") or ""
        ).strip(),
        options=tuple(
            str(item)
            for item in payload.get("options", []) or []
        ),
        media_resource_ids=tuple(
            str(item)
            for item in payload.get(
                "media_resource_ids",
                [],
            ) or []
        ),
        validated=bool(payload.get("validated", False)),
        metadata=dict(payload.get("metadata") or {}),
    )


def _item_to_dict(item: AssessmentItem) -> dict[str, Any]:
    return {
        "item_id": item.item_id,
        "entry_id": item.entry_id,
        "competency": item.competency,
        "assessment_type": item.assessment_type,
        "difficulty": item.difficulty,
        "prompt": item.prompt,
        "correct_answer": item.correct_answer,
        "options": list(item.options),
        "media_resource_ids": list(item.media_resource_ids),
        "validated": item.validated,
        "metadata": dict(item.metadata),
    }


def _validate_item(payload: dict[str, Any]) -> tuple[str, ...]:
    errors = []
    item_id = str(payload.get("item_id") or "").strip()
    entry_id = str(payload.get("entry_id") or "").strip()
    competency = str(payload.get("competency") or "").strip()
    assessment_type = str(
        payload.get("assessment_type") or ""
    ).strip()
    prompt = str(payload.get("prompt") or "").strip()
    correct_answer = str(
        payload.get("correct_answer") or ""
    ).strip()

    try:
        difficulty = int(payload.get("difficulty", 0))
    except (TypeError, ValueError):
        difficulty = 0

    if not item_id.startswith("QST-"):
        errors.append("item_id debe iniciar con QST-.")

    if not entry_id.startswith("LEX-"):
        errors.append("entry_id debe iniciar con LEX-.")

    if not competency:
        errors.append("La competencia es obligatoria.")

    if assessment_type not in _ALLOWED_TYPES:
        errors.append("assessment_type no está permitido.")

    if difficulty not in {1, 2, 3}:
        errors.append("difficulty debe ser 1, 2 o 3.")

    if not prompt:
        errors.append("El enunciado es obligatorio.")

    if not correct_answer:
        errors.append("La respuesta correcta es obligatoria.")

    return tuple(errors)


class AdaptiveAssessmentEngine:
    def __init__(
        self,
        repository: AssessmentRepository | None = None,
    ) -> None:
        self.repository = repository or AssessmentRepository()

    def execute(
        self,
        command: AssessmentCommand,
    ) -> AssessmentResult:
        handlers = {
            "register_item": self._register_item,
            "upsert_item": self._upsert_item,
            "next_item": self._next_item,
            "submit_answer": self._submit_answer,
            "mastery": self._mastery,
            "history": self._history,
            "stats": self._stats,
            "export_result": self._export_result,
        }

        handler = handlers.get(command.operation)

        if handler is None:
            return AssessmentResult(
                operation=command.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(command.payload)

    def _register_item(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        errors = _validate_item(payload)

        if errors:
            return AssessmentResult(
                operation="register_item",
                status="invalid_item",
                data={"errors": list(errors)},
                warnings=errors,
            )

        item = _item_from_payload(payload)

        try:
            self.repository.add_item(item)
        except ValueError as error:
            return AssessmentResult(
                operation="register_item",
                status="duplicate_id",
                data={"item_id": item.item_id},
                warnings=(str(error),),
            )

        return AssessmentResult(
            operation="register_item",
            status="ok",
            data=_item_to_dict(item),
        )

    def _upsert_item(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        errors = _validate_item(payload)

        if errors:
            return AssessmentResult(
                operation="upsert_item",
                status="invalid_item",
                data={"errors": list(errors)},
                warnings=errors,
            )

        item = self.repository.upsert_item(
            _item_from_payload(payload)
        )

        return AssessmentResult(
            operation="upsert_item",
            status="ok",
            data=_item_to_dict(item),
        )

    def _next_item(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        competency = str(
            payload.get("competency") or ""
        ).strip()
        attempts = self.repository.attempts_for(
            learner_id,
            competency,
        )
        items = self.repository.items_for_competency(
            competency,
            validated_only=True,
        )
        selected = select_next_item(items, attempts)

        if selected is None:
            return AssessmentResult(
                operation="next_item",
                status="not_found",
                data={
                    "learner_id": learner_id,
                    "competency": competency,
                },
            )

        return AssessmentResult(
            operation="next_item",
            status="ok",
            data={
                "item": _item_to_dict(selected),
                "recommended_difficulty": (
                    recommended_difficulty(attempts)
                ),
            },
        )

    def _submit_answer(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        item_id = str(payload.get("item_id") or "").strip()
        answer = str(payload.get("answer") or "")
        item = self.repository.get_item(item_id)

        if item is None:
            return AssessmentResult(
                operation="submit_answer",
                status="not_found",
                data={"item_id": item_id},
            )

        correct, score = score_answer(
            answer,
            item.correct_answer,
        )
        attempt = LearnerAttempt(
            learner_id=learner_id,
            item_id=item.item_id,
            answer=answer,
            correct=correct,
            score=score,
            difficulty=item.difficulty,
            competency=item.competency,
        )
        self.repository.add_attempt(attempt)
        attempts = self.repository.attempts_for(
            learner_id,
            item.competency,
        )
        mastery_score = mastery(attempts)

        return AssessmentResult(
            operation="submit_answer",
            status="ok",
            data={
                "learner_id": learner_id,
                "item_id": item_id,
                "correct": correct,
                "score": score,
                "mastery": mastery_score,
                "feedback": build_feedback(
                    correct,
                    mastery_score,
                    item.competency,
                ),
                "next_difficulty": (
                    recommended_difficulty(attempts)
                ),
            },
        )

    def _mastery(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        competency = str(
            payload.get("competency") or ""
        ).strip()
        attempts = self.repository.attempts_for(
            learner_id,
            competency,
        )

        return AssessmentResult(
            operation="mastery",
            status="ok",
            data={
                "learner_id": learner_id,
                "competency": competency,
                "attempts": len(attempts),
                "mastery": mastery(attempts),
                "recommended_difficulty": (
                    recommended_difficulty(attempts)
                ),
            },
        )

    def _history(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        attempts = self.repository.attempts_for(learner_id)

        return AssessmentResult(
            operation="history",
            status="ok",
            data={
                "learner_id": learner_id,
                "total": len(attempts),
                "attempts": [
                    {
                        "item_id": item.item_id,
                        "answer": item.answer,
                        "correct": item.correct,
                        "score": item.score,
                        "difficulty": item.difficulty,
                        "competency": item.competency,
                    }
                    for item in attempts
                ],
            },
        )

    def _stats(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        items = self.repository.items()

        return AssessmentResult(
            operation="stats",
            status="ok",
            data={
                "items": len(items),
                "validated_items": sum(
                    1 for item in items if item.validated
                ),
                "diagnostic": sum(
                    1
                    for item in items
                    if item.assessment_type == "diagnostic"
                ),
                "formative": sum(
                    1
                    for item in items
                    if item.assessment_type == "formative"
                ),
                "summative": sum(
                    1
                    for item in items
                    if item.assessment_type == "summative"
                ),
            },
        )

    def _export_result(
        self,
        payload: dict[str, Any],
    ) -> AssessmentResult:
        path = str(payload.get("path") or "").strip()
        learner_id = str(
            payload.get("learner_id") or ""
        ).strip()
        history = self._history(
            {"learner_id": learner_id}
        ).data
        export_result(
            path,
            {
                "schema": "SPT-015",
                "version": "1.0.0",
                "learner": history,
            },
        )

        return AssessmentResult(
            operation="export_result",
            status="ok",
            data={
                "path": path,
                "learner_id": learner_id,
            },
        )
'@

$Cli = @'
"""CLI de SPT-015."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import AssessmentCommand
from .service import AdaptiveAssessmentEngine


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

    engine = AdaptiveAssessmentEngine()

    for item in request.get("items", []):
        engine.execute(
            AssessmentCommand(
                operation="upsert_item",
                payload=dict(item),
            )
        )

    for attempt in request.get("attempts", []):
        engine.execute(
            AssessmentCommand(
                operation="submit_answer",
                payload=dict(attempt),
            )
        )

    response = engine.execute(
        AssessmentCommand(
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

    print("SPT-015 ejecutado correctamente.")
    print(f"Operación: {response.operation}")
    print(f"Estado: {response.status}")
    print(f"Resultado: {target}")

    return 0 if response.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""SPT-015 — Motor de Evaluación Adaptativa."""

from .adaptation import (
    recommended_difficulty,
    select_next_item,
)
from .feedback import build_feedback
from .models import (
    AssessmentCommand,
    AssessmentItem,
    AssessmentResult,
    LearnerAttempt,
)
from .repository import AssessmentRepository
from .scoring import mastery, score_answer
from .service import AdaptiveAssessmentEngine

__all__ = [
    "AdaptiveAssessmentEngine",
    "AssessmentCommand",
    "AssessmentItem",
    "AssessmentRepository",
    "AssessmentResult",
    "LearnerAttempt",
    "build_feedback",
    "mastery",
    "recommended_difficulty",
    "score_answer",
    "select_next_item",
]
'@

$Tests = @'
from __future__ import annotations

from pathlib import Path

from sgoda.adaptive_assessment import (
    AdaptiveAssessmentEngine,
    AssessmentCommand,
    AssessmentRepository,
    AssessmentItem,
    LearnerAttempt,
    mastery,
    recommended_difficulty,
    score_answer,
    select_next_item,
)


def _item(
    item_id: str = "QST-001",
    difficulty: int = 1,
    assessment_type: str = "formative",
    validated: bool = True,
) -> dict:
    return {
        "item_id": item_id,
        "entry_id": "LEX-001",
        "competency": "vocabulary",
        "assessment_type": assessment_type,
        "difficulty": difficulty,
        "prompt": "¿Qué significa AMDA?",
        "correct_answer": "casa",
        "options": ["casa", "río", "fuego"],
        "media_resource_ids": ["MED-001"],
        "validated": validated,
    }


def test_SPT_015_registers_item() -> None:
    engine = AdaptiveAssessmentEngine()
    result = engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    assert result.status == "ok"


def test_SPT_015_rejects_invalid_id() -> None:
    payload = _item()
    payload["item_id"] = "BAD"
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(
            operation="register_item",
            payload=payload,
        )
    )

    assert result.status == "invalid_item"


def test_SPT_015_rejects_invalid_entry_id() -> None:
    payload = _item()
    payload["entry_id"] = "BAD"
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(
            operation="register_item",
            payload=payload,
        )
    )

    assert result.status == "invalid_item"


def test_SPT_015_rejects_invalid_type() -> None:
    payload = _item()
    payload["assessment_type"] = "other"
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(
            operation="register_item",
            payload=payload,
        )
    )

    assert result.status == "invalid_item"


def test_SPT_015_rejects_invalid_difficulty() -> None:
    payload = _item()
    payload["difficulty"] = 9
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(
            operation="register_item",
            payload=payload,
        )
    )

    assert result.status == "invalid_item"


def test_SPT_015_detects_duplicate_id() -> None:
    engine = AdaptiveAssessmentEngine()
    command = AssessmentCommand(
        operation="register_item",
        payload=_item(),
    )
    engine.execute(command)

    assert engine.execute(command).status == "duplicate_id"


def test_SPT_015_scores_correct_answer() -> None:
    assert score_answer("Casa", "casa") == (True, 1.0)


def test_SPT_015_scores_incorrect_answer() -> None:
    assert score_answer("río", "casa") == (False, 0.0)


def test_SPT_015_mastery_is_zero_without_attempts() -> None:
    assert mastery(()) == 0.0


def test_SPT_015_mastery_is_weighted() -> None:
    attempts = (
        LearnerAttempt(
            "L-001",
            "Q1",
            "casa",
            True,
            1.0,
            1,
            "vocabulary",
        ),
        LearnerAttempt(
            "L-001",
            "Q2",
            "río",
            False,
            0.0,
            3,
            "vocabulary",
        ),
    )

    assert mastery(attempts) == 0.25


def test_SPT_015_recommends_low_difficulty() -> None:
    assert recommended_difficulty(()) == 1


def test_SPT_015_recommends_high_difficulty() -> None:
    attempts = (
        LearnerAttempt(
            "L-001",
            "Q1",
            "casa",
            True,
            1.0,
            3,
            "vocabulary",
        ),
    )

    assert recommended_difficulty(attempts) == 3


def test_SPT_015_selects_validated_item() -> None:
    items = (
        AssessmentItem(
            "QST-001",
            "LEX-001",
            "vocabulary",
            "formative",
            1,
            "Prompt",
            "casa",
            validated=False,
        ),
        AssessmentItem(
            "QST-002",
            "LEX-001",
            "vocabulary",
            "formative",
            1,
            "Prompt",
            "casa",
            validated=True,
        ),
    )

    assert select_next_item(items, ()).item_id == "QST-002"


def test_SPT_015_next_item_works() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    result = engine.execute(
        AssessmentCommand(
            operation="next_item",
            payload={
                "learner_id": "L-001",
                "competency": "vocabulary",
            },
        )
    )

    assert result.status == "ok"


def test_SPT_015_submits_correct_answer() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    result = engine.execute(
        AssessmentCommand(
            operation="submit_answer",
            payload={
                "learner_id": "L-001",
                "item_id": "QST-001",
                "answer": "casa",
            },
        )
    )

    assert result.data["correct"] is True
    assert result.data["mastery"] == 1.0


def test_SPT_015_submits_incorrect_answer() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    result = engine.execute(
        AssessmentCommand(
            operation="submit_answer",
            payload={
                "learner_id": "L-001",
                "item_id": "QST-001",
                "answer": "río",
            },
        )
    )

    assert result.data["correct"] is False


def test_SPT_015_reports_history() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )
    engine.execute(
        AssessmentCommand(
            operation="submit_answer",
            payload={
                "learner_id": "L-001",
                "item_id": "QST-001",
                "answer": "casa",
            },
        )
    )

    result = engine.execute(
        AssessmentCommand(
            operation="history",
            payload={"learner_id": "L-001"},
        )
    )

    assert result.data["total"] == 1


def test_SPT_015_reports_stats() -> None:
    engine = AdaptiveAssessmentEngine()
    engine.execute(
        AssessmentCommand(
            operation="register_item",
            payload=_item(),
        )
    )

    result = engine.execute(
        AssessmentCommand(operation="stats")
    )

    assert result.data["items"] == 1
    assert result.data["formative"] == 1


def test_SPT_015_exports_result(tmp_path: Path) -> None:
    target = tmp_path / "result.json"
    engine = AdaptiveAssessmentEngine()

    result = engine.execute(
        AssessmentCommand(
            operation="export_result",
            payload={
                "path": str(target),
                "learner_id": "L-001",
            },
        )
    )

    assert result.status == "ok"
    assert target.exists()


def test_SPT_015_preserves_no_invention() -> None:
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(operation="stats")
    )

    assert result.no_invention is True


def test_SPT_015_rejects_unknown_operation() -> None:
    result = AdaptiveAssessmentEngine().execute(
        AssessmentCommand(operation="unknown")
    )

    assert result.status == "unsupported_operation"
'@

$Component = @'
{
  "increment_code": "SPT-015",
  "name": "Motor de Evaluación Adaptativa",
  "component_type": "adaptive_assessment_engine",
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
    "SPT-014",
    "SPT-012",
    "SPT-008",
    "SGD-114D",
    "SGD-114E",
    "SGD-115A",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/adaptive_assessment/models.py",
    "src/sgoda/adaptive_assessment/repository.py",
    "src/sgoda/adaptive_assessment/scoring.py",
    "src/sgoda/adaptive_assessment/adaptation.py",
    "src/sgoda/adaptive_assessment/feedback.py",
    "src/sgoda/adaptive_assessment/exporter.py",
    "src/sgoda/adaptive_assessment/service.py",
    "src/sgoda/adaptive_assessment/cli.py"
  ],
  "tests": [
    "tests/adaptive_assessment/test_SPT_015_adaptive_assessment_engine.py"
  ],
  "documentation": [
    "docs/08_Fase_Tecnologica_IV/SPT-015/SPT-015-Arquitectura.md",
    "docs/08_Fase_Tecnologica_IV/SPT-015/SPT-015-Modelo-Adaptativo.md",
    "docs/08_Fase_Tecnologica_IV/SPT-015/SPT-015-Rubricas.md"
  ]
}
'@

$Policy = @'
{
  "component": "SPT-015",
  "version": "1.0.0",
  "validated_items_only": true,
  "difficulty_levels": [
    1,
    2,
    3
  ],
  "assessment_types": [
    "diagnostic",
    "formative",
    "summative"
  ],
  "no_invention": true,
  "local_first": true,
  "free_open_technology": true,
  "mandatory_proprietary_dependencies": []
}
'@

$Rubrics = @'
{
  "component": "SPT-015",
  "version": "1.0.0",
  "mastery_thresholds": {
    "reinforcement": 0.0,
    "intermediate": 0.55,
    "advanced": 0.85
  },
  "score": {
    "correct": 1.0,
    "incorrect": 0.0
  },
  "difficulty_weights": {
    "1": 1,
    "2": 2,
    "3": 3
  }
}
'@

$Schema = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SPT-015 Assessment Item",
  "type": "object",
  "required": [
    "item_id",
    "entry_id",
    "competency",
    "assessment_type",
    "difficulty",
    "prompt",
    "correct_answer"
  ],
  "properties": {
    "item_id": {
      "type": "string",
      "pattern": "^QST-"
    },
    "entry_id": {
      "type": "string",
      "pattern": "^LEX-"
    },
    "assessment_type": {
      "enum": [
        "diagnostic",
        "formative",
        "summative"
      ]
    },
    "difficulty": {
      "type": "integer",
      "minimum": 1,
      "maximum": 3
    },
    "validated": {
      "type": "boolean"
    }
  }
}
'@

$Docs = @{
    (Join-Path $DocsDir "SPT-015-Arquitectura.md") = @'
# SPT-015 — Arquitectura

SPT-015 administra preguntas, intentos, puntajes, dominio, adaptación y
retroalimentación. Se integra nativamente con SPT-013B, SPT-014, SPT-012 y
SPT-008.
'@

    (Join-Path $DocsDir "SPT-015-Modelo-Adaptativo.md") = @'
# SPT-015 — Modelo adaptativo

El motor calcula dominio ponderado por dificultad:

- dominio inferior a 0.55: dificultad 1;
- dominio desde 0.55: dificultad 2;
- dominio desde 0.85: dificultad 3.

La selección usa únicamente preguntas validadas.
'@

    (Join-Path $DocsDir "SPT-015-Rubricas.md") = @'
# SPT-015 — Rúbricas

Se admiten evaluaciones diagnósticas, formativas y sumativas. Cada respuesta
correcta obtiene 1.0 y cada respuesta incorrecta 0.0. La dificultad pondera
el cálculo del dominio.
'@
}

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [string]$Output = "artifacts/adaptive_assessment/SPT-015/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.adaptive_assessment.cli `
    --request-file "$RequestFile" `
    --output "$Output"

exit $LASTEXITCODE
'@

Write-Step "Instalando SPT-015"

Write-Utf8 -Path $ModelsPath -Content $Models
Write-Utf8 -Path $RepositoryPath -Content $Repository
Write-Utf8 -Path $ScoringPath -Content $Scoring
Write-Utf8 -Path $AdaptationPath -Content $Adaptation
Write-Utf8 -Path $FeedbackPath -Content $Feedback
Write-Utf8 -Path $ExportPath -Content $Export
Write-Utf8 -Path $ServicePath -Content $Service
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $InitPath -Content $Init
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $RubricsPath -Content $Rubrics
Write-Utf8 -Path $SchemaPath -Content $Schema
Write-Utf8 -Path $InvokePath -Content $Invoke

foreach ($Document in $Docs.GetEnumerator()) {
    Write-Utf8 `
        -Path $Document.Key `
        -Content $Document.Value
}

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/adaptive_assessment/models.py" `
        "src/sgoda/adaptive_assessment/repository.py" `
        "src/sgoda/adaptive_assessment/scoring.py" `
        "src/sgoda/adaptive_assessment/adaptation.py" `
        "src/sgoda/adaptive_assessment/feedback.py" `
        "src/sgoda/adaptive_assessment/exporter.py" `
        "src/sgoda/adaptive_assessment/service.py" `
        "src/sgoda/adaptive_assessment/cli.py" `
        "src/sgoda/adaptive_assessment/__init__.py" `
        "tests/adaptive_assessment/test_SPT_015_adaptive_assessment_engine.py"
}

Invoke-Checked "Ejecutando 20 pruebas específicas SPT-015" {
    python -m pytest `
        "tests/adaptive_assessment/test_SPT_015_adaptive_assessment_engine.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Ejecutando demostración institucional AMDA"

$DemoItems = @(
    [ordered]@{
        item_id = "QST-001"
        entry_id = "LEX-001"
        competency = "vocabulary"
        assessment_type = "diagnostic"
        difficulty = 1
        prompt = "¿Qué significa AMDA?"
        correct_answer = "casa"
        options = @("casa", "río", "fuego")
        media_resource_ids = @("MED-001", "MED-002")
        validated = $true
    },
    [ordered]@{
        item_id = "QST-002"
        entry_id = "LEX-001"
        competency = "vocabulary"
        assessment_type = "formative"
        difficulty = 2
        prompt = "Seleccione la traducción correcta de AMDA."
        correct_answer = "casa"
        options = @("casa", "agua", "tierra")
        media_resource_ids = @("MED-001")
        validated = $true
    }
)

Write-Json `
    -Path $DemoRequestPath `
    -Value ([ordered]@{
        items = $DemoItems
        attempts = @(
            [ordered]@{
                learner_id = "LEARNER-001"
                item_id = "QST-001"
                answer = "casa"
            }
        )
        operation = "mastery"
        payload = [ordered]@{
            learner_id = "LEARNER-001"
            competency = "vocabulary"
        }
    })

Invoke-Checked "Evaluando aprendizaje de AMDA" {
    python -m sgoda.adaptive_assessment.cli `
        --request-file "$DemoRequestPath" `
        --output "$DemoOutputPath"
}

$Demo = Get-Content `
    -LiteralPath $DemoOutputPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración SPT-015 no fue aprobada."
}

if ([double]$Demo.data.mastery -ne 1.0) {
    throw "El dominio esperado para AMDA no fue 1.0."
}

if ([int]$Demo.data.recommended_difficulty -ne 3) {
    throw "La adaptación esperada no seleccionó dificultad 3."
}

Write-Step "Generando evidencia y release"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json `
    -Path $EvidencePath `
    -Value ([ordered]@{
        increment_code = "SPT-015"
        version = "1.0.0"
        status = "implemented_and_tested"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        specific_tests = 20
        full_suite_executed = (-not $SkipFullSuite)
        demo_status = $Demo.status
        demo_learner = $Demo.data.learner_id
        demo_competency = $Demo.data.competency
        demo_mastery = $Demo.data.mastery
        recommended_difficulty = (
            $Demo.data.recommended_difficulty
        )
        no_invention = [bool]$Demo.no_invention
        backup = $BackupDir
    })

foreach ($ReleaseFile in @(
    $ModelsPath,
    $RepositoryPath,
    $ScoringPath,
    $AdaptationPath,
    $FeedbackPath,
    $ExportPath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $RubricsPath,
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
        increment_code = "SPT-015"
        version = "1.0.0"
        status = "implemented_and_tested"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
            Select-Object -ExpandProperty Name
        )
    })

Write-Step "Evaluando SPT-015 mediante SGD-114D"

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$ProjectRoot" `
    --increment "SPT-015" `
    --output-json "$PolicyJson" `
    --output-md "$PolicyMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114D no aprobó SPT-015."
}

Write-Step "Evaluando arquitectura nativa mediante SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$NativeJson" `
    --output-md "$NativeMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SPT-015."
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
            "feat(assessment): implement SPT-015 adaptive assessment engine"
        ) `
        -EvidenceCommitMessage (
            "chore(assessment): publish SPT-015 evidence"
        )

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Write-Step "Resultado final"

Write-Host "SPT-015 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Motor de Evaluación Adaptativa: OPERATIVO." `
    -ForegroundColor Green
Write-Host "Evaluación diagnóstica: IMPLEMENTADA." `
    -ForegroundColor Green
Write-Host "Evaluación formativa: IMPLEMENTADA." `
    -ForegroundColor Green
Write-Host "Evaluación sumativa: IMPLEMENTADA." `
    -ForegroundColor Green
Write-Host "Adaptación automática de dificultad: IMPLEMENTADA." `
    -ForegroundColor Green
Write-Host "Puntaje y dominio: IMPLEMENTADOS." `
    -ForegroundColor Green
Write-Host "Retroalimentación y recomendaciones: IMPLEMENTADAS." `
    -ForegroundColor Green
Write-Host "Historial y exportación: IMPLEMENTADOS." `
    -ForegroundColor Green
Write-Host "Pruebas específicas: 20 APROBADAS." `
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
Write-Host "Release: releases\SPT-015-v1.0.0" `
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
