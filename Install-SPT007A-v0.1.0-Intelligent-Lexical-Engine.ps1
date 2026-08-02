<#
.SYNOPSIS
    Instala SPT-007A v0.1.0 — Fundación del Motor Léxico Inteligente.

.DESCRIPTION
    Implementa la primera entrega funcional de SPT-007 dentro de la
    Fase Tecnológica de SGODA-PUINAVE.

    Incluye:
      - modelos léxicos canónicos;
      - normalización Unicode;
      - búsqueda exacta;
      - búsqueda por prefijo y contenido;
      - búsqueda tolerante mediante distancia de edición;
      - ranking determinista;
      - respuesta multilingüe Puinave, español, inglés americano e italiano;
      - asociación de audio, imagen y video;
      - repositorio JSON compatible con RLB;
      - servicio y CLI;
      - pruebas específicas;
      - suite completa;
      - evaluación SGD-114C;
      - actualización SGD-115;
      - regeneración SGD-116;
      - evidencia y release técnico.

    El motor no inventa palabras ni traducciones Puinave. Solo devuelve
    información contenida en el RLB o en fuentes explícitamente cargadas.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.

.PARAMETER SampleLimit
    Cantidad máxima de registros del RLB usados en la demostración.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [int]$SampleLimit = 80
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
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

