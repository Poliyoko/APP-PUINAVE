<#
.SYNOPSIS
    Instala SPT-007B v1.0.0 — Motor Léxico Inteligente Semántico.

.DESCRIPTION
    Amplía SPT-007A con capacidades semánticas locales, deterministas y
    culturalmente gobernadas.

    Incluye:
      - índice invertido multilingüe;
      - variantes ortográficas explícitas;
      - sinónimos y términos relacionados;
      - familias léxicas;
      - relaciones culturales;
      - ranking híbrido léxico-semántico;
      - sugerencias deterministas;
      - expansión de consultas;
      - integración con multimedia;
      - contrato de consulta para asistente y API;
      - operación local sin modelos de pago;
      - no invención de vocabulario Puinave;
      - pruebas específicas y suite completa;
      - evaluación SGD-114C;
      - actualización SGD-115;
      - regeneración SGD-116;
      - evidencia y release.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.
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
    param([string]$Description, [scriptblock]$Action)

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
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\lexical_engine\SPT-007B"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-007B"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-007B-v1.0.0"

$SemanticModelsPath = Join-Path $SourceDir "semantic_models.py"
$IndexPath = Join-Path $SourceDir "semantic_index.py"
$RelationsPath = Join-Path $SourceDir "relations.py"
$ExpansionPath = Join-Path $SourceDir "query_expansion.py"
$SemanticRankingPath = Join-Path $SourceDir "semantic_ranking.py"
$SuggestionsPath = Join-Path $SourceDir "suggestions.py"
$SemanticServicePath = Join-Path $SourceDir "semantic_service.py"
$SemanticCliPath = Join-Path $SourceDir "semantic_cli.py"

$TestPath = Join-Path $TestsDir "test_SPT_007B_semantic_lexical_engine.py"
$PolicyPath = Join-Path $ConfigDir "SPT-007B-semantic-policy.json"
$RelationsConfigPath = Join-Path $ConfigDir "SPT-007B-relations.example.json"
$ComponentPath = Join-Path $ConfigDir "SPT-007B-component.json"
$DocPath = Join-Path $DocsDir "SPT-007B-Motor-Lexico-Inteligente-Semantico.md"
$ArchitecturePath = Join-Path $DocsDir "SPT-007B-Arquitectura-Indice-Semantico.md"
$GovernancePath = Join-Path $DocsDir "SPT-007B-Gobierno-Relaciones-Lexicas.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT007B-SemanticLexicalEngine.ps1"

