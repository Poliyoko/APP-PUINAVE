<#
.SYNOPSIS
    Implementa SPT-004A — Fundación del Asistente Inteligente Institucional.

.DESCRIPTION
    Instala desde un solo archivo:
      - modelos de conversación;
      - clasificador de intenciones basado en reglas;
      - búsqueda segura sobre el repositorio léxico canónico;
      - consulta básica de ODA;
      - preguntas frecuentes institucionales;
      - respuestas con fuentes y nivel de validación;
      - política de no invención lingüística;
      - registro de preguntas no resueltas;
      - API de servicio desacoplada;
      - CLI;
      - pruebas automatizadas;
      - documentación, evidencias, dashboard, release y quality gate;
      - actualización de SGD-115.

    El nombre visible en lengua Puinave queda pendiente de validación
    lingüística y cultural. El identificador técnico permanente es SPT-004.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.

.EXAMPLE
    .\Install-SPT004A-Institutional-Assistant-Foundation.ps1
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\assistant"
$TestsDir = Join-Path $ProjectRoot "tests\assistant"
$ConfigDir = Join-Path $ProjectRoot "config\assistant"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-004"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\assistant\SPT-004A"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-004A"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-004A-v0.1.0"

$ModelsPath = Join-Path $SourceDir "models.py"
$RepositoryPath = Join-Path $SourceDir "knowledge_repository.py"
$IntentPath = Join-Path $SourceDir "intent_classifier.py"
$FaqPath = Join-Path $SourceDir "faq.py"
$ServicePath = Join-Path $SourceDir "service.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPT_004A_institutional_assistant.py"

$PolicyPath = Join-Path $ConfigDir "SPT-004A-assistant-policy.json"
$FaqConfigPath = Join-Path $ConfigDir "SPT-004A-faq.json"
$IdentityPath = Join-Path $ConfigDir "SPT-004A-identity.json"
$ComponentPath = Join-Path $ConfigDir "SPT-004A-component.json"

$DocPath = Join-Path $DocsDir "SPT-004A-Fundacion-Asistente-Institucional.md"
$SafetyPath = Join-Path $DocsDir "SPT-004A-Seguridad-Linguistica-Cultural.md"
$IdentityDocPath = Join-Path $DocsDir "SPT-004A-Identidad-Cultural-Pendiente.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT004A-AssistantDemo.ps1"

$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SPT-004A.json"
$GatePath = Join-Path $PmoDir "SPT-004A-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPT-004A-dashboard.json"

$CanonicalRepository = Join-Path `
    $ProjectRoot `
    "artifacts\rlb\SPT-001B-P08\canonical-repository-v1.0.0.json"

$OdaRepository = Join-Path `
    $ProjectRoot `
    "artifacts\oda\SPT-002\oda-repository-v0.1.0.json"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    $CanonicalRepository,
    $OdaRepository,
    (Join-Path $ProjectRoot "docs\00_INDICE_MAESTRO.md"),
    (Join-Path $ProjectRoot "docs\00_ARQUITECTURA_MAESTRA.md"),
    (Join-Path $ProjectRoot "docs\00_REGISTRO_MAESTRO_COMPONENTES.md"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
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
    '^\?\? Install-SPT004A-Institutional-Assistant-Foundation\.ps1$',
    '^\?\? Repair-SPT004A-v[0-9.]+-.*\.ps1$',
    '^\?\? SPT004A-.*\.zip$',
    '^\?\? LEAME-SPT004A.*\.txt$'
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
    Write-Host "Cambios Git no permitidos antes de SPT-004A:" -ForegroundColor Red
    $Unexpected | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }
    throw "La línea base contiene cambios ajenos a SPT-004A."
}