function Write-Json {
    param([string]$Path, [object]$Value)

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Checked {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    Write-Step $Description
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\lexical_engine"
$TestsDir = Join-Path $ProjectRoot "tests\lexical_engine"
$ConfigDir = Join-Path $ProjectRoot "config\lexical_engine"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-007"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\lexical_engine\SPT-007A"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-007A"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-007A-v0.1.0"

$ModelsPath = Join-Path $SourceDir "models.py"
$NormalizerPath = Join-Path $SourceDir "normalizer.py"
$RepositoryPath = Join-Path $SourceDir "repository.py"
$SearchPath = Join-Path $SourceDir "search.py"
$RankingPath = Join-Path $SourceDir "ranking.py"
$MultimediaPath = Join-Path $SourceDir "multimedia.py"
$ServicePath = Join-Path $SourceDir "service.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path $TestsDir "test_SPT_007A_intelligent_lexical_engine.py"
$PolicyPath = Join-Path $ConfigDir "SPT-007A-lexical-policy.json"
$ComponentPath = Join-Path $ConfigDir "SPT-007A-component.json"
$DocPath = Join-Path $DocsDir "SPT-007A-Fundacion-Motor-Lexico-Inteligente.md"
$ArchitecturePath = Join-Path $DocsDir "SPT-007A-Arquitectura-Busqueda-Ranking.md"
$CulturalPath = Join-Path $DocsDir "SPT-007A-Seguridad-Linguistica-Cultural.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT007A-LexicalEngine.ps1"

$DemoPath = Join-Path $ArtifactsDir "demo-search.json"
$EvidencePath = Join-Path $PmoDir "SPT-007A-implementation-evidence.json"
$GateJson = Join-Path $PmoDir "SPT-007A-policy-result.json"
$GateMd = Join-Path $PmoDir "SPT-007A-policy-result.md"

$BackupDir = Join-Path $PmoDir (
    "backups\pre-SPT007A-" +
    [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
)

Write-Step "Validando línea base tecnológica"

foreach ($Path in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\governance\policy_cli.py"),
    (Join-Path $ProjectRoot "config\governance\SGD-114C-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File -Path $Path
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Path in @(
    $ModelsPath,
    $NormalizerPath,
    $RepositoryPath,
    $SearchPath,
    $RankingPath,
    $MultimediaPath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $PolicyPath,
    $ComponentPath,
    $DocPath,
    $ArchitecturePath,
    $CulturalPath,
    $InvokePath
)) {
    if (Test-Path -LiteralPath $Path) {
        Copy-Item `
            -LiteralPath $Path `
            -Destination (Join-Path $BackupDir (Split-Path $Path -Leaf)) `
            -Force
    }
}

$Models = @'
"""Modelos canónicos del Motor Léxico Inteligente SPT-007A."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


SUPPORTED_LANGUAGES = ("pu", "es", "en-US", "it")


@dataclass(frozen=True, slots=True)
class MultimediaResource:
    resource_type: str
    language: str | None
    path: str
    validated: bool = False
    autoplay: bool = False
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LexicalEntry:
    entry_id: str
    puinave: str
    spanish: str = ""
    english_us: str = ""
    italian: str = ""
    category: str = ""
    validated: bool = False
    cultural_status: str = "pending"
    multimedia: tuple[MultimediaResource, ...] = ()
    metadata: dict[str, Any] = field(default_factory=dict)

    def text_by_language(self) -> dict[str, str]:
        return {
            "pu": self.puinave,
            "es": self.spanish,
            "en-US": self.english_us,
            "it": self.italian,
        }


@dataclass(frozen=True, slots=True)
class SearchQuery:
    text: str
    languages: tuple[str, ...] = SUPPORTED_LANGUAGES
    limit: int = 20
    include_unvalidated: bool = True
    category: str | None = None
    fuzzy: bool = True


@dataclass(frozen=True, slots=True)
class SearchHit:
    entry: LexicalEntry
    score: float
    match_type: str
    matched_language: str
    matched_text: str
    normalized_query: str
    normalized_text: str


@dataclass(frozen=True, slots=True)
class SearchResponse:
    query: SearchQuery
    total: int
    hits: tuple[SearchHit, ...]
    no_invention: bool = True
'@

$Normalizer = @'
"""Normalización Unicode y lingüística segura."""

from __future__ import annotations

import re
import unicodedata


_WHITESPACE = re.compile(r"\s+")
_NON_WORD = re.compile(r"[^\w\s-]", re.UNICODE)


def normalize_text(value: str) -> str:
    text = unicodedata.normalize("NFKC", str(value or ""))
    text = text.casefold().strip()
    text = _NON_WORD.sub(" ", text)
    text = _WHITESPACE.sub(" ", text)
    return text


def compact_text(value: str) -> str:
    return normalize_text(value).replace(" ", "")


def tokenize(value: str) -> tuple[str, ...]:
    normalized = normalize_text(value)
    return tuple(token for token in normalized.split(" ") if token)


def levenshtein_distance(left: str, right: str) -> int:
    a = normalize_text(left)
    b = normalize_text(right)

    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)

    previous = list(range(len(b) + 1))

    for index_a, char_a in enumerate(a, start=1):
        current = [index_a]

        for index_b, char_b in enumerate(b, start=1):
            insert_cost = current[index_b - 1] + 1
            delete_cost = previous[index_b] + 1
            replace_cost = previous[index_b - 1] + (
                0 if char_a == char_b else 1
            )

            current.append(
                min(insert_cost, delete_cost, replace_cost)
            )

        previous = current

    return previous[-1]


def similarity(left: str, right: str) -> float:
    a = normalize_text(left)
    b = normalize_text(right)

    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0

    distance = levenshtein_distance(a, b)
    maximum = max(len(a), len(b))
    return max(0.0, 1.0 - (distance / maximum))
'@

$Repository = @'
"""Repositorio léxico de solo lectura compatible con RLB JSON."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import LexicalEntry, MultimediaResource


def _first(payload: dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = payload.get(key)

        if value is not None and str(value).strip():
            return str(value).strip()

    return ""


def _bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value

    return str(value).strip().casefold() in {
        "1",
        "true",
        "yes",
        "si",
        "sí",
        "validated",
        "approved",
        "aprobado",
    }


def _multimedia(payload: dict[str, Any]) -> tuple[MultimediaResource, ...]:
    resources: list[MultimediaResource] = []

    raw = payload.get("multimedia") or payload.get("resources") or []

    if isinstance(raw, dict):
        raw = [
            {
                "resource_type": key,
                "path": value,
            }
            for key, value in raw.items()
            if value
        ]

    if isinstance(raw, list):
        for item in raw:
            if not isinstance(item, dict):
                continue

            path = _first(item, "path", "url", "file")

            if not path:
                continue

            resources.append(
                MultimediaResource(
                    resource_type=_first(
                        item,
                        "resource_type",
                        "type",
                        "kind",
                    )
                    or "unknown",
                    language=_first(
                        item,
                        "language",
                        "locale",
                    )
                    or None,
                    path=path,
                    validated=_bool(
                        item.get("validated", False)
                    ),
                    autoplay=_bool(
                        item.get("autoplay", False)
                    ),
                    metadata={
                        key: value
                        for key, value in item.items()
                        if key
                        not in {
                            "resource_type",
                            "type",
                            "kind",
                            "language",
                            "locale",
                            "path",
                            "url",
                            "file",
                            "validated",
                            "autoplay",
                        }
                    },
                )
            )

    direct_fields = (
        ("audio_puinave", "audio", "pu"),
        ("audio_spanish", "audio", "es"),
        ("audio_es", "audio", "es"),
        ("audio_english", "audio", "en-US"),
        ("audio_en", "audio", "en-US"),
        ("audio_italian", "audio", "it"),
        ("audio_it", "audio", "it"),
        ("image", "image", None),
        ("imagen", "image", None),
        ("video", "video", None),
    )

    known = {(item.resource_type, item.language, item.path) for item in resources}

    for field_name, resource_type, language in direct_fields:
        value = payload.get(field_name)

        if value and (
            resource_type,
            language,
            str(value),
        ) not in known:
            resources.append(
                MultimediaResource(
                    resource_type=resource_type,
                    language=language,
                    path=str(value),
                    validated=_bool(
                        payload.get(f"{field_name}_validated", False)
                    ),
                    autoplay=(
                        resource_type == "audio"
                        and language in {"es", "en-US", "it"}
                    ),
                )
            )

    return tuple(resources)


def entry_from_dict(
    payload: dict[str, Any],
    index: int,
) -> LexicalEntry:
    entry_id = _first(
        payload,
        "entry_id",
        "id",
        "lexical_id",
        "codigo",
        "code",
    ) or f"LEX-{index:06d}"

    puinave = _first(
        payload,
        "puinave",
        "native",
        "word",
        "palabra_puinave",
        "termino_puinave",
    )

    spanish = _first(
        payload,
        "spanish",
        "es",
        "espanol",
        "español",
        "traduccion_es",
    )

    english = _first(
        payload,
        "english_us",
        "english",
        "en-US",
        "en",
        "traduccion_en",
    )

    italian = _first(
        payload,
        "italian",
        "it",
        "italiano",
        "traduccion_it",
    )

    return LexicalEntry(
        entry_id=entry_id,
        puinave=puinave,
        spanish=spanish,
        english_us=english,
        italian=italian,
        category=_first(
            payload,
            "category",
            "categoria",
            "class",
        ),
        validated=_bool(
            payload.get(
                "validated",
                payload.get("validado", False),
            )
        ),
        cultural_status=_first(
            payload,
            "cultural_status",
            "estado_cultural",
        )
        or "pending",
        multimedia=_multimedia(payload),
        metadata={
            key: value
            for key, value in payload.items()
            if key
            not in {
                "entry_id",
                "id",
                "lexical_id",
                "codigo",
                "code",
                "puinave",
                "native",
                "word",
                "palabra_puinave",
                "termino_puinave",
                "spanish",
                "es",
                "espanol",
                "español",
                "traduccion_es",
                "english_us",
                "english",
                "en-US",
                "en",
                "traduccion_en",
                "italian",
                "it",
                "italiano",
                "traduccion_it",
                "category",
                "categoria",
                "class",
                "validated",
                "validado",
                "cultural_status",
                "estado_cultural",
                "multimedia",
                "resources",
            }
        },
    )


class LexicalRepository:
    def __init__(self, entries: list[LexicalEntry]) -> None:
        self._entries = tuple(entries)

    @classmethod
    def from_json(cls, path: str | Path) -> "LexicalRepository":
        target = Path(path)
        payload = json.loads(
            target.read_text(encoding="utf-8-sig")
        )

        if isinstance(payload, dict):
            raw_entries = (
                payload.get("entries")
                or payload.get("records")
                or payload.get("words")
                or payload.get("palabras")
                or []
            )
        else:
            raw_entries = payload

        if not isinstance(raw_entries, list):
            raise ValueError(
                "El archivo RLB debe contener una lista de registros."
            )

        entries = [
            entry_from_dict(item, index)
            for index, item in enumerate(raw_entries, start=1)
            if isinstance(item, dict)
        ]

        return cls(entries)

    @classmethod
    def from_records(
        cls,
        records: list[dict[str, Any]],
    ) -> "LexicalRepository":
        return cls(
            [
                entry_from_dict(item, index)
                for index, item in enumerate(records, start=1)
            ]
        )

    def all(self) -> tuple[LexicalEntry, ...]:
        return self._entries

    def __len__(self) -> int:
        return len(self._entries)
'@

$Ranking = @'
"""Ranking determinista del Motor Léxico Inteligente."""

from __future__ import annotations

from .models import SearchHit


MATCH_WEIGHTS = {
    "exact": 100.0,
    "prefix": 85.0,
    "token": 75.0,
    "contains": 65.0,
    "fuzzy": 50.0,
}


LANGUAGE_WEIGHTS = {
    "pu": 4.0,
    "es": 3.0,
    "en-US": 2.0,
    "it": 1.0,
}


def calculate_score(
    match_type: str,
    language: str,
    similarity_score: float,
    validated: bool,
    multimedia_count: int,
) -> float:
    score = MATCH_WEIGHTS.get(match_type, 0.0)
    score += LANGUAGE_WEIGHTS.get(language, 0.0)
    score += max(0.0, min(1.0, similarity_score)) * 10.0
    score += 2.0 if validated else 0.0
    score += min(multimedia_count, 5) * 0.25
    return round(score, 6)


def sort_hits(hits: list[SearchHit]) -> tuple[SearchHit, ...]:
    return tuple(
        sorted(
            hits,
            key=lambda hit: (
                -hit.score,
                hit.entry.entry_id,
                hit.matched_language,
                hit.matched_text.casefold(),
            ),
        )
    )
'@

$Search = @'
"""Búsqueda exacta, parcial y tolerante."""

from __future__ import annotations

from .models import SearchHit, SearchQuery, SearchResponse
from .normalizer import normalize_text, similarity, tokenize
from .ranking import calculate_score, sort_hits
from .repository import LexicalRepository


class LexicalSearchEngine:
    def __init__(
        self,
        repository: LexicalRepository,
        fuzzy_threshold: float = 0.72,
    ) -> None:
        self.repository = repository
        self.fuzzy_threshold = fuzzy_threshold

    def search(self, query: SearchQuery) -> SearchResponse:
        normalized_query = normalize_text(query.text)

        if not normalized_query:
            return SearchResponse(
                query=query,
                total=0,
                hits=(),
            )

        hits: list[SearchHit] = []

        for entry in self.repository.all():
            if (
                not query.include_unvalidated
                and not entry.validated
            ):
                continue

            if query.category and (
                normalize_text(entry.category)
                != normalize_text(query.category)
            ):
                continue

            best: SearchHit | None = None

            for language, original_text in entry.text_by_language().items():
                if language not in query.languages:
                    continue

                if not original_text:
                    continue

                normalized_text = normalize_text(original_text)
                match_type = ""
                similarity_score = 0.0

                if normalized_text == normalized_query:
                    match_type = "exact"
                    similarity_score = 1.0
                elif normalized_text.startswith(normalized_query):
                    match_type = "prefix"
                    similarity_score = (
                        len(normalized_query)
                        / max(len(normalized_text), 1)
                    )
                elif normalized_query in tokenize(normalized_text):
                    match_type = "token"
                    similarity_score = 0.9
                elif normalized_query in normalized_text:
                    match_type = "contains"
                    similarity_score = (
                        len(normalized_query)
                        / max(len(normalized_text), 1)
                    )
                elif query.fuzzy:
                    similarity_score = similarity(
                        normalized_query,
                        normalized_text,
                    )

                    if similarity_score >= self.fuzzy_threshold:
                        match_type = "fuzzy"

                if not match_type:
                    continue

                score = calculate_score(
                    match_type=match_type,
                    language=language,
                    similarity_score=similarity_score,
                    validated=entry.validated,
                    multimedia_count=len(entry.multimedia),
                )

                candidate = SearchHit(
                    entry=entry,
                    score=score,
                    match_type=match_type,
                    matched_language=language,
                    matched_text=original_text,
                    normalized_query=normalized_query,
                    normalized_text=normalized_text,
                )

                if best is None or candidate.score > best.score:
                    best = candidate

            if best is not None:
                hits.append(best)

        ordered = sort_hits(hits)
        limited = ordered[: max(1, query.limit)]

        return SearchResponse(
            query=query,
            total=len(ordered),
            hits=limited,
        )
'@

$Multimedia = @'
"""Selección gobernada de recursos multimedia."""

from __future__ import annotations

from .models import LexicalEntry, MultimediaResource


def resources_for_entry(
    entry: LexicalEntry,
    language: str | None = None,
    validated_only: bool = False,
) -> tuple[MultimediaResource, ...]:
    resources = []

    for resource in entry.multimedia:
        if validated_only and not resource.validated:
            continue

        if (
            language is not None
            and resource.language not in {None, language}
        ):
            continue

        resources.append(resource)

    return tuple(
        sorted(
            resources,
            key=lambda item: (
                item.resource_type,
                item.language or "",
                item.path,
            ),
        )
    )


def playback_manifest(entry: LexicalEntry) -> dict:
    audios = [
        resource
        for resource in resources_for_entry(entry)
        if resource.resource_type == "audio"
    ]

    images = [
        resource
        for resource in resources_for_entry(entry)
        if resource.resource_type == "image"
    ]

    videos = [
        resource
        for resource in resources_for_entry(entry)
        if resource.resource_type == "video"
    ]

    return {
        "entry_id": entry.entry_id,
        "autoplay_audio": [
            {
                "language": item.language,
                "path": item.path,
                "validated": item.validated,
            }
            for item in audios
            if item.autoplay
        ],
        "images": [
            {
                "path": item.path,
                "validated": item.validated,
            }
            for item in images
        ],
        "videos": [
            {
                "path": item.path,
                "validated": item.validated,
                "autoplay": False,
            }
            for item in videos
        ],
    }
'@

$Service = @'
"""Servicio de aplicación para SPT-007A."""

from __future__ import annotations

from .models import SearchQuery
from .multimedia import playback_manifest
from .repository import LexicalRepository
from .search import LexicalSearchEngine


class IntelligentLexicalService:
    def __init__(
        self,
        repository: LexicalRepository,
        fuzzy_threshold: float = 0.72,
    ) -> None:
        self.repository = repository
        self.engine = LexicalSearchEngine(
            repository,
            fuzzy_threshold=fuzzy_threshold,
        )

    def search(
        self,
        text: str,
        languages: tuple[str, ...] = (
            "pu",
            "es",
            "en-US",
            "it",
        ),
        limit: int = 20,
        include_unvalidated: bool = True,
        category: str | None = None,
        fuzzy: bool = True,
    ) -> dict:
        response = self.engine.search(
            SearchQuery(
                text=text,
                languages=languages,
                limit=limit,
                include_unvalidated=include_unvalidated,
                category=category,
                fuzzy=fuzzy,
            )
        )

        return {
            "query": response.query.text,
            "languages": list(response.query.languages),
            "total": response.total,
            "no_invention": response.no_invention,
            "results": [
                {
                    "entry_id": hit.entry.entry_id,
                    "score": hit.score,
                    "match_type": hit.match_type,
                    "matched_language": hit.matched_language,
                    "matched_text": hit.matched_text,
                    "puinave": hit.entry.puinave,
                    "spanish": hit.entry.spanish,
                    "english_us": hit.entry.english_us,
                    "italian": hit.entry.italian,
                    "category": hit.entry.category,
                    "validated": hit.entry.validated,
                    "cultural_status": hit.entry.cultural_status,
                    "playback": playback_manifest(hit.entry),
                }
                for hit in response.hits
            ],
        }
'@

$Cli = @'
"""CLI de SPT-007A."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .repository import LexicalRepository
from .service import IntelligentLexicalService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rlb", required=True)
    parser.add_argument("--query", required=True)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument(
        "--languages",
        default="pu,es,en-US,it",
    )
    parser.add_argument("--output")
    parser.add_argument(
        "--validated-only",
        action="store_true",
    )
    parser.add_argument(
        "--no-fuzzy",
        action="store_true",
    )
    args = parser.parse_args()

    repository = LexicalRepository.from_json(args.rlb)
    service = IntelligentLexicalService(repository)

    result = service.search(
        text=args.query,
        languages=tuple(
            item.strip()
            for item in args.languages.split(",")
            if item.strip()
        ),
        limit=args.limit,
        include_unvalidated=not args.validated_only,
        fuzzy=not args.no_fuzzy,
    )

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
"""SPT-007A — Motor Léxico Inteligente."""

from .models import (
    LexicalEntry,
    MultimediaResource,
    SearchHit,
    SearchQuery,
    SearchResponse,
)
from .multimedia import playback_manifest, resources_for_entry
from .normalizer import (
    levenshtein_distance,
    normalize_text,
    similarity,
    tokenize,
)
from .repository import LexicalRepository, entry_from_dict
from .search import LexicalSearchEngine
from .service import IntelligentLexicalService

__all__ = [
    "IntelligentLexicalService",
    "LexicalEntry",
    "LexicalRepository",
    "LexicalSearchEngine",
    "MultimediaResource",
    "SearchHit",
    "SearchQuery",
    "SearchResponse",
    "entry_from_dict",
    "levenshtein_distance",
    "normalize_text",
    "playback_manifest",
    "resources_for_entry",
    "similarity",
    "tokenize",
]
'@

$Tests = @'
import json
from pathlib import Path

from sgoda.lexical_engine import (
    IntelligentLexicalService,
    LexicalRepository,
    SearchQuery,
    normalize_text,
    playback_manifest,
)
from sgoda.lexical_engine.search import LexicalSearchEngine


def _repository() -> LexicalRepository:
    return LexicalRepository.from_records(
        [
            {
                "id": "LEX-001",
                "puinave": "AMDA",
                "spanish": "casa",
                "english_us": "house",
                "italian": "casa",
                "validated": True,
                "category": "sustantivo",
                "multimedia": [
                    {
                        "type": "audio",
                        "language": "es",
                        "path": "media/audio/es/LEX-001.wav",
                        "validated": True,
                        "autoplay": True,
                    },
                    {
                        "type": "image",
                        "path": "media/images/LEX-001.webp",
                        "validated": True,
                    },
                ],
            },
            {
                "id": "LEX-002",
                "puinave": "DAPA",
                "spanish": "agua",
                "english_us": "water",
                "italian": "acqua",
                "validated": False,
                "category": "sustantivo",
            },
        ]
    )


def test_SPT_007A_normalizes_unicode_and_case() -> None:
    assert normalize_text("  CÁSÁ  ") == "cásá"


def test_SPT_007A_exact_search() -> None:
    engine = LexicalSearchEngine(_repository())
    result = engine.search(SearchQuery("AMDA"))

    assert result.total == 1
    assert result.hits[0].entry.entry_id == "LEX-001"
    assert result.hits[0].match_type == "exact"
    assert result.hits[0].matched_language == "pu"


def test_SPT_007A_multilingual_search() -> None:
    service = IntelligentLexicalService(_repository())
    result = service.search("house")

    assert result["total"] == 1
    assert result["results"][0]["puinave"] == "AMDA"
    assert result["results"][0]["english_us"] == "house"


def test_SPT_007A_prefix_search() -> None:
    engine = LexicalSearchEngine(_repository())
    result = engine.search(SearchQuery("wat"))

    assert result.hits[0].entry.entry_id == "LEX-002"
    assert result.hits[0].match_type == "prefix"


def test_SPT_007A_fuzzy_search() -> None:
    engine = LexicalSearchEngine(
        _repository(),
        fuzzy_threshold=0.60,
    )
    result = engine.search(SearchQuery("hous"))

    assert result.hits[0].entry.entry_id == "LEX-001"


def test_SPT_007A_can_filter_unvalidated() -> None:
    engine = LexicalSearchEngine(_repository())
    result = engine.search(
        SearchQuery(
            "agua",
            include_unvalidated=False,
        )
    )

    assert result.total == 0


def test_SPT_007A_ranking_is_deterministic() -> None:
    engine = LexicalSearchEngine(_repository())
    first = engine.search(SearchQuery("casa"))
    second = engine.search(SearchQuery("casa"))

    assert first.hits == second.hits
    assert first.hits[0].entry.entry_id == "LEX-001"


def test_SPT_007A_multimedia_manifest() -> None:
    entry = _repository().all()[0]
    manifest = playback_manifest(entry)

    assert manifest["entry_id"] == "LEX-001"
    assert manifest["autoplay_audio"][0]["language"] == "es"
    assert manifest["images"][0]["validated"] is True


def test_SPT_007A_reads_json_rlb(tmp_path: Path) -> None:
    path = tmp_path / "words.json"
    path.write_text(
        json.dumps(
            {
                "entries": [
                    {
                        "id": "LEX-003",
                        "puinave": "KADA",
                        "spanish": "sol",
                        "english": "sun",
                        "italian": "sole",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )

    repository = LexicalRepository.from_json(path)

    assert len(repository) == 1
    assert repository.all()[0].english_us == "sun"


def test_SPT_007A_no_invention_contract() -> None:
    service = IntelligentLexicalService(_repository())
    result = service.search("palabra inexistente")

    assert result["total"] == 0
    assert result["no_invention"] is True
    assert result["results"] == []
'@

$Policy = @'
{
  "component": "SPT-007A",
  "version": "0.1.0",
  "name": "Fundación del Motor Léxico Inteligente",
  "supported_languages": [
    "pu",
    "es",
    "en-US",
    "it"
  ],
  "search_modes": [
    "exact",
    "prefix",
    "token",
    "contains",
    "fuzzy"
  ],
  "fuzzy_threshold": 0.72,
  "default_limit": 20,
  "maximum_limit": 100,
  "no_invention": true,
  "puinave_generation": false,
  "requires_cultural_validation": true,
  "video_autoplay": false,
  "local_first": true,
  "paid_services_required": false
}
'@

$Component = @'
{
  "increment_code": "SPT-007A",
  "name": "Fundación del Motor Léxico Inteligente",
  "component_type": "intelligent_lexical_engine",
  "version": "0.1.0",
  "status": "implemented",
  "phase": "Fase Tecnológica",
  "dependencies": [
    "SPT-001B",
    "SPT-003A",
    "SPT-004A",
    "SPT-006",
    "SPT-006A",
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/lexical_engine/models.py",
    "src/sgoda/lexical_engine/normalizer.py",
    "src/sgoda/lexical_engine/repository.py",
    "src/sgoda/lexical_engine/search.py",
    "src/sgoda/lexical_engine/ranking.py",
    "src/sgoda/lexical_engine/multimedia.py",
    "src/sgoda/lexical_engine/service.py",
    "src/sgoda/lexical_engine/cli.py"
  ],
  "tests": [
    "tests/lexical_engine/test_SPT_007A_intelligent_lexical_engine.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007A-Fundacion-Motor-Lexico-Inteligente.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007A-Arquitectura-Busqueda-Ranking.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007A-Seguridad-Linguistica-Cultural.md"
  ]
}
'@

$Doc = @'
# SPT-007A — Fundación del Motor Léxico Inteligente

SPT-007A convierte el Repositorio Léxico Base en un servicio de consulta
multilingüe y trazable.

## Capacidades

- búsqueda exacta;
- búsqueda parcial;
- búsqueda tolerante;
- ranking determinista;
- consulta Puinave, español, inglés americano e italiano;
- recuperación de audio, imagen y video;
- respuesta sin invención;
- preparación para FastAPI, Flutter y el asistente institucional.
'@

$Architecture = @'
# Arquitectura de búsqueda y ranking SPT-007A

El motor separa:

1. repositorio de solo lectura;
2. normalización Unicode;
3. detección del tipo de coincidencia;
4. cálculo determinista de puntuación;
5. selección del mejor idioma coincidente;
6. ordenamiento estable;
7. construcción de respuesta multilingüe;
8. manifiesto de reproducción multimedia.

La prioridad de coincidencia es:

`exact > prefix > token > contains > fuzzy`.
'@

$Cultural = @'
# Seguridad lingüística y cultural SPT-007A

El motor no genera, corrige ni completa vocabulario Puinave.

Cuando una consulta no coincide con el RLB, devuelve una lista vacía y
`no_invention=true`.

Los recursos culturales y lingüísticos conservan sus estados de validación.
El video nunca se reproduce automáticamente.
'@

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Rlb,

    [Parameter(Mandatory = $true)]
    [string]$Query,

    [int]$Limit = 20,

    [string]$Output = "artifacts/lexical_engine/SPT-007A/search-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.lexical_engine.cli `
    --rlb $Rlb `
    --query $Query `
    --limit $Limit `
    --output $Output

exit $LASTEXITCODE
'@

Write-Step "Instalando SPT-007A"

Write-Utf8 $ModelsPath $Models
Write-Utf8 $NormalizerPath $Normalizer
Write-Utf8 $RepositoryPath $Repository
Write-Utf8 $RankingPath $Ranking
Write-Utf8 $SearchPath $Search
Write-Utf8 $MultimediaPath $Multimedia
Write-Utf8 $ServicePath $Service
Write-Utf8 $CliPath $Cli
Write-Utf8 $InitPath $Init
Write-Utf8 $TestPath $Tests
Write-Utf8 $PolicyPath $Policy
Write-Utf8 $ComponentPath $Component
Write-Utf8 $DocPath $Doc
Write-Utf8 $ArchitecturePath $Architecture
Write-Utf8 $CulturalPath $Cultural
Write-Utf8 $InvokePath $Invoke

Invoke-Checked "Validando sintaxis" {
    python -m py_compile `
        "src/sgoda/lexical_engine/models.py" `
        "src/sgoda/lexical_engine/normalizer.py" `
        "src/sgoda/lexical_engine/repository.py" `
        "src/sgoda/lexical_engine/ranking.py" `
        "src/sgoda/lexical_engine/search.py" `
        "src/sgoda/lexical_engine/multimedia.py" `
        "src/sgoda/lexical_engine/service.py" `
        "src/sgoda/lexical_engine/cli.py" `
        "src/sgoda/lexical_engine/__init__.py" `
        "tests/lexical_engine/test_SPT_007A_intelligent_lexical_engine.py"
}

Invoke-Checked "Ejecutando 10 pruebas específicas SPT-007A" {
    python -m pytest `
        "tests/lexical_engine/test_SPT_007A_intelligent_lexical_engine.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Ejecutando demostración controlada"

$DemoRlb = Join-Path $ArtifactsDir "demo-rlb.json"

Write-Json $DemoRlb ([ordered]@{
    entries = @(
        [ordered]@{
            id = "LEX-001"
            puinave = "AMDA"
            spanish = "casa"
            english_us = "house"
            italian = "casa"
            validated = $true
            category = "sustantivo"
            multimedia = @(
                [ordered]@{
                    type = "audio"
                    language = "es"
                    path = "media/audio/es/LEX-001.wav"
                    validated = $true
                    autoplay = $true
                },
                [ordered]@{
                    type = "image"
                    path = "media/images/LEX-001.webp"
                    validated = $true
                }
            )
        }
    )
})

Invoke-Checked "Consultando palabra demostrativa AMDA" {
    python -m sgoda.lexical_engine.cli `
        --rlb "$DemoRlb" `
        --query "AMDA" `
        --limit 5 `
        --output "$DemoPath"
}

$Demo = Get-Content `
    -LiteralPath $DemoPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.total -ne 1) {
    throw "La demostración léxica no devolvió el registro esperado."
}

Write-Step "Regenerando Roadmap Maestro SGD-116"

Invoke-Checked "Actualizando Roadmap" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

$RoadmapValidationPath = Join-Path `
    $ProjectRoot `
    "artifacts\roadmap\SGD-116\validation.json"

Require-File $RoadmapValidationPath

$RoadmapValidation = Get-Content `
    -LiteralPath $RoadmapValidationPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not $RoadmapValidation.passed) {
    throw "El Roadmap Maestro no fue aprobado después de SPT-007A."
}

Write-Step "Evaluando SPT-007A mediante SGD-114C"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json (Join-Path $PmoDir "SPT-007A-pre-gate-evidence.json") ([ordered]@{
    increment_code = "SPT-007A"
    version = "0.1.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    specific_tests = 10
    full_suite_executed = (-not $SkipFullSuite)
    demo_total = $Demo.total
    roadmap_approved = [bool]$RoadmapValidation.passed
})

Copy-Item `
    -LiteralPath $ComponentPath `
    -Destination (Join-Path $ReleaseDir "SPT-007A-component.json") `
    -Force

& python -m sgoda.governance.policy_cli `
    --root "$ProjectRoot" `
    --policy "config/governance/SGD-114C-policy.json" `
    --increment "SPT-007A" `
    --output-json "$GateJson" `
    --output-md "$GateMd"

$GateExitCode = $LASTEXITCODE

Require-File $GateJson
Require-File $GateMd

$Gate = Get-Content `
    -LiteralPath $GateJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($GateExitCode -ne 0 -or -not $Gate.approved) {
    @($Gate.results) |
        Where-Object { $_.blocking } |
        Format-Table rule, name, message, remediation -AutoSize

    throw "SGD-114C no aprobó SPT-007A."
}

Write-Step "Actualizando documentación maestra SGD-115"

Invoke-Checked "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Write-Step "Generando evidencia y release"

Write-Json $EvidencePath ([ordered]@{
    increment_code = "SPT-007A"
    version = "0.1.0"
    status = "implemented"
    phase = "Fase Tecnológica"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    capabilities = @(
        "exact_search",
        "prefix_search",
        "token_search",
        "contains_search",
        "fuzzy_search",
        "deterministic_ranking",
        "multilingual_response",
        "multimedia_manifest",
        "no_invention"
    )
    languages = @("pu", "es", "en-US", "it")
    specific_tests = 10
    full_suite_executed = (-not $SkipFullSuite)
    policy_approved = [bool]$Gate.approved
    policy_exit_code = $Gate.exit_code
    roadmap_approved = [bool]$RoadmapValidation.passed
    demo = $DemoPath
    backup = $BackupDir
})

foreach ($Path in @(
    $ModelsPath,
    $NormalizerPath,
    $RepositoryPath,
    $RankingPath,
    $SearchPath,
    $MultimediaPath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $PolicyPath,
    $ComponentPath,
    $DocPath,
    $ArchitecturePath,
    $CulturalPath,
    $InvokePath,
    $DemoPath,
    $EvidencePath,
    $GateJson,
    $GateMd
)) {
    Require-File $Path

    Copy-Item `
        -LiteralPath $Path `
        -Destination (Join-Path $ReleaseDir (Split-Path $Path -Leaf)) `
        -Force
}

Write-Step "Resultado final"

Write-Host "SPT-007A v0.1.0 implementado." -ForegroundColor Green
Write-Host "Fase Tecnológica: ACTUALIZADA." -ForegroundColor Green
Write-Host "Motor Léxico Inteligente: FUNDACIÓN OPERATIVA." -ForegroundColor Green
Write-Host "Pruebas específicas: 10 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Búsqueda exacta: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Búsqueda parcial: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Búsqueda tolerante: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Ranking determinista: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Puinave, español, inglés americano e italiano: SOPORTADOS." `
    -ForegroundColor Green
Write-Host "Asociación multimedia: IMPLEMENTADA." -ForegroundColor Green
Write-Host "No invención Puinave: IMPLEMENTADA." -ForegroundColor Green
Write-Host "SGD-114C: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO Y APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-007A-v0.1.0" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