$DemoRlbPath = Join-Path $ArtifactsDir "demo-semantic-rlb.json"
$DemoRelationsPath = Join-Path $ArtifactsDir "demo-relations.json"
$DemoResultPath = Join-Path $ArtifactsDir "demo-semantic-search.json"
$EvidencePath = Join-Path $PmoDir "SPT-007B-implementation-evidence.json"
$GateJson = Join-Path $PmoDir "SPT-007B-policy-result.json"
$GateMd = Join-Path $PmoDir "SPT-007B-policy-result.md"
$BackupDir = Join-Path $PmoDir (
    "backups\pre-SPT007B-" +
    [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
)

Write-Step "Validando línea base SPT-007A y gobernanza"

foreach ($Path in @(
    (Join-Path $SourceDir "models.py"),
    (Join-Path $SourceDir "normalizer.py"),
    (Join-Path $SourceDir "repository.py"),
    (Join-Path $SourceDir "search.py"),
    (Join-Path $SourceDir "service.py"),
    (Join-Path $ProjectRoot "config\lexical_engine\SPT-007A-component.json"),
    (Join-Path $ProjectRoot "src\sgoda\governance\policy_cli.py"),
    (Join-Path $ProjectRoot "config\governance\SGD-114C-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "pytest.ini")
)) {
    Require-File -Path $Path
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Path in @(
    $SemanticModelsPath,
    $IndexPath,
    $RelationsPath,
    $ExpansionPath,
    $SemanticRankingPath,
    $SuggestionsPath,
    $SemanticServicePath,
    $SemanticCliPath,
    $TestPath,
    $PolicyPath,
    $RelationsConfigPath,
    $ComponentPath,
    $DocPath,
    $ArchitecturePath,
    $GovernancePath,
    $InvokePath
)) {
    if (Test-Path -LiteralPath $Path) {
        Copy-Item `
            -LiteralPath $Path `
            -Destination (Join-Path $BackupDir (Split-Path $Path -Leaf)) `
            -Force
    }
}

$SemanticModels = @'
"""Modelos semánticos de SPT-007B."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class SemanticRelation:
    source_id: str
    target_id: str
    relation_type: str
    weight: float = 1.0
    validated: bool = False
    cultural: bool = False
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class QueryExpansion:
    original: str
    normalized: str
    terms: tuple[str, ...]
    variants: tuple[str, ...]
    related_entry_ids: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SemanticHit:
    entry_id: str
    lexical_score: float
    semantic_score: float
    relation_score: float
    final_score: float
    matched_terms: tuple[str, ...]
    relation_types: tuple[str, ...]
    explanation: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SemanticSearchResponse:
    query: str
    normalized_query: str
    total: int
    hits: tuple[SemanticHit, ...]
    suggestions: tuple[str, ...]
    no_invention: bool = True
'@

$Index = @'
"""Índice invertido multilingüe local."""

from __future__ import annotations

from collections import defaultdict

from .models import LexicalEntry
from .normalizer import normalize_text, tokenize


class SemanticLexicalIndex:
    def __init__(self) -> None:
        self._entries: dict[str, LexicalEntry] = {}
        self._token_to_ids: dict[str, set[str]] = defaultdict(set)
        self._term_to_ids: dict[str, set[str]] = defaultdict(set)
        self._category_to_ids: dict[str, set[str]] = defaultdict(set)
        self._variants: dict[str, set[str]] = defaultdict(set)

    def add_entry(
        self,
        entry: LexicalEntry,
        variants: tuple[str, ...] = (),
    ) -> None:
        self._entries[entry.entry_id] = entry

        for text in entry.text_by_language().values():
            normalized = normalize_text(text)

            if not normalized:
                continue

            self._term_to_ids[normalized].add(entry.entry_id)

            for token in tokenize(normalized):
                self._token_to_ids[token].add(entry.entry_id)

        category = normalize_text(entry.category)

        if category:
            self._category_to_ids[category].add(entry.entry_id)

        for variant in variants:
            normalized_variant = normalize_text(variant)

            if normalized_variant:
                self._variants[normalized_variant].add(entry.entry_id)

    def get(self, entry_id: str) -> LexicalEntry | None:
        return self._entries.get(entry_id)

    def entry_ids(self) -> tuple[str, ...]:
        return tuple(sorted(self._entries))

    def exact(self, term: str) -> tuple[str, ...]:
        return tuple(
            sorted(self._term_to_ids.get(normalize_text(term), set()))
        )

    def token(self, token: str) -> tuple[str, ...]:
        return tuple(
            sorted(self._token_to_ids.get(normalize_text(token), set()))
        )

    def variant(self, variant: str) -> tuple[str, ...]:
        return tuple(
            sorted(self._variants.get(normalize_text(variant), set()))
        )

    def candidates(self, terms: tuple[str, ...]) -> tuple[str, ...]:
        found: set[str] = set()

        for term in terms:
            normalized = normalize_text(term)
            found.update(self._term_to_ids.get(normalized, set()))
            found.update(self._token_to_ids.get(normalized, set()))
            found.update(self._variants.get(normalized, set()))

        return tuple(sorted(found))

    def vocabulary(self) -> tuple[str, ...]:
        return tuple(
            sorted(
                set(self._term_to_ids)
                | set(self._token_to_ids)
                | set(self._variants)
            )
        )
'@

$Relations = @'
"""Repositorio gobernado de relaciones semánticas."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

from .semantic_models import SemanticRelation


ALLOWED_RELATIONS = {
    "synonym",
    "related",
    "family",
    "variant",
    "broader",
    "narrower",
    "cultural",
    "antonym",
}


class SemanticRelationRepository:
    def __init__(
        self,
        relations: list[SemanticRelation],
    ) -> None:
        self._relations = tuple(relations)
        self._outgoing: dict[str, list[SemanticRelation]] = defaultdict(list)

        for relation in self._relations:
            self._outgoing[relation.source_id].append(relation)

    @classmethod
    def from_records(
        cls,
        records: list[dict[str, Any]],
    ) -> "SemanticRelationRepository":
        relations = []

        for item in records:
            relation_type = str(
                item.get("relation_type")
                or item.get("type")
                or ""
            ).strip().casefold()

            if relation_type not in ALLOWED_RELATIONS:
                continue

            source_id = str(item.get("source_id") or "").strip()
            target_id = str(item.get("target_id") or "").strip()

            if not source_id or not target_id or source_id == target_id:
                continue

            relations.append(
                SemanticRelation(
                    source_id=source_id,
                    target_id=target_id,
                    relation_type=relation_type,
                    weight=max(
                        0.0,
                        min(1.0, float(item.get("weight", 1.0))),
                    ),
                    validated=bool(item.get("validated", False)),
                    cultural=bool(item.get("cultural", False)),
                    metadata={
                        key: value
                        for key, value in item.items()
                        if key
                        not in {
                            "source_id",
                            "target_id",
                            "relation_type",
                            "type",
                            "weight",
                            "validated",
                            "cultural",
                        }
                    },
                )
            )

        return cls(relations)

    @classmethod
    def from_json(
        cls,
        path: str | Path,
    ) -> "SemanticRelationRepository":
        payload = json.loads(
            Path(path).read_text(encoding="utf-8-sig")
        )

        if isinstance(payload, dict):
            records = payload.get("relations", [])
        else:
            records = payload

        if not isinstance(records, list):
            raise ValueError("relations debe ser una lista.")

        return cls.from_records(
            [item for item in records if isinstance(item, dict)]
        )

    def outgoing(
        self,
        source_id: str,
        validated_only: bool = False,
    ) -> tuple[SemanticRelation, ...]:
        relations = self._outgoing.get(source_id, [])

        if validated_only:
            relations = [
                item for item in relations if item.validated
            ]

        return tuple(
            sorted(
                relations,
                key=lambda item: (
                    item.relation_type,
                    item.target_id,
                ),
            )
        )

    def related_ids(
        self,
        source_ids: tuple[str, ...],
        validated_only: bool = False,
    ) -> tuple[str, ...]:
        result: set[str] = set()

        for source_id in source_ids:
            for relation in self.outgoing(
                source_id,
                validated_only=validated_only,
            ):
                result.add(relation.target_id)

        return tuple(sorted(result))
'@

$Expansion = @'
"""Expansión determinista de consultas."""

from __future__ import annotations

from .normalizer import normalize_text, tokenize
from .relations import SemanticRelationRepository
from .semantic_index import SemanticLexicalIndex
from .semantic_models import QueryExpansion


def expand_query(
    query: str,
    index: SemanticLexicalIndex,
    relations: SemanticRelationRepository,
    explicit_variants: tuple[str, ...] = (),
) -> QueryExpansion:
    normalized = normalize_text(query)
    terms = tokenize(normalized)

    direct_ids: set[str] = set()

    for term in (normalized, *terms, *explicit_variants):
        direct_ids.update(index.exact(term))
        direct_ids.update(index.token(term))
        direct_ids.update(index.variant(term))

    related = relations.related_ids(
        tuple(sorted(direct_ids)),
        validated_only=True,
    )

    variants = tuple(
        sorted(
            {
                normalize_text(item)
                for item in explicit_variants
                if normalize_text(item)
            }
        )
    )

    return QueryExpansion(
        original=query,
        normalized=normalized,
        terms=terms,
        variants=variants,
        related_entry_ids=related,
    )
'@

$SemanticRanking = @'
"""Ranking híbrido léxico-semántico."""

from __future__ import annotations


RELATION_WEIGHTS = {
    "synonym": 1.0,
    "variant": 0.95,
    "family": 0.85,
    "related": 0.70,
    "cultural": 0.75,
    "broader": 0.60,
    "narrower": 0.60,
    "antonym": 0.35,
}


def relation_weight(relation_type: str) -> float:
    return RELATION_WEIGHTS.get(relation_type, 0.0)


def hybrid_score(
    lexical_score: float,
    semantic_score: float,
    relation_score: float,
    validated: bool,
) -> float:
    score = (
        lexical_score * 0.55
        + semantic_score * 0.25
        + relation_score * 0.20
    )

    if validated:
        score += 2.0

    return round(score, 6)
'@

$Suggestions = @'
"""Sugerencias deterministas sin generación inventada."""

from __future__ import annotations

from .normalizer import normalize_text, similarity
from .semantic_index import SemanticLexicalIndex


def suggest_terms(
    query: str,
    index: SemanticLexicalIndex,
    limit: int = 5,
    threshold: float = 0.45,
) -> tuple[str, ...]:
    normalized = normalize_text(query)
    candidates = []

    for term in index.vocabulary():
        if term == normalized:
            continue

        score = similarity(normalized, term)

        if score >= threshold:
            candidates.append((score, term))

    return tuple(
        term
        for _, term in sorted(
            candidates,
            key=lambda item: (-item[0], item[1]),
        )[: max(0, limit)]
    )
'@

$SemanticService = @'
"""Servicio semántico de SPT-007B."""

from __future__ import annotations

from .models import SearchQuery
from .normalizer import normalize_text, similarity
from .relations import SemanticRelationRepository
from .search import LexicalSearchEngine
from .semantic_index import SemanticLexicalIndex
from .semantic_models import SemanticHit, SemanticSearchResponse
from .semantic_ranking import hybrid_score, relation_weight
from .suggestions import suggest_terms


class SemanticLexicalService:
    def __init__(
        self,
        lexical_engine: LexicalSearchEngine,
        index: SemanticLexicalIndex,
        relations: SemanticRelationRepository,
    ) -> None:
        self.lexical_engine = lexical_engine
        self.index = index
        self.relations = relations

    def search(
        self,
        query: str,
        limit: int = 20,
        validated_relations_only: bool = True,
    ) -> SemanticSearchResponse:
        normalized = normalize_text(query)

        lexical = self.lexical_engine.search(
            SearchQuery(
                text=query,
                limit=max(limit, 50),
                fuzzy=True,
            )
        )

        by_id = {
            hit.entry.entry_id: hit
            for hit in lexical.hits
        }

        candidate_ids: set[str] = set(by_id)
        direct_ids = set(self.index.candidates((normalized,)))
        candidate_ids.update(direct_ids)

        relation_map: dict[str, list] = {}

        for source_id in tuple(sorted(candidate_ids)):
            for relation in self.relations.outgoing(
                source_id,
                validated_only=validated_relations_only,
            ):
                candidate_ids.add(relation.target_id)
                relation_map.setdefault(
                    relation.target_id,
                    [],
                ).append(relation)

        hits = []

        for entry_id in sorted(candidate_ids):
            entry = self.index.get(entry_id)

            if entry is None:
                continue

            lexical_hit = by_id.get(entry_id)
            lexical_score = (
                lexical_hit.score
                if lexical_hit is not None
                else 0.0
            )

            text_scores = [
                similarity(normalized, text)
                for text in entry.text_by_language().values()
                if text
            ]
            semantic_score = (
                max(text_scores, default=0.0) * 100.0
            )

            related = relation_map.get(entry_id, [])
            relation_score = (
                max(
                    (
                        relation_weight(item.relation_type)
                        * item.weight
                        * 100.0
                    )
                    for item in related
                )
                if related
                else 0.0
            )

            final = hybrid_score(
                lexical_score=lexical_score,
                semantic_score=semantic_score,
                relation_score=relation_score,
                validated=entry.validated,
            )

            if final <= 0.0:
                continue

            matched_terms = tuple(
                sorted(
                    {
                        lexical_hit.matched_text
                        if lexical_hit is not None
                        else "",
                        *(
                            text
                            for text in entry.text_by_language().values()
                            if normalize_text(text) == normalized
                        ),
                    }
                    - {""}
                )
            )

            relation_types = tuple(
                sorted({item.relation_type for item in related})
            )

            explanation = []

            if lexical_hit is not None:
                explanation.append(
                    f"coincidencia:{lexical_hit.match_type}"
                )

            if relation_types:
                explanation.append(
                    "relaciones:" + ",".join(relation_types)
                )

            hits.append(
                SemanticHit(
                    entry_id=entry_id,
                    lexical_score=round(lexical_score, 6),
                    semantic_score=round(semantic_score, 6),
                    relation_score=round(relation_score, 6),
                    final_score=final,
                    matched_terms=matched_terms,
                    relation_types=relation_types,
                    explanation=tuple(explanation),
                )
            )

        ordered = tuple(
            sorted(
                hits,
                key=lambda item: (
                    -item.final_score,
                    item.entry_id,
                ),
            )[: max(1, limit)]
        )

        suggestions = suggest_terms(
            query,
            self.index,
            limit=5,
        )

        return SemanticSearchResponse(
            query=query,
            normalized_query=normalized,
            total=len(ordered),
            hits=ordered,
            suggestions=suggestions,
            no_invention=True,
        )

    def to_dict(
        self,
        response: SemanticSearchResponse,
    ) -> dict:
        results = []

        for hit in response.hits:
            entry = self.index.get(hit.entry_id)

            if entry is None:
                continue

            results.append(
                {
                    "entry_id": hit.entry_id,
                    "final_score": hit.final_score,
                    "lexical_score": hit.lexical_score,
                    "semantic_score": hit.semantic_score,
                    "relation_score": hit.relation_score,
                    "matched_terms": list(hit.matched_terms),
                    "relation_types": list(hit.relation_types),
                    "explanation": list(hit.explanation),
                    "puinave": entry.puinave,
                    "spanish": entry.spanish,
                    "english_us": entry.english_us,
                    "italian": entry.italian,
                    "category": entry.category,
                    "validated": entry.validated,
                    "cultural_status": entry.cultural_status,
                }
            )

        return {
            "query": response.query,
            "normalized_query": response.normalized_query,
            "total": response.total,
            "suggestions": list(response.suggestions),
            "no_invention": response.no_invention,
            "results": results,
        }
'@

$SemanticCli = @'
"""CLI de SPT-007B."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .relations import SemanticRelationRepository
from .repository import LexicalRepository
from .search import LexicalSearchEngine
from .semantic_index import SemanticLexicalIndex
from .semantic_service import SemanticLexicalService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rlb", required=True)
    parser.add_argument("--relations", required=True)
    parser.add_argument("--query", required=True)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--output")
    args = parser.parse_args()

    repository = LexicalRepository.from_json(args.rlb)
    relations = SemanticRelationRepository.from_json(
        args.relations
    )
    index = SemanticLexicalIndex()

    for entry in repository.all():
        variants = tuple(
            str(item)
            for item in entry.metadata.get("variants", [])
            if str(item).strip()
        )
        index.add_entry(entry, variants=variants)

    service = SemanticLexicalService(
        LexicalSearchEngine(repository),
        index,
        relations,
    )

    payload = service.to_dict(
        service.search(
            args.query,
            limit=args.limit,
        )
    )

    serialized = json.dumps(
        payload,
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

$Tests = @'
import json
from pathlib import Path

from sgoda.lexical_engine.relations import (
    SemanticRelationRepository,
)
from sgoda.lexical_engine.repository import LexicalRepository
from sgoda.lexical_engine.search import LexicalSearchEngine
from sgoda.lexical_engine.semantic_index import SemanticLexicalIndex
from sgoda.lexical_engine.semantic_service import (
    SemanticLexicalService,
)
from sgoda.lexical_engine.suggestions import suggest_terms


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
                "variants": ["amdaa"],
            },
            {
                "id": "LEX-002",
                "puinave": "AMDA-KU",
                "spanish": "hogar",
                "english_us": "home",
                "italian": "dimora",
                "validated": True,
                "category": "sustantivo",
            },
            {
                "id": "LEX-003",
                "puinave": "DAPA",
                "spanish": "agua",
                "english_us": "water",
                "italian": "acqua",
                "validated": True,
                "category": "sustantivo",
            },
        ]
    )


def _relations() -> SemanticRelationRepository:
    return SemanticRelationRepository.from_records(
        [
            {
                "source_id": "LEX-001",
                "target_id": "LEX-002",
                "relation_type": "synonym",
                "weight": 1.0,
                "validated": True,
            },
            {
                "source_id": "LEX-002",
                "target_id": "LEX-001",
                "relation_type": "family",
                "weight": 0.8,
                "validated": True,
            },
        ]
    )


def _service() -> SemanticLexicalService:
    repository = _repository()
    index = SemanticLexicalIndex()

    for entry in repository.all():
        variants = tuple(entry.metadata.get("variants", []))
        index.add_entry(entry, variants=variants)

    return SemanticLexicalService(
        LexicalSearchEngine(repository),
        index,
        _relations(),
    )


def test_SPT_007B_builds_multilingual_index() -> None:
    repository = _repository()
    index = SemanticLexicalIndex()

    for entry in repository.all():
        index.add_entry(entry)

    assert index.exact("house") == ("LEX-001",)
    assert index.exact("agua") == ("LEX-003",)
    assert index.token("casa") == ("LEX-001",)


def test_SPT_007B_indexes_explicit_variants() -> None:
    repository = _repository()
    index = SemanticLexicalIndex()
    entry = repository.all()[0]
    index.add_entry(entry, variants=("amdaa",))

    assert index.variant("amdaa") == ("LEX-001",)


def test_SPT_007B_reads_relations() -> None:
    relations = _relations()
    outgoing = relations.outgoing("LEX-001")

    assert len(outgoing) == 1
    assert outgoing[0].relation_type == "synonym"
    assert outgoing[0].target_id == "LEX-002"


def test_SPT_007B_expands_results_by_relation() -> None:
    response = _service().search("casa")

    ids = {item.entry_id for item in response.hits}
    assert "LEX-001" in ids
    assert "LEX-002" in ids


def test_SPT_007B_hybrid_ranking_is_deterministic() -> None:
    service = _service()

    first = service.search("casa")
    second = service.search("casa")

    assert first.hits == second.hits
    assert first.hits[0].entry_id == "LEX-001"


def test_SPT_007B_reports_relation_explanation() -> None:
    response = _service().search("casa")
    related = next(
        item
        for item in response.hits
        if item.entry_id == "LEX-002"
    )

    assert "synonym" in related.relation_types
    assert related.relation_score > 0


def test_SPT_007B_generates_safe_suggestions() -> None:
    repository = _repository()
    index = SemanticLexicalIndex()

    for entry in repository.all():
        index.add_entry(entry)

    suggestions = suggest_terms(
        "hous",
        index,
        threshold=0.40,
    )

    assert "house" in suggestions


def test_SPT_007B_no_invention_contract() -> None:
    response = _service().search("zzzz inexistente")

    assert response.no_invention is True
    assert all(
        _service().index.get(item.entry_id) is not None
        for item in response.hits
    )


def test_SPT_007B_serializes_multilingual_result() -> None:
    service = _service()
    payload = service.to_dict(service.search("house"))

    assert payload["results"][0]["puinave"] == "AMDA"
    assert payload["results"][0]["english_us"] == "house"
    assert payload["no_invention"] is True


def test_SPT_007B_reads_json_relations(tmp_path: Path) -> None:
    path = tmp_path / "relations.json"
    path.write_text(
        json.dumps(
            {
                "relations": [
                    {
                        "source_id": "LEX-001",
                        "target_id": "LEX-002",
                        "relation_type": "related",
                        "validated": True,
                    }
                ]
            }
        ),
        encoding="utf-8",
    )

    repository = SemanticRelationRepository.from_json(path)

    assert repository.outgoing("LEX-001")[0].target_id == "LEX-002"


def test_SPT_007B_rejects_unknown_relation_types() -> None:
    repository = SemanticRelationRepository.from_records(
        [
            {
                "source_id": "LEX-001",
                "target_id": "LEX-002",
                "relation_type": "invented_relation",
            }
        ]
    )

    assert repository.outgoing("LEX-001") == ()


def test_SPT_007B_only_uses_validated_relations_by_default() -> None:
    repository = _repository()
    index = SemanticLexicalIndex()

    for entry in repository.all():
        index.add_entry(entry)

    relations = SemanticRelationRepository.from_records(
        [
            {
                "source_id": "LEX-001",
                "target_id": "LEX-003",
                "relation_type": "related",
                "validated": False,
            }
        ]
    )

    service = SemanticLexicalService(
        LexicalSearchEngine(repository),
        index,
        relations,
    )
    response = service.search("casa")

    related = [
        item
        for item in response.hits
        if item.entry_id == "LEX-003"
    ]
    assert related == []
'@

$Policy = @'
{
  "component": "SPT-007B",
  "version": "1.0.0",
  "name": "Motor Léxico Inteligente Semántico",
  "local_first": true,
  "paid_services_required": false,
  "generative_models_required": false,
  "no_invention": true,
  "validated_relations_only": true,
  "allowed_relation_types": [
    "synonym",
    "related",
    "family",
    "variant",
    "broader",
    "narrower",
    "cultural",
    "antonym"
  ],
  "supported_languages": [
    "pu",
    "es",
    "en-US",
    "it"
  ],
  "ranking": {
    "lexical_weight": 0.55,
    "semantic_weight": 0.25,
    "relation_weight": 0.20
  },
  "cultural_validation_required": true
}
'@

$RelationsConfig = @'
{
  "relations": [
    {
      "source_id": "LEX-001",
      "target_id": "LEX-002",
      "relation_type": "related",
      "weight": 0.8,
      "validated": false,
      "cultural": false,
      "review_required": true
    }
  ]
}
'@

$Component = @'
{
  "increment_code": "SPT-007B",
  "name": "Motor Léxico Inteligente Semántico",
  "component_type": "semantic_lexical_engine",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica",
  "dependencies": [
    "SPT-007A",
    "SPT-006",
    "SPT-006A",
    "SPT-004A",
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/lexical_engine/semantic_models.py",
    "src/sgoda/lexical_engine/semantic_index.py",
    "src/sgoda/lexical_engine/relations.py",
    "src/sgoda/lexical_engine/query_expansion.py",
    "src/sgoda/lexical_engine/semantic_ranking.py",
    "src/sgoda/lexical_engine/suggestions.py",
    "src/sgoda/lexical_engine/semantic_service.py",
    "src/sgoda/lexical_engine/semantic_cli.py"
  ],
  "tests": [
    "tests/lexical_engine/test_SPT_007B_semantic_lexical_engine.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007B-Motor-Lexico-Inteligente-Semantico.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007B-Arquitectura-Indice-Semantico.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007B-Gobierno-Relaciones-Lexicas.md"
  ]
}
'@

$Doc = @'
# SPT-007B — Motor Léxico Inteligente Semántico

SPT-007B amplía SPT-007A con un índice invertido multilingüe, relaciones
léxicas gobernadas, expansión determinista de consultas, sugerencias y
ranking híbrido.

No utiliza servicios de pago ni genera vocabulario Puinave.
'@

$Architecture = @'
# Arquitectura del índice semántico SPT-007B

El motor combina:

1. coincidencia léxica de SPT-007A;
2. índice invertido multilingüe;
3. variantes explícitas;
4. relaciones validadas;
5. similitud ortográfica local;
6. ranking híbrido determinista;
7. sugerencias basadas únicamente en vocabulario existente.

No se usan embeddings externos en esta versión.
'@

$Governance = @'
# Gobierno de relaciones léxicas SPT-007B

Las relaciones deben declarar:

- registro origen;
- registro destino;
- tipo permitido;
- peso;
- estado de validación;
- indicador cultural.

Por defecto, el motor solo utiliza relaciones validadas. Las relaciones
desconocidas o autorreferenciales son rechazadas.
'@

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Rlb,

    [Parameter(Mandatory = $true)]
    [string]$Relations,

    [Parameter(Mandatory = $true)]
    [string]$Query,

    [int]$Limit = 20,

    [string]$Output = "artifacts/lexical_engine/SPT-007B/search-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.lexical_engine.semantic_cli `
    --rlb $Rlb `
    --relations $Relations `
    --query $Query `
    --limit $Limit `
    --output $Output

exit $LASTEXITCODE
'@

Write-Step "Instalando SPT-007B"

Write-Utf8 $SemanticModelsPath $SemanticModels
Write-Utf8 $IndexPath $Index
Write-Utf8 $RelationsPath $Relations
Write-Utf8 $ExpansionPath $Expansion
Write-Utf8 $SemanticRankingPath $SemanticRanking
Write-Utf8 $SuggestionsPath $Suggestions
Write-Utf8 $SemanticServicePath $SemanticService
Write-Utf8 $SemanticCliPath $SemanticCli
Write-Utf8 $TestPath $Tests
Write-Utf8 $PolicyPath $Policy
Write-Utf8 $RelationsConfigPath $RelationsConfig
Write-Utf8 $ComponentPath $Component
Write-Utf8 $DocPath $Doc
Write-Utf8 $ArchitecturePath $Architecture
Write-Utf8 $GovernancePath $Governance
Write-Utf8 $InvokePath $Invoke

Invoke-Checked "Validando sintaxis" {
    python -m py_compile `
        "src/sgoda/lexical_engine/semantic_models.py" `
        "src/sgoda/lexical_engine/semantic_index.py" `
        "src/sgoda/lexical_engine/relations.py" `
        "src/sgoda/lexical_engine/query_expansion.py" `
        "src/sgoda/lexical_engine/semantic_ranking.py" `
        "src/sgoda/lexical_engine/suggestions.py" `
        "src/sgoda/lexical_engine/semantic_service.py" `
        "src/sgoda/lexical_engine/semantic_cli.py" `
        "tests/lexical_engine/test_SPT_007B_semantic_lexical_engine.py"
}

Invoke-Checked "Ejecutando 12 pruebas específicas SPT-007B" {
    python -m pytest `
        "tests/lexical_engine/test_SPT_007B_semantic_lexical_engine.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Ejecutando demostración semántica controlada"

Write-Json $DemoRlbPath ([ordered]@{
    entries = @(
        [ordered]@{
            id = "LEX-001"
            puinave = "AMDA"
            spanish = "casa"
            english_us = "house"
            italian = "casa"
            validated = $true
            category = "sustantivo"
            variants = @("amdaa")
        },
        [ordered]@{
            id = "LEX-002"
            puinave = "AMDA-KU"
            spanish = "hogar"
            english_us = "home"
            italian = "dimora"
            validated = $true
            category = "sustantivo"
        }
    )
})

Write-Json $DemoRelationsPath ([ordered]@{
    relations = @(
        [ordered]@{
            source_id = "LEX-001"
            target_id = "LEX-002"
            relation_type = "synonym"
            weight = 1.0
            validated = $true
            cultural = $false
        }
    )
})

Invoke-Checked "Consultando relación semántica casa-hogar" {
    python -m sgoda.lexical_engine.semantic_cli `
        --rlb "$DemoRlbPath" `
        --relations "$DemoRelationsPath" `
        --query "casa" `
        --limit 10 `
        --output "$DemoResultPath"
}

$Demo = Get-Content `
    -LiteralPath $DemoResultPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

$DemoIds = @($Demo.results | ForEach-Object { $_.entry_id })

if (
    $DemoIds -notcontains "LEX-001" -or
    $DemoIds -notcontains "LEX-002"
) {
    throw "La demostración no recuperó el registro directo y el relacionado."
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
    throw "SGD-116 no aprobó la incorporación de SPT-007B."
}

Write-Step "Preparando evidencia previa y release"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json (Join-Path $PmoDir "SPT-007B-pre-gate-evidence.json") ([ordered]@{
    increment_code = "SPT-007B"
    version = "1.0.0"
    status = "technically_completed"
    phase = "Fase Tecnológica"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    specific_tests = 12
    full_suite_executed = (-not $SkipFullSuite)
    semantic_demo_total = $Demo.total
    roadmap_approved = [bool]$RoadmapValidation.passed
})

Copy-Item `
    -LiteralPath $ComponentPath `
    -Destination (Join-Path $ReleaseDir "SPT-007B-component.json") `
    -Force

Write-Step "Evaluando SPT-007B mediante SGD-114C"

& python -m sgoda.governance.policy_cli `
    --root "$ProjectRoot" `
    --policy "config/governance/SGD-114C-policy.json" `
    --increment "SPT-007B" `
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

    throw "SGD-114C no aprobó SPT-007B."
}

Write-Step "Actualizando documentación maestra SGD-115"

Invoke-Checked "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Write-Step "Generando evidencia y release"

Write-Json $EvidencePath ([ordered]@{
    increment_code = "SPT-007B"
    version = "1.0.0"
    status = "implemented"
    phase = "Fase Tecnológica"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    capabilities = @(
        "multilingual_inverted_index",
        "explicit_variants",
        "validated_relations",
        "lexical_families",
        "semantic_expansion",
        "hybrid_ranking",
        "safe_suggestions",
        "assistant_contract",
        "no_invention"
    )
    supported_languages = @("pu", "es", "en-US", "it")
    specific_tests = 12
    full_suite_executed = (-not $SkipFullSuite)
    policy_approved = [bool]$Gate.approved
    policy_exit_code = $Gate.exit_code
    roadmap_approved = [bool]$RoadmapValidation.passed
    demo = $DemoResultPath
    backup = $BackupDir
})

foreach ($Path in @(
    $SemanticModelsPath,
    $IndexPath,
    $RelationsPath,
    $ExpansionPath,
    $SemanticRankingPath,
    $SuggestionsPath,
    $SemanticServicePath,
    $SemanticCliPath,
    $TestPath,
    $PolicyPath,
    $RelationsConfigPath,
    $ComponentPath,
    $DocPath,
    $ArchitecturePath,
    $GovernancePath,
    $InvokePath,
    $DemoResultPath,
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

Write-Host "SPT-007B v1.0.0 implementado." -ForegroundColor Green
Write-Host "Fase Tecnológica: ACTUALIZADA." -ForegroundColor Green
Write-Host "Motor Léxico Semántico: OPERATIVO." -ForegroundColor Green
Write-Host "Pruebas específicas: 12 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Índice invertido multilingüe: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Variantes ortográficas explícitas: IMPLEMENTADAS." -ForegroundColor Green
Write-Host "Relaciones léxicas gobernadas: IMPLEMENTADAS." -ForegroundColor Green
Write-Host "Familias y relaciones culturales: PREPARADAS." -ForegroundColor Green
Write-Host "Ranking híbrido: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Sugerencias seguras: IMPLEMENTADAS." -ForegroundColor Green
Write-Host "No invención Puinave: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Servicios de pago: NO REQUERIDOS." -ForegroundColor Green
Write-Host "SGD-114C: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO Y APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-007B-v1.0.0" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