$ModelsContent = @'
"""Modelos del Asistente Inteligente Institucional SPT-004A."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class FuenteRespuesta:
    source_type: str
    source_id: str
    label: str
    path: str | None = None
    validated: bool = True


@dataclass(slots=True)
class ConsultaAsistente:
    question: str
    language: str = "es"
    user_role: str = "visitor"
    session_id: str | None = None


@dataclass(slots=True)
class RespuestaAsistente:
    answer: str
    intent: str
    confidence: float
    validated: bool
    found: bool
    sources: list[FuenteRespuesta] = field(default_factory=list)
    suggestions: list[str] = field(default_factory=list)
    data: dict[str, Any] = field(default_factory=dict)
    requires_human_review: bool = False
'@

$IntentContent = @'
"""Clasificador institucional de intenciones."""

from __future__ import annotations

import re
import unicodedata


def normalize_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value.casefold())
    without_marks = "".join(
        char for char in normalized
        if not unicodedata.combining(char)
    )
    return re.sub(r"\s+", " ", without_marks).strip()


RULES: list[tuple[str, tuple[str, ...]]] = [
    (
        "platform_help",
        (
            "como uso",
            "como buscar",
            "como escuch",
            "como funciona",
            "ayuda",
            "donde encuentro",
        ),
    ),
    (
        "project_information",
        (
            "que es sgoda",
            "proyecto puinave",
            "objetivo del proyecto",
            "para que sirve",
        ),
    ),
    (
        "learning_activity",
        (
            "hazme una prueba",
            "quiero practicar",
            "quiero aprender",
            "palabras nuevas",
            "actividad",
        ),
    ),
    (
        "category_search",
        (
            "palabras relacionadas",
            "palabras de",
            "categoria",
            "animales",
            "plantas",
            "familia",
        ),
    ),
    (
        "lexical_search",
        (
            "como se dice",
            "que significa",
            "traduccion",
            "palabra",
            "en puinave",
            "en español",
            "en ingles",
        ),
    ),
]


def classify_intent(question: str) -> tuple[str, float]:
    normalized = normalize_text(question)

    for intent, patterns in RULES:
        if any(pattern in normalized for pattern in patterns):
            return intent, 0.92

    if len(normalized.split()) <= 3:
        return "lexical_search", 0.65

    return "unknown", 0.25
'@

$FaqContent = @'
"""Preguntas frecuentes institucionales."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .intent_classifier import normalize_text


class FaqRepository:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        payload = json.loads(self.path.read_text(encoding="utf-8"))
        self.items: list[dict[str, Any]] = list(payload["items"])

    def search(self, question: str) -> dict[str, Any] | None:
        normalized = normalize_text(question)
        best: dict[str, Any] | None = None
        best_score = 0

        for item in self.items:
            keywords = [
                normalize_text(str(keyword))
                for keyword in item.get("keywords", [])
            ]
            score = sum(
                1 for keyword in keywords
                if keyword and keyword in normalized
            )
            if score > best_score:
                best = item
                best_score = score

        return best if best_score > 0 else None
'@

$RepositoryContent = @'
"""Acceso seguro al conocimiento institucional validado."""

from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path
from typing import Any


def _normalize(value: Any) -> str:
    text = unicodedata.normalize(
        "NFKD",
        str(value or "").casefold(),
    )
    text = "".join(
        char for char in text
        if not unicodedata.combining(char)
    )
    return re.sub(r"\s+", " ", text).strip()


def _records_from_payload(payload: Any) -> list[dict[str, Any]]:
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
        "objetos_digitales_aprendizaje",
        "odas",
    ):
        value = payload.get(key)
        if isinstance(value, list):
            return [
                item for item in value
                if isinstance(item, dict)
            ]

    for value in payload.values():
        if isinstance(value, list) and all(
            isinstance(item, dict) for item in value
        ):
            return list(value)

    return []


class KnowledgeRepository:
    def __init__(
        self,
        *,
        canonical_path: str | Path,
        oda_path: str | Path,
    ) -> None:
        self.canonical_path = Path(canonical_path)
        self.oda_path = Path(oda_path)

        canonical_payload = json.loads(
            self.canonical_path.read_text(encoding="utf-8")
        )
        oda_payload = json.loads(
            self.oda_path.read_text(encoding="utf-8")
        )

        self.canonical_records = _records_from_payload(
            canonical_payload
        )
        self.oda_records = _records_from_payload(oda_payload)

    @staticmethod
    def _field(
        record: dict[str, Any],
        *names: str,
    ) -> Any:
        for name in names:
            value = record.get(name)
            if value not in (None, ""):
                return value
        return None

    def search_lexical(
        self,
        term: str,
        *,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        normalized_term = _normalize(term)
        if not normalized_term:
            return []

        scored: list[tuple[int, dict[str, Any]]] = []

        for record in self.canonical_records:
            puinave = self._field(
                record,
                "puinave",
                "palabra_puinave",
                "termino_puinave",
                "word_puinave",
            )
            spanish = self._field(
                record,
                "espanol",
                "español",
                "traduccion_espanol",
                "traducción_español",
                "spanish",
            )
            english = self._field(
                record,
                "ingles",
                "inglés",
                "traduccion_ingles",
                "traducción_inglés",
                "english",
            )
            category = self._field(
                record,
                "categoria",
                "categoría",
                "category",
                "campo_semantico",
            )

            values = [
                _normalize(puinave),
                _normalize(spanish),
                _normalize(english),
                _normalize(category),
            ]

            score = 0
            for value in values:
                if not value:
                    continue
                if normalized_term == value:
                    score = max(score, 100)
                elif normalized_term in value:
                    score = max(score, 70)
                elif value in normalized_term:
                    score = max(score, 50)

            if score > 0:
                scored.append(
                    (
                        score,
                        {
                            "canonical_id": self._field(
                                record,
                                "canonical_id",
                                "id",
                                "lexical_id",
                            ),
                            "puinave": puinave,
                            "spanish": spanish,
                            "english": english,
                            "category": category,
                            "raw": record,
                        },
                    )
                )

        scored.sort(
            key=lambda item: (
                -item[0],
                _normalize(item[1].get("puinave")),
            )
        )
        return [item[1] for item in scored[:limit]]

    def search_category(
        self,
        category: str,
        *,
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        return self.search_lexical(category, limit=limit)

    def find_oda(
        self,
        canonical_id: str | None,
    ) -> dict[str, Any] | None:
        if not canonical_id:
            return None

        normalized = _normalize(canonical_id)

        for record in self.oda_records:
            value = self._field(
                record,
                "canonical_id",
                "lexical_id",
                "source_id",
            )
            if _normalize(value) == normalized:
                return record

        return None
'@

$ServiceContent = @'
"""Servicio principal del Asistente Inteligente Institucional."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .faq import FaqRepository
from .intent_classifier import classify_intent, normalize_text
from .knowledge_repository import KnowledgeRepository
from .models import (
    ConsultaAsistente,
    FuenteRespuesta,
    RespuestaAsistente,
)


SAFE_FALLBACK = (
    "No encontré una respuesta validada para esta consulta. "
    "La pregunta quedó registrada para revisión lingüística, "
    "educativa o cultural."
)


class InstitutionalAssistant:
    def __init__(
        self,
        *,
        repository: KnowledgeRepository,
        faq: FaqRepository,
        unresolved_path: str | Path,
        display_name: str = "Asistente Virtual SGODA",
    ) -> None:
        self.repository = repository
        self.faq = faq
        self.unresolved_path = Path(unresolved_path)
        self.display_name = display_name

    @staticmethod
    def _extract_search_term(question: str) -> str:
        normalized = normalize_text(question)
        patterns = (
            r"como se dice\s+(.+?)(?:\s+en puinave)?$",
            r"que significa\s+(.+)$",
            r"traduccion de\s+(.+)$",
            r"palabra\s+(.+)$",
        )

        for pattern in patterns:
            match = re.search(pattern, normalized)
            if match:
                return match.group(1).strip(" ?¿!¡.")

        return question.strip(" ?¿!¡.")

    def _record_unresolved(
        self,
        query: ConsultaAsistente,
        intent: str,
    ) -> None:
        self.unresolved_path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        record = {
            "occurred_at_utc": datetime.now(
                timezone.utc
            ).isoformat(),
            "question": query.question,
            "language": query.language,
            "user_role": query.user_role,
            "session_id": query.session_id,
            "intent": intent,
            "status": "pending_human_review",
        }

        with self.unresolved_path.open(
            "a",
            encoding="utf-8",
        ) as stream:
            stream.write(
                json.dumps(record, ensure_ascii=False) + "\n"
            )

    def answer(
        self,
        query: ConsultaAsistente,
    ) -> RespuestaAsistente:
        question = query.question.strip()

        if not question:
            return RespuestaAsistente(
                answer="Escribe una pregunta para poder ayudarte.",
                intent="empty",
                confidence=1.0,
                validated=True,
                found=False,
            )

        intent, confidence = classify_intent(question)

        if intent in {"platform_help", "project_information"}:
            faq_item = self.faq.search(question)
            if faq_item is not None:
                return RespuestaAsistente(
                    answer=str(faq_item["answer"]),
                    intent=intent,
                    confidence=confidence,
                    validated=True,
                    found=True,
                    sources=[
                        FuenteRespuesta(
                            source_type="institutional_faq",
                            source_id=str(faq_item["id"]),
                            label="Preguntas frecuentes institucionales",
                            path="config/assistant/SPT-004A-faq.json",
                        )
                    ],
                    suggestions=list(
                        faq_item.get("suggestions", [])
                    ),
                )

        if intent in {
            "lexical_search",
            "category_search",
            "learning_activity",
        }:
            term = self._extract_search_term(question)
            results = self.repository.search_lexical(
                term,
                limit=10 if intent == "category_search" else 5,
            )

            if results:
                first = results[0]
                puinave = first.get("puinave") or "No registrada"
                spanish = first.get("spanish") or "No registrada"
                english = first.get("english") or "No registrada"
                canonical_id = str(
                    first.get("canonical_id") or "sin-id"
                )

                oda = self.repository.find_oda(
                    first.get("canonical_id")
                )

                if len(results) == 1:
                    answer = (
                        f"Encontré una entrada validada. "
                        f"Puinave: «{puinave}». "
                        f"Español: «{spanish}». "
                        f"Inglés: «{english}»."
                    )
                else:
                    preview = "; ".join(
                        str(item.get("puinave") or item.get("spanish"))
                        for item in results[:5]
                    )
                    answer = (
                        f"Encontré {len(results)} entradas relacionadas: "
                        f"{preview}."
                    )

                sources = [
                    FuenteRespuesta(
                        source_type="canonical_lexical_repository",
                        source_id=canonical_id,
                        label="Repositorio Léxico Canónico",
                        path=(
                            "artifacts/rlb/SPT-001B-P08/"
                            "canonical-repository-v1.0.0.json"
                        ),
                    )
                ]

                if oda is not None:
                    oda_id = str(
                        oda.get("oda_id")
                        or oda.get("id")
                        or canonical_id
                    )
                    sources.append(
                        FuenteRespuesta(
                            source_type="oda_repository",
                            source_id=oda_id,
                            label="Repositorio de ODA",
                            path=(
                                "artifacts/oda/SPT-002/"
                                "oda-repository-v0.1.0.json"
                            ),
                        )
                    )

                return RespuestaAsistente(
                    answer=answer,
                    intent=intent,
                    confidence=confidence,
                    validated=True,
                    found=True,
                    sources=sources,
                    suggestions=[
                        "Escuchar pronunciación",
                        "Ver imagen",
                        "Practicar esta palabra",
                    ],
                    data={
                        "matches": results,
                        "oda": oda,
                    },
                )

        self._record_unresolved(query, intent)

        return RespuestaAsistente(
            answer=SAFE_FALLBACK,
            intent=intent,
            confidence=confidence,
            validated=False,
            found=False,
            sources=[],
            suggestions=[
                "Buscar una palabra",
                "Cómo usar la plataforma",
                "Conocer el proyecto",
            ],
            requires_human_review=True,
        )
'@

$CliContent = @'
"""CLI del Asistente Inteligente Institucional."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .faq import FaqRepository
from .knowledge_repository import KnowledgeRepository
from .models import ConsultaAsistente
from .service import InstitutionalAssistant


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("question")
    parser.add_argument(
        "--canonical",
        default=(
            "artifacts/rlb/SPT-001B-P08/"
            "canonical-repository-v1.0.0.json"
        ),
    )
    parser.add_argument(
        "--oda",
        default=(
            "artifacts/oda/SPT-002/"
            "oda-repository-v0.1.0.json"
        ),
    )
    parser.add_argument(
        "--faq",
        default="config/assistant/SPT-004A-faq.json",
    )
    parser.add_argument(
        "--unresolved",
        default=(
            "artifacts/assistant/SPT-004A/"
            "unresolved-questions.jsonl"
        ),
    )
    parser.add_argument(
        "--output",
        default=(
            "artifacts/assistant/SPT-004A/"
            "last-response.json"
        ),
    )
    args = parser.parse_args()

    assistant = InstitutionalAssistant(
        repository=KnowledgeRepository(
            canonical_path=args.canonical,
            oda_path=args.oda,
        ),
        faq=FaqRepository(args.faq),
        unresolved_path=args.unresolved,
    )

    response = assistant.answer(
        ConsultaAsistente(question=args.question)
    )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(
            asdict(response),
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    print(response.answer)
    print(f"Intención: {response.intent}")
    print(f"Validada: {response.validated}")
    print(f"Fuentes: {len(response.sources)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Asistente Inteligente Institucional SGODA-PUINAVE."""

from __future__ import annotations

from typing import Any

__all__ = [
    "ConsultaAsistente",
    "FuenteRespuesta",
    "InstitutionalAssistant",
    "KnowledgeRepository",
    "RespuestaAsistente",
    "classify_intent",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)

    if name in {
        "ConsultaAsistente",
        "FuenteRespuesta",
        "RespuestaAsistente",
    }:
        from . import models
        return getattr(models, name)

    if name == "KnowledgeRepository":
        from . import knowledge_repository
        return getattr(knowledge_repository, name)

    if name == "InstitutionalAssistant":
        from . import service
        return getattr(service, name)

    if name == "classify_intent":
        from . import intent_classifier
        return getattr(intent_classifier, name)

    raise AttributeError(name)
'@

$TestContent = @'
"""Pruebas SPT-004A del Asistente Inteligente Institucional."""

import json
from pathlib import Path

from sgoda.assistant.faq import FaqRepository
from sgoda.assistant.intent_classifier import classify_intent
from sgoda.assistant.knowledge_repository import KnowledgeRepository
from sgoda.assistant.models import ConsultaAsistente
from sgoda.assistant.service import InstitutionalAssistant


def _files(tmp_path: Path) -> tuple[Path, Path, Path]:
    canonical = tmp_path / "canonical.json"
    oda = tmp_path / "oda.json"
    faq = tmp_path / "faq.json"

    canonical.write_text(
        json.dumps(
            {
                "records": [
                    {
                        "canonical_id": "LEX-001",
                        "puinave": "AMDA",
                        "espanol": "ejemplo",
                        "ingles": "example",
                        "categoria": "aprendizaje",
                    },
                    {
                        "canonical_id": "LEX-002",
                        "puinave": "WAI",
                        "espanol": "agua",
                        "ingles": "water",
                        "categoria": "naturaleza",
                    },
                ]
            }
        ),
        encoding="utf-8",
    )

    oda.write_text(
        json.dumps(
            {
                "objetos_digitales_aprendizaje": [
                    {
                        "oda_id": "ODA-001",
                        "canonical_id": "LEX-001",
                        "title": "AMDA",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )

    faq.write_text(
        json.dumps(
            {
                "items": [
                    {
                        "id": "FAQ-001",
                        "keywords": ["como buscar", "buscar palabra"],
                        "answer": "Usa el buscador principal.",
                        "suggestions": ["Buscar una palabra"],
                    },
                    {
                        "id": "FAQ-002",
                        "keywords": ["que es sgoda"],
                        "answer": "SGODA preserva y enseña la lengua Puinave.",
                    },
                ]
            }
        ),
        encoding="utf-8",
    )

    return canonical, oda, faq


def _assistant(tmp_path: Path) -> InstitutionalAssistant:
    canonical, oda, faq = _files(tmp_path)
    return InstitutionalAssistant(
        repository=KnowledgeRepository(
            canonical_path=canonical,
            oda_path=oda,
        ),
        faq=FaqRepository(faq),
        unresolved_path=tmp_path / "unresolved.jsonl",
    )


def test_SPT_004A_clasifica_busqueda_lexica() -> None:
    intent, confidence = classify_intent(
        "¿Cómo se dice agua en Puinave?"
    )
    assert intent == "lexical_search"
    assert confidence > 0.8


def test_SPT_004A_clasifica_ayuda() -> None:
    intent, _ = classify_intent(
        "¿Cómo buscar una palabra?"
    )
    assert intent == "platform_help"


def test_SPT_004A_busca_repositorio_canonico(
    tmp_path: Path,
) -> None:
    canonical, oda, _ = _files(tmp_path)
    repository = KnowledgeRepository(
        canonical_path=canonical,
        oda_path=oda,
    )

    results = repository.search_lexical("agua")

    assert len(results) == 1
    assert results[0]["puinave"] == "WAI"


def test_SPT_004A_relaciona_oda(tmp_path: Path) -> None:
    canonical, oda, _ = _files(tmp_path)
    repository = KnowledgeRepository(
        canonical_path=canonical,
        oda_path=oda,
    )

    result = repository.find_oda("LEX-001")

    assert result is not None
    assert result["oda_id"] == "ODA-001"


def test_SPT_004A_responde_con_fuente_validada(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(
            question="¿Cómo se dice agua en Puinave?"
        )
    )

    assert response.found is True
    assert response.validated is True
    assert "WAI" in response.answer
    assert response.sources[0].source_type == (
        "canonical_lexical_repository"
    )


def test_SPT_004A_responde_pregunta_frecuente(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(
            question="¿Cómo buscar una palabra?"
        )
    )

    assert response.found is True
    assert "buscador principal" in response.answer
    assert response.intent == "platform_help"


def test_SPT_004A_no_inventa_respuesta(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(
            question="¿Cuál es la traducción de una palabra inexistente?"
        )
    )

    assert response.found is False
    assert response.validated is False
    assert response.requires_human_review is True
    assert "No encontré una respuesta validada" in response.answer


def test_SPT_004A_registra_pregunta_no_resuelta(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)
    unresolved = tmp_path / "unresolved.jsonl"

    assistant.answer(
        ConsultaAsistente(
            question="Pregunta completamente desconocida",
            session_id="session-test",
        )
    )

    assert unresolved.is_file()
    payload = json.loads(
        unresolved.read_text(encoding="utf-8").strip()
    )
    assert payload["status"] == "pending_human_review"
    assert payload["session_id"] == "session-test"


def test_SPT_004A_rechaza_pregunta_vacia(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(question="   ")
    )

    assert response.intent == "empty"
    assert response.found is False
    assert response.validated is True


def test_SPT_004A_fuentes_no_vacias_en_respuesta_lexica(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(question="AMDA")
    )

    assert response.found is True
    assert len(response.sources) >= 1
    assert all(source.validated for source in response.sources)
'@

$PolicyContent = @'
{
  "increment_code": "SPT-004A",
  "version": "0.1.0",
  "policy_name": "Fundación del Asistente Inteligente Institucional",
  "technical_id": "SPT-004",
  "display_name": "Asistente Virtual SGODA",
  "cultural_name_status": "pending_puinave_validation",
  "generative_ai_enabled": false,
  "validated_sources_only": true,
  "invent_puinave_words": false,
  "unresolved_questions_require_human_review": true,
  "supported_intents": [
    "platform_help",
    "project_information",
    "lexical_search",
    "category_search",
    "learning_activity",
    "unknown"
  ],
  "supported_languages_initial": ["es"],
  "future_languages": ["en", "pui"],
  "governed_by": [
    "SGD-114-v2.0.1",
    "SGD-115-v1.0.1"
  ]
}
'@

$FaqConfigContent = @'
{
  "items": [
    {
      "id": "FAQ-PLATFORM-001",
      "keywords": ["como buscar", "buscar palabra", "encontrar palabra"],
      "answer": "Usa el buscador principal, escribe una palabra en Puinave, español o inglés y selecciona una entrada para consultar su ficha.",
      "suggestions": ["Buscar una palabra", "Escuchar pronunciación"]
    },
    {
      "id": "FAQ-PLATFORM-002",
      "keywords": ["como escuchar", "escuchar audio", "pronunciacion"],
      "answer": "Abre la ficha de la palabra y selecciona el botón de audio correspondiente al idioma disponible.",
      "suggestions": ["Buscar una palabra"]
    },
    {
      "id": "FAQ-PROJECT-001",
      "keywords": ["que es sgoda", "proyecto puinave", "objetivo del proyecto"],
      "answer": "SGODA-PUINAVE es un ecosistema digital orientado a preservar, documentar y apoyar la enseñanza de la lengua Puinave mediante datos léxicos, audios, imágenes y objetos digitales de aprendizaje.",
      "suggestions": ["Conocer el diccionario", "Buscar una palabra"]
    },
    {
      "id": "FAQ-CULTURE-001",
      "keywords": ["nombre del robot", "nombre del asistente"],
      "answer": "El asistente conserva temporalmente un nombre técnico. Su nombre oficial será una palabra en Puinave validada lingüística y culturalmente por la comunidad.",
      "suggestions": ["Conocer el proyecto"]
    }
  ]
}
'@

$IdentityContent = @'
{
  "technical_id": "SPT-004",
  "internal_name": "InstitutionalIntelligentAssistant",
  "temporary_display_name": "Asistente Virtual SGODA",
  "official_puinave_name": null,
  "official_name_status": "pending_linguistic_and_cultural_validation",
  "naming_principles": [
    "do_not_invent_puinave_terms",
    "community_validation_required",
    "preserve_technical_traceability",
    "update_visible_identity_without_changing_technical_id"
  ]
}
'@

$ComponentContent = @'
{
  "increment_code": "SPT-004A",
  "name": "Fundación del Asistente Inteligente Institucional",
  "component_type": "institutional_intelligent_assistant",
  "version": "0.1.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.assistant.cli",
  "source": [
    "src/sgoda/assistant/models.py",
    "src/sgoda/assistant/intent_classifier.py",
    "src/sgoda/assistant/knowledge_repository.py",
    "src/sgoda/assistant/faq.py",
    "src/sgoda/assistant/service.py",
    "src/sgoda/assistant/cli.py"
  ],
  "tests": [
    "tests/assistant/test_SPT_004A_institutional_assistant.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SPT-004/SPT-004A-Fundacion-Asistente-Institucional.md",
    "docs/05_Fase_Tecnologica/SPT-004/SPT-004A-Seguridad-Linguistica-Cultural.md",
    "docs/05_Fase_Tecnologica/SPT-004/SPT-004A-Identidad-Cultural-Pendiente.md"
  ],
  "governed_by": [
    "SGD-114-v2.0.1",
    "SGD-115-v1.0.1"
  ]
}
'@

$DocContent = @'
# SPT-004A — Fundación del Asistente Inteligente Institucional

## Objetivo

Crear el núcleo seguro del asistente de SGODA-PUINAVE para responder
preguntas usando exclusivamente conocimiento institucional validado.

## Capacidades iniciales

- ayuda sobre el uso de la plataforma;
- información institucional;
- búsqueda léxica;
- búsqueda por categorías;
- consulta relacionada con ODA;
- respuestas con fuentes;
- registro de preguntas no resueltas;
- sugerencias de navegación y aprendizaje.

## Restricciones

- no se inventan palabras Puinave;
- no se generan traducciones no validadas;
- la IA generativa permanece deshabilitada;
- las respuestas sin evidencia pasan a revisión humana;
- el nombre cultural oficial permanece pendiente.

## Próximos incrementos

- SPT-004B: API conversacional FastAPI.
- SPT-004C: recuperación multimedia y actividades.
- SPT-004D: interfaz visual del robot en Flutter.
- SPT-004E: IA conversacional controlada.
- SPT-004H: identidad cultural y nombre oficial Puinave.
'@

$SafetyContent = @'
# SPT-004A — Seguridad Lingüística y Cultural

El asistente responde únicamente desde fuentes institucionales.

Reglas obligatorias:

1. No inventar palabras ni traducciones Puinave.
2. Identificar las fuentes usadas.
3. Marcar respuestas validadas y no validadas.
4. Registrar preguntas sin respuesta.
5. Requerir revisión humana para contenido nuevo.
6. No sustituir a hablantes, docentes ni autoridades culturales.
7. No publicar automáticamente contenido cultural propuesto por IA.
8. Mantener trazabilidad hasta el RLB, ODA o documento utilizado.

La respuesta segura predeterminada informa que no existe una respuesta
validada y remite la consulta a revisión.
'@

$IdentityDocContent = @'
# SPT-004A — Identidad Cultural Pendiente

El identificador técnico permanente es `SPT-004`.

Durante el desarrollo se utiliza el nombre visible temporal:

`Asistente Virtual SGODA`

El nombre oficial deberá ser una palabra en lengua Puinave y solo será
incorporado después de:

1. propuesta de hablantes o autoridades culturales;
2. revisión lingüística;
3. validación de significado y pronunciación;
4. aprobación comunitaria;
5. documentación de la decisión;
6. actualización de Flutter, API, manuales y SGD-115.

No se seleccionará ni generará automáticamente un nombre Puinave.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Question
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.assistant.cli $Question

if ($LASTEXITCODE -ne 0) {
    throw "SPT-004A terminó con errores."
}
'@

Write-Step "Instalando SPT-004A"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $IntentPath -Content $IntentContent
Write-Utf8NoBom -Path $RepositoryPath -Content $RepositoryContent
Write-Utf8NoBom -Path $FaqPath -Content $FaqContent
Write-Utf8NoBom -Path $ServicePath -Content $ServiceContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent

Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $FaqConfigPath -Content $FaqConfigContent
Write-Utf8NoBom -Path $IdentityPath -Content $IdentityContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent

Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $SafetyPath -Content $SafetyContent
Write-Utf8NoBom -Path $IdentityDocPath -Content $IdentityDocContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Evidence = [ordered]@{
    increment_code = "SPT-004A"
    technical_id = "SPT-004"
    version = "0.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    temporary_display_name = "Asistente Virtual SGODA"
    official_puinave_name = $null
    cultural_name_status = "pending_validation"
    generative_ai_enabled = $false
    validated_sources_only = $true
    source_repositories = @(
        "artifacts/rlb/SPT-001B-P08/canonical-repository-v1.0.0.json",
        "artifacts/oda/SPT-002/oda-repository-v0.1.0.json"
    )
}
Write-JsonUtf8 -Path $EvidencePath -Data $Evidence

$Trace = [ordered]@{
    increment_code = "SPT-004A"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/assistant/"
    )
    tests = @(
        "tests/assistant/test_SPT_004A_institutional_assistant.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-004/SPT-004A-Fundacion-Asistente-Institucional.md",
        "docs/05_Fase_Tecnologica/SPT-004/SPT-004A-Seguridad-Linguistica-Cultural.md",
        "docs/05_Fase_Tecnologica/SPT-004/SPT-004A-Identidad-Cultural-Pendiente.md"
    )
    evidence = @(
        "artifacts/pmo/SPT-004A/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando sintaxis e importaciones"

& python -m py_compile `
    "src/sgoda/assistant/models.py" `
    "src/sgoda/assistant/intent_classifier.py" `
    "src/sgoda/assistant/knowledge_repository.py" `
    "src/sgoda/assistant/faq.py" `
    "src/sgoda/assistant/service.py" `
    "src/sgoda/assistant/cli.py"

if ($LASTEXITCODE -ne 0) {
    throw "La compilación de SPT-004A falló."
}

& python -c "from sgoda.assistant import InstitutionalAssistant, KnowledgeRepository, classify_intent; print(InstitutionalAssistant.__name__, KnowledgeRepository.__name__, classify_intent.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SPT-004A."
}

Write-Step "Ejecutando 10 pruebas específicas SPT-004A"

& python -m pytest `
    "tests/assistant/test_SPT_004A_institutional_assistant.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPT-004A fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Ejecutando demostración institucional"

& python -m sgoda.assistant.cli `
    "¿Qué es SGODA-PUINAVE?" `
    --output "artifacts/assistant/SPT-004A/demo-response.json"

if ($LASTEXITCODE -ne 0) {
    throw "La demostración institucional SPT-004A falló."
}

$DemoPath = Join-Path $ArtifactsDir "demo-response.json"
Assert-Path -Path $DemoPath -Description "demo-response.json"

$Demo = Get-Content -LiteralPath $DemoPath -Raw |
    ConvertFrom-Json

if (-not $Demo.validated) {
    throw "La demostración debe producir una respuesta validada."
}

if (@($Demo.sources).Count -le 0) {
    throw "La demostración debe incluir fuentes."
}

Write-Step "Publicando release técnico"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

foreach ($Artifact in @(
    $DemoPath,
    $PolicyPath,
    $FaqConfigPath,
    $IdentityPath,
    $ComponentPath,
    $DocPath,
    $SafetyPath,
    $IdentityDocPath
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
    --increment "SPT-004A" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SPT-004A no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "SPT-004A no contiene passed=true."
}

$Dashboard = [ordered]@{
    increment_code = "SPT-004A"
    technical_id = "SPT-004"
    version = "0.1.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    temporary_display_name = "Asistente Virtual SGODA"
    cultural_name = "pending_puinave_validation"
    generative_ai_enabled = $false
    validated_sources_only = $true
    supported_intents = 6
    initial_languages = @("es")
    future_languages = @("en", "pui")
    specific_tests = 10
    expected_total_tests = 149
    demo_validated = [bool]$Demo.validated
    demo_sources = @($Demo.sources).Count
    quality_gate = "approved"
    release = "SPT-004A-v0.1.0"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Actualizando documentación maestra SGD-115"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La actualización documental SGD-115 falló."
}

Write-Step "Resultado final"

Write-Host "SPT-004A implementado y validado." -ForegroundColor Green
Write-Host "Asistente Inteligente Institucional: FUNDACIÓN OPERATIVA." -ForegroundColor Green
Write-Host "Pruebas específicas: 10 APROBADAS." -ForegroundColor Green
Write-Host "Suite total esperada desde 139: 149 pruebas." -ForegroundColor Cyan
Write-Host "Respuesta institucional demostrativa: APROBADA." -ForegroundColor Green
Write-Host "Respuestas con fuentes: IMPLEMENTADAS." -ForegroundColor Green
Write-Host "No invención lingüística: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Preguntas no resueltas: REGISTRADAS PARA REVISIÓN." -ForegroundColor Green
Write-Host "IA generativa: DESHABILITADA." -ForegroundColor Yellow
Write-Host "Nombre oficial Puinave: PENDIENTE DE VALIDACIÓN." -ForegroundColor Yellow
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SPT-004A-v0.1.0" -ForegroundColor Cyan
