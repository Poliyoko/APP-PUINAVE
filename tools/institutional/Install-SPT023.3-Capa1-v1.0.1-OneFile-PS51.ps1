param(
    [string]$ProjectRoot = "",
    [string]$ExpectedHead = "543dd7e52c24e661b8b7a1936aae7b88346733e1"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$Component = "SPT-023.3"
$Version = "1.0.1"
$RunId = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")

function Stop-Install {
    param(
        [string]$Message,
        [System.Collections.ArrayList]$CreatedFiles
    )

    if ($null -ne $CreatedFiles) {
        foreach ($Path in @($CreatedFiles) | Sort-Object Length -Descending) {
            if (Test-Path -LiteralPath $Path -PathType Leaf) {
                Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host " SPT-023.3 CAPA 1 v1.0.1 INSTALLATION : HOLD" -ForegroundColor Red
    Write-Host (" " + $Message) -ForegroundColor Red
    Write-Host " NEW FILES FROM THIS RUN       : ROLLED BACK" -ForegroundColor Red
    Write-Host " COMMIT / PUSH                 : NO" -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Red
    exit 20
}

function Invoke-GitSingleLine {
    param([string[]]$GitArguments)

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Output = @(& git @GitArguments 2>&1)
        $Code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }

    if ($Code -ne 0) {
        throw ("git " + ($GitArguments -join " ") + " failed: " + ($Output -join " "))
    }
    if ($Output.Count -eq 0) {
        throw ("git " + ($GitArguments -join " ") + " returned no output.")
    }

    return ([string]($Output | Select-Object -First 1)).Trim()
}

function Invoke-GitLines {
    param([string[]]$GitArguments)

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Output = @(& git @GitArguments 2>&1)
        $Code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }

    if ($Code -ne 0) {
        throw ("git " + ($GitArguments -join " ") + " failed: " + ($Output -join " "))
    }

    foreach ($Line in $Output) {
        [string]$Line
    }
}

function Write-Utf8Lf {
    param(
        [string]$Path,
        [string]$Content,
        [System.Collections.ArrayList]$CreatedFiles
    )

    if (Test-Path -LiteralPath $Path) {
        throw "Target already exists; refusing overwrite: $Path"
    }

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Text = $Content.Replace("`r`n","`n").Replace("`r","`n").TrimEnd([char[]]@("`r","`n")) + "`n"
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        (New-Object System.Text.UTF8Encoding($false))
    )
    [void]$CreatedFiles.Add($Path)
}

function Get-TrackedHashMap {
    param(
        [string]$Root,
        [string[]]$Paths
    )

    $Map = @{}
    foreach ($Rel in $Paths) {
        $Full = Join-Path $Root $Rel
        if (Test-Path -LiteralPath $Full -PathType Leaf) {
            $Map[$Rel] = (Get-FileHash -LiteralPath $Full -Algorithm SHA256).Hash
        }
    }
    return $Map
}

function Compare-HashMaps {
    param($Before, $After)

    $Keys = @($Before.Keys + $After.Keys | Sort-Object -Unique)
    $Changed = @()

    foreach ($Key in $Keys) {
        if (-not $Before.ContainsKey($Key) -or -not $After.ContainsKey($Key)) {
            $Changed += $Key
            continue
        }
        if ($Before[$Key] -ne $After[$Key]) {
            $Changed += $Key
        }
    }

    return @($Changed)
}

$CreatedFiles = New-Object System.Collections.ArrayList

try {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = Invoke-GitSingleLine @("rev-parse","--show-toplevel")
    }

    Set-Location $ProjectRoot
    $Root = Invoke-GitSingleLine @("rev-parse","--show-toplevel")
    $Branch = Invoke-GitSingleLine @("branch","--show-current")
    $Origin = Invoke-GitSingleLine @("remote","get-url","origin")

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host " SGODA-PUINAVE - SPT-023.3 CAPA 1 v1.0.1" -ForegroundColor Cyan
    Write-Host " MOTOR DE CATEGORIAS - IMPLEMENTACION INCREMENTAL" -ForegroundColor Cyan
    Write-Host " SINGLE FILE / POWERSHELL 5.1 / NO COMMIT / NO PUSH" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "[1/10] AUTHORITATIVE BASELINE" -ForegroundColor Yellow

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git fetch origin $Branch --no-tags
        $FetchCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }

    if ($FetchCode -ne 0) {
        throw "Unable to fetch official remote."
    }

    $Local = Invoke-GitSingleLine @("rev-parse","HEAD")
    $Remote = Invoke-GitSingleLine @("rev-parse","origin/$Branch")
    $Staged = @(Invoke-GitLines @("diff","--cached","--name-only"))
    $Deleted = @(Invoke-GitLines @("ls-files","--deleted"))

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if ($Local -ne $ExpectedHead) { throw "Local HEAD is not certified baseline." }
    if ($Remote -ne $ExpectedHead) { throw "Remote HEAD is not certified baseline." }
    if ($Staged.Count -ne 0) { throw "Staging is not clean." }
    if ($Deleted.Count -ne 0) { throw "Tracked deletions detected." }

    $VenvPython = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
        throw "Project .venv Python not found."
    }

    Write-Host "BASELINE : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[2/10] PRESERVE CLOSED COMPONENTS BY SHA-256" -ForegroundColor Yellow

    $Tracked = @(Invoke-GitLines @("-c","core.quotepath=false","ls-files"))
    $Protected = @(
        $Tracked |
        Where-Object {
            $_ -match '(?i)^src/sgoda/integration/spt0231/' -or
            $_ -match '(?i)^src/sgoda/integration/spt0232/' -or
            $_ -match '(?i)^docs/06_Tecnologia/SPT-023\.1/' -or
            $_ -match '(?i)^docs/06_Tecnologia/SPT-023\.2/'
        }
    )

    if ($Protected.Count -eq 0) {
        throw "Protected SPT-023.1/SPT-023.2 baseline not found."
    }

    $ProtectedBefore = Get-TrackedHashMap -Root $Root -Paths $Protected
    Write-Host "PROTECTED FILES : $($ProtectedBefore.Count)"
    Write-Host "SHA-256 BASELINE CAPTURED : YES" -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/10] TARGET COLLISION GATE" -ForegroundColor Yellow

    $Targets = @(
        "src\sgoda\integration\spt0233\__init__.py",
        "src\sgoda\integration\spt0233\models.py",
        "src\sgoda\integration\spt0233\catalog.py",
        "src\sgoda\integration\spt0233\service.py",
        "tests\integration\test_spt0233_category_engine.py",
        "docs\06_Tecnologia\SPT-023.3\SGD-SPT023.3-Capa1-Motor-Categorias.md"
    )

    $ExistingTargets = @()
    foreach ($Rel in $Targets) {
        $Full = Join-Path $Root $Rel
        if (Test-Path -LiteralPath $Full -PathType Leaf) {
            $ExistingTargets += $Rel
        }
    }

    if ($ExistingTargets.Count -eq 0) {
        Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green
        Write-Host "MODE              : FRESH INSTALL" -ForegroundColor Green
    }
    elseif ($ExistingTargets.Count -eq $Targets.Count) {
        foreach ($Rel in $ExistingTargets) {
            $PreviousEAP = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                & git ls-files --error-unmatch -- "$Rel" *> $null
                $TrackedTargetCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $PreviousEAP
            }

            if ($TrackedTargetCode -eq 0) {
                throw "Resume refused because target is already tracked: $Rel"
            }
        }

        Write-Host "EXISTING TARGETS : $($ExistingTargets.Count)" -ForegroundColor Yellow
        Write-Host "MODE             : SAFE RESUME OF PREVIOUS UNPUBLISHED RUN" -ForegroundColor Yellow
    }
    else {
        throw "Partial target set detected ($($ExistingTargets.Count)/$($Targets.Count)); refusing ambiguous installation."
    }

    Write-Host ""
    Write-Host "[4/10] IMPLEMENTING / RESUMING SPT-023.3 CAPA 1 v1.0.1" -ForegroundColor Yellow

    $InitPy = @'
"""SPT-023.3 - Motor institucional de categorias."""

from .catalog import CategoryCatalog
from .models import CategoryAssignmentResult
from .service import Spt0233CategoryService

__all__ = [
    "CategoryAssignmentResult",
    "CategoryCatalog",
    "Spt0233CategoryService",
]
'@

    $ModelsPy = @'
"""Modelos de resultado para SPT-023.3."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class CategoryAssignmentResult:
    source_index: int
    puinave: str
    lexical_hash: str
    input_decision: str
    assignment_status: str
    category_id: str | None = None
    category_name: str | None = None
    confidence: float = 0.0
    reasons: tuple[str, ...] = ()
    no_invention: bool = True
    requires_human_validation: bool = True
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "source_index": self.source_index,
            "puinave": self.puinave,
            "lexical_hash": self.lexical_hash,
            "input_decision": self.input_decision,
            "assignment_status": self.assignment_status,
            "category_id": self.category_id,
            "category_name": self.category_name,
            "confidence": self.confidence,
            "reasons": list(self.reasons),
            "no_invention": self.no_invention,
            "requires_human_validation": self.requires_human_validation,
            "metadata": dict(self.metadata),
        }
'@

    $CatalogPy = @'
"""Catalogo deterministico de categorias existentes para SPT-023.3."""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass
from typing import Any, Iterable


def _normalize(value: object) -> str:
    text = str(value or "").strip().casefold()
    text = unicodedata.normalize("NFKD", text)
    return "".join(ch for ch in text if not unicodedata.combining(ch))


@dataclass(frozen=True)
class CategoryDefinition:
    category_id: str
    name: str
    aliases: tuple[str, ...] = ()
    keywords: tuple[str, ...] = ()
    metadata: dict[str, Any] | None = None


class CategoryCatalog:
    """Solo contiene categorias institucionales ya existentes.

    La Capa 1 no crea categorias nuevas. La asignacion se limita a
    evidencia textual ya presente en la salida semantica SPT-023.2.
    """

    def __init__(self, categories: Iterable[dict[str, Any]]) -> None:
        definitions: list[CategoryDefinition] = []
        seen_ids: set[str] = set()

        for item in categories:
            if not isinstance(item, dict):
                raise TypeError("Cada categoria debe ser un objeto dict.")

            category_id = str(
                item.get("id") or item.get("category_id") or ""
            ).strip()
            name = str(item.get("name") or item.get("nombre") or "").strip()

            if not category_id or not name:
                raise ValueError("Cada categoria requiere id y name.")

            if category_id in seen_ids:
                raise ValueError(
                    f"Categoria duplicada en catalogo: {category_id}"
                )

            seen_ids.add(category_id)
            aliases = tuple(
                str(value).strip()
                for value in item.get("aliases", ())
                if str(value).strip()
            )
            keywords = tuple(
                str(value).strip()
                for value in item.get("keywords", ())
                if str(value).strip()
            )

            definitions.append(
                CategoryDefinition(
                    category_id=category_id,
                    name=name,
                    aliases=aliases,
                    keywords=keywords,
                    metadata=dict(item.get("metadata") or {}),
                )
            )

        self._categories = tuple(definitions)

    @property
    def categories(self) -> tuple[CategoryDefinition, ...]:
        return self._categories

    def rank(self, evidence: Iterable[str]) -> list[tuple[float, CategoryDefinition, str]]:
        normalized_evidence = {
            _normalize(value)
            for value in evidence
            if _normalize(value)
        }

        ranked: list[tuple[float, CategoryDefinition, str]] = []

        for category in self._categories:
            exact_terms = {
                _normalize(category.name),
                *(_normalize(value) for value in category.aliases),
            }
            keyword_terms = {
                _normalize(value)
                for value in category.keywords
                if _normalize(value)
            }

            exact_hit = sorted(normalized_evidence.intersection(exact_terms))
            if exact_hit:
                ranked.append((1.0, category, f"exact:{exact_hit[0]}"))
                continue

            keyword_hit = sorted(
                value
                for value in normalized_evidence
                for keyword in keyword_terms
                if keyword and (
                    value == keyword
                    or keyword in value.split()
                    or keyword in value
                )
            )

            if keyword_hit:
                ranked.append((0.85, category, f"keyword:{keyword_hit[0]}"))

        ranked.sort(
            key=lambda item: (
                -item[0],
                item[1].category_id,
            )
        )
        return ranked
'@

    $ServicePy = @'
"""Servicio deterministico de asignacion de categorias SPT-023.3."""

from __future__ import annotations

from typing import Any, Iterable

from .catalog import CategoryCatalog
from .models import CategoryAssignmentResult


_ALLOWED_EVIDENCE_KEYS = {
    "category",
    "categories",
    "semantic_category",
    "semantic_categories",
    "domain",
    "domains",
    "part_of_speech",
    "pos",
    "gloss",
    "meaning",
    "meanings",
    "translation_es",
    "spanish",
    "label",
    "labels",
}


def _flatten_evidence(value: object) -> list[str]:
    out: list[str] = []

    if value is None:
        return out

    if isinstance(value, str):
        text = value.strip()
        if text:
            out.append(text)
        return out

    if isinstance(value, (list, tuple, set)):
        for item in value:
            out.extend(_flatten_evidence(item))
        return out

    if isinstance(value, dict):
        for key, item in value.items():
            if str(key).casefold() in _ALLOWED_EVIDENCE_KEYS:
                out.extend(_flatten_evidence(item))
        return out

    return out


class Spt0233CategoryService:
    """Asigna exclusivamente categorias preexistentes.

    No crea categorias, no inventa significado y no habilita SPT-023.4
    cuando la evidencia es insuficiente o ambigua.
    """

    def __init__(
        self,
        catalog: CategoryCatalog,
        minimum_confidence: float = 0.85,
    ) -> None:
        self.catalog = catalog
        self.minimum_confidence = max(
            0.0,
            min(1.0, float(minimum_confidence)),
        )

    @staticmethod
    def _input_decision(item: dict[str, Any]) -> str:
        explicit = str(
            item.get("institutional_decision")
            or item.get("decision")
            or ""
        ).strip().upper()

        if explicit:
            return explicit

        if (
            bool(item.get("downstream_allowed"))
            and str(item.get("semantic_status") or "").upper() == "MATCHED"
        ):
            return "READY_FOR_CATEGORY"

        return "NOT_ELIGIBLE"

    def assign(self, item: dict[str, Any]) -> CategoryAssignmentResult:
        decision = self._input_decision(item)
        source_index = int(item.get("source_index") or 0)
        puinave = str(item.get("puinave") or "").strip()
        lexical_hash = str(item.get("lexical_hash") or "").strip()

        base = {
            "source_index": source_index,
            "puinave": puinave,
            "lexical_hash": lexical_hash,
            "input_decision": decision,
            "no_invention": True,
            "metadata": {
                "source_component": "SPT-023.2",
                "target_component": "SPT-023.3",
            },
        }

        if decision != "READY_FOR_CATEGORY":
            return CategoryAssignmentResult(
                **base,
                assignment_status="NOT_ELIGIBLE",
                confidence=0.0,
                reasons=("input_not_ready_for_category",),
                requires_human_validation=True,
            )

        evidence: list[str] = []
        evidence.extend(_flatten_evidence(item.get("semantic_candidates")))
        evidence.extend(_flatten_evidence(item.get("metadata")))
        evidence.extend(_flatten_evidence(item.get("context")))

        ranked = self.catalog.rank(evidence)

        if not ranked:
            return CategoryAssignmentResult(
                **base,
                assignment_status="REVIEW_REQUIRED",
                confidence=0.0,
                reasons=("no_existing_category_match",),
                requires_human_validation=True,
            )

        best_score = ranked[0][0]
        best = [entry for entry in ranked if entry[0] == best_score]

        if len(best) != 1:
            return CategoryAssignmentResult(
                **base,
                assignment_status="AMBIGUOUS",
                confidence=best_score,
                reasons=("multiple_existing_categories_match",),
                requires_human_validation=True,
            )

        score, category, reason = best[0]

        if score < self.minimum_confidence:
            return CategoryAssignmentResult(
                **base,
                assignment_status="REVIEW_REQUIRED",
                confidence=score,
                reasons=("confidence_below_threshold", reason),
                requires_human_validation=True,
            )

        return CategoryAssignmentResult(
            **base,
            assignment_status="ASSIGNED",
            category_id=category.category_id,
            category_name=category.name,
            confidence=score,
            reasons=(reason,),
            requires_human_validation=True,
        )

    def assign_batch(
        self,
        payload: dict[str, Any] | Iterable[dict[str, Any]],
    ) -> dict[str, Any]:
        if isinstance(payload, dict):
            raw_results = payload.get("results", [])
            source_hash = payload.get("source_batch_hash")
        else:
            raw_results = payload
            source_hash = None

        if not isinstance(raw_results, Iterable):
            raise ValueError("SPT-023.2 payload debe contener results.")

        results = [
            self.assign(item)
            for item in raw_results
            if isinstance(item, dict)
        ]

        assigned = sum(
            item.assignment_status == "ASSIGNED"
            for item in results
        )
        review = sum(
            item.assignment_status in {"REVIEW_REQUIRED", "AMBIGUOUS"}
            for item in results
        )
        not_eligible = sum(
            item.assignment_status == "NOT_ELIGIBLE"
            for item in results
        )

        return {
            "component": "SPT-023.3",
            "source_component": "SPT-023.2",
            "source_batch_hash": source_hash,
            "records_processed": len(results),
            "assigned": assigned,
            "review_required": review,
            "not_eligible": not_eligible,
            "no_invention": all(item.no_invention for item in results),
            "automatic_category_creation": False,
            "requires_human_validation": True,
            "next_component": "SPT-023.4",
            "results": [item.to_dict() for item in results],
        }
'@

    $TestsPy = @'
from sgoda.integration.spt0233 import CategoryCatalog, Spt0233CategoryService


def catalog():
    return CategoryCatalog(
        [
            {
                "id": "CAT-ANIMAL",
                "name": "Animales",
                "aliases": ["animal"],
                "keywords": ["fauna"],
            },
            {
                "id": "CAT-PLANT",
                "name": "Plantas",
                "aliases": ["planta"],
                "keywords": ["flora"],
            },
        ]
    )


def ready(**extra):
    item = {
        "source_index": 1,
        "puinave": "AMDA",
        "lexical_hash": "abc",
        "institutional_decision": "READY_FOR_CATEGORY",
        "downstream_allowed": True,
        "semantic_status": "MATCHED",
        "semantic_candidates": [],
        "metadata": {},
    }
    item.update(extra)
    return item


def test_exact_existing_category_assignment():
    service = Spt0233CategoryService(catalog())
    result = service.assign(
        ready(semantic_candidates=[{"category": "Animales"}])
    )
    assert result.assignment_status == "ASSIGNED"
    assert result.category_id == "CAT-ANIMAL"
    assert result.no_invention is True


def test_alias_existing_category_assignment():
    service = Spt0233CategoryService(catalog())
    result = service.assign(
        ready(semantic_candidates=[{"category": "planta"}])
    )
    assert result.assignment_status == "ASSIGNED"
    assert result.category_id == "CAT-PLANT"


def test_keyword_existing_category_assignment():
    service = Spt0233CategoryService(catalog())
    result = service.assign(
        ready(semantic_candidates=[{"domain": "fauna"}])
    )
    assert result.assignment_status == "ASSIGNED"
    assert result.confidence == 0.85


def test_no_match_requires_review_and_creates_nothing():
    service = Spt0233CategoryService(catalog())
    before = service.catalog.categories
    result = service.assign(
        ready(semantic_candidates=[{"domain": "astronomia"}])
    )
    after = service.catalog.categories
    assert result.assignment_status == "REVIEW_REQUIRED"
    assert result.category_id is None
    assert before == after


def test_ambiguous_existing_categories_requires_review():
    service = Spt0233CategoryService(catalog())
    result = service.assign(
        ready(
            semantic_candidates=[
                {"category": "Animales"},
                {"category": "Plantas"},
            ]
        )
    )
    assert result.assignment_status == "AMBIGUOUS"
    assert result.requires_human_validation is True


def test_not_ready_input_is_blocked():
    service = Spt0233CategoryService(catalog())
    item = ready(institutional_decision="HUMAN_REVIEW_REQUIRED")
    result = service.assign(item)
    assert result.assignment_status == "NOT_ELIGIBLE"
    assert result.category_id is None


def test_spt0232_compatible_inference_from_downstream_allowed():
    service = Spt0233CategoryService(catalog())
    item = ready(
        institutional_decision="",
        semantic_candidates=[{"category": "Animales"}],
    )
    result = service.assign(item)
    assert result.assignment_status == "ASSIGNED"


def test_batch_contract_routes_to_spt0234_without_auto_creation():
    service = Spt0233CategoryService(catalog())
    batch = service.assign_batch(
        {
            "component": "SPT-023.2",
            "source_batch_hash": "batch-sha",
            "results": [
                ready(semantic_candidates=[{"category": "Animales"}]),
                ready(semantic_candidates=[{"domain": "astronomia"}]),
            ],
        }
    )
    assert batch["component"] == "SPT-023.3"
    assert batch["source_component"] == "SPT-023.2"
    assert batch["next_component"] == "SPT-023.4"
    assert batch["assigned"] == 1
    assert batch["review_required"] == 1
    assert batch["automatic_category_creation"] is False
    assert batch["no_invention"] is True


def test_duplicate_catalog_ids_are_rejected():
    try:
        CategoryCatalog(
            [
                {"id": "CAT-X", "name": "Uno"},
                {"id": "CAT-X", "name": "Dos"},
            ]
        )
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate category ids must fail")
'@

    $DocMd = @'
# SPT-023.3 - Capa 1 - Motor Institucional de Categorias

## Objetivo

Implementar la primera capa del motor de categorias confirmado por la
nomenclatura institucional SPT-023.3.

## Contrato de entrada

La capa consume exclusivamente resultados provenientes de SPT-023.2.

Solo los elementos con decision `READY_FOR_CATEGORY`, o los resultados
compatibles de SPT-023.2 con `downstream_allowed=true` y
`semantic_status=MATCHED`, pueden intentar una asignacion.

## Principios

- reutilizar exclusivamente categorias existentes;
- no crear categorias automaticamente;
- no inventar significado, traduccion o relacion linguistica;
- derivar a revision humana cuando no hay evidencia suficiente;
- derivar a revision humana cuando existen multiples categorias con
  la misma mejor evidencia;
- mantener `requires_human_validation=true`;
- conservar trazabilidad hacia SPT-023.2;
- entregar como siguiente componente SPT-023.4.

## Evidencia de asignacion

La coincidencia es deterministica:

1. nombre o alias exacto de una categoria existente: confianza 1.00;
2. keyword existente: confianza 0.85;
3. sin coincidencia: revision requerida;
4. multiples mejores coincidencias: ambigua y revision requerida.

La evidencia se limita a campos semanticos/contextuales ya presentes.
No se construye informacion linguistica nueva.

## Preservacion

Esta implementacion no modifica:

- SPT-007A;
- SPT-007B;
- SPT-023.1;
- SPT-023.2;
- FastAPI;
- n8n;
- PMO Digital;
- Auditor Institucional.

## Publicacion

La Capa 1 queda sometida a quality gate propio. Este instalador no
realiza commit ni push.
'@

    $Files = @{
        "src\sgoda\integration\spt0233\__init__.py" = $InitPy
        "src\sgoda\integration\spt0233\models.py" = $ModelsPy
        "src\sgoda\integration\spt0233\catalog.py" = $CatalogPy
        "src\sgoda\integration\spt0233\service.py" = $ServicePy
        "tests\integration\test_spt0233_category_engine.py" = $TestsPy
        "docs\06_Tecnologia\SPT-023.3\SGD-SPT023.3-Capa1-Motor-Categorias.md" = $DocMd
    }

    foreach ($Rel in $Files.Keys) {
        $FullTarget = Join-Path $Root $Rel

        if (Test-Path -LiteralPath $FullTarget -PathType Leaf) {
            Write-Host ("REUSED  : " + $Rel)
            continue
        }

        Write-Utf8Lf `
            -Path $FullTarget `
            -Content $Files[$Rel] `
            -CreatedFiles $CreatedFiles
        Write-Host ("CREATED : " + $Rel)
    }

    Write-Host ""
    Write-Host "[5/10] PYTHON SYNTAX PREVALIDATION" -ForegroundColor Yellow

    $Env:PYTHONPATH = Join-Path $Root "src"

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $VenvPython -m py_compile `
            (Join-Path $Root "src\sgoda\integration\spt0233\__init__.py") `
            (Join-Path $Root "src\sgoda\integration\spt0233\models.py") `
            (Join-Path $Root "src\sgoda\integration\spt0233\catalog.py") `
            (Join-Path $Root "src\sgoda\integration\spt0233\service.py") `
            (Join-Path $Root "tests\integration\test_spt0233_category_engine.py")
        $CompileCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }

    if ($CompileCode -ne 0) {
        throw "SPT-023.3 Python syntax prevalidation failed."
    }

    Write-Host "PYTHON SYNTAX : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[6/10] TARGETED QUALITY GATE" -ForegroundColor Yellow

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $TargetOutput = @(
            & $VenvPython -m pytest `
                "tests/integration/test_spt0233_category_engine.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }

    if ($TargetCode -ne 0) {
        throw "SPT-023.3 targeted tests failed."
    }

    $TargetText = ($TargetOutput | ForEach-Object { [string]$_ }) -join "`n"
    $TargetMatch = [regex]::Match($TargetText, '(\d+)\s+passed')

    if (-not $TargetMatch.Success) {
        throw "Unable to certify targeted test count."
    }

    $TargetPassed = [int]$TargetMatch.Groups[1].Value

    if ($TargetPassed -lt 9) {
        throw "Expected at least 9 targeted tests."
    }

    Write-Host "TARGETED TESTS : $TargetPassed PASSED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[7/10] INSTITUTIONAL SUITE" -ForegroundColor Yellow

    $PreviousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $SuiteOutput = @(& $VenvPython -m pytest -q 2>&1)
        $SuiteCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousEAP
    }

    $SuiteOutput | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }

    if ($SuiteCode -ne 0) {
        throw "Institutional pytest suite failed."
    }

    $SuiteText = ($SuiteOutput | ForEach-Object { [string]$_ }) -join "`n"
    $SuiteMatch = [regex]::Match($SuiteText, '(\d+)\s+passed')

    if (-not $SuiteMatch.Success) {
        throw "Unable to certify institutional test count."
    }

    $SuitePassed = [int]$SuiteMatch.Groups[1].Value

    if ($SuitePassed -lt 870) {
        throw "Institutional suite did not include the 861 baseline plus 9 new tests."
    }

    Write-Host "INSTITUTIONAL TESTS : $SuitePassed PASSED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[8/10] PRESERVATION SHA-256 GATE" -ForegroundColor Yellow

    $ProtectedAfter = Get-TrackedHashMap -Root $Root -Paths $Protected
    $ProtectedChanges = @(Compare-HashMaps -Before $ProtectedBefore -After $ProtectedAfter)

    Write-Host "PROTECTED FILES CHANGED : $($ProtectedChanges.Count)"

    if ($ProtectedChanges.Count -ne 0) {
        $ProtectedChanges | ForEach-Object { Write-Host ("CHANGED: " + $_) -ForegroundColor Red }
        throw "Protected SPT-023.1/SPT-023.2 files changed."
    }

    Write-Host "SPT-023.1 / SPT-023.2 SHA-256 : PRESERVED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[9/10] IMPLEMENTATION EVIDENCE" -ForegroundColor Yellow

    $EvidenceDir = Join-Path $Root ("artifacts\development\SPT-023.3-v1.0.1\runs\" + $RunId)
    if (-not (Test-Path -LiteralPath $EvidenceDir)) {
        New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
    }

    $EvidencePath = Join-Path $EvidenceDir "implementation-evidence.json"

    $GeneratedHashes = @()
    foreach ($Rel in $Files.Keys | Sort-Object) {
        $Full = Join-Path $Root $Rel
        $GeneratedHashes += [ordered]@{
            path = $Rel.Replace("\","/")
            sha256 = (Get-FileHash -LiteralPath $Full -Algorithm SHA256).Hash
        }
    }

    $Evidence = [ordered]@{
        schema_version = "1.0.1"
        component = "SPT-023.3"
        layer = "Capa 1"
        title = "Motor Institucional de Categorias"
        run_id = $RunId
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedHead
        source_component = "SPT-023.2"
        next_component = "SPT-023.4"
        policy = [ordered]@{
            reuse_existing_categories = $true
            automatic_category_creation = $false
            no_invention = $true
            human_validation = $true
        }
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ProtectedChanges.Count
        resume_mode = ($ExistingTargets.Count -eq $Targets.Count)
        generated_files = $GeneratedHashes
        commit = $false
        push = $false
    }

    Write-Utf8Lf `
        -Path $EvidencePath `
        -Content ($Evidence | ConvertTo-Json -Depth 8) `
        -CreatedFiles $CreatedFiles

    Write-Host "EVIDENCE : $EvidencePath"

    Write-Host ""
    Write-Host "[10/10] FINAL GIT SAFETY" -ForegroundColor Yellow

    $HeadAfter = Invoke-GitSingleLine @("rev-parse","HEAD")
    $StagedAfter = @(Invoke-GitLines @("diff","--cached","--name-only"))
    $DeletedAfter = @(Invoke-GitLines @("ls-files","--deleted"))

    Write-Host "HEAD AFTER      : $HeadAfter"
    Write-Host "STAGED AFTER    : $($StagedAfter.Count)"
    Write-Host "DELETED TRACKED : $($DeletedAfter.Count)"

    if ($HeadAfter -ne $ExpectedHead) { throw "HEAD changed during implementation." }
    if ($StagedAfter.Count -ne 0) { throw "Installer unexpectedly changed staging." }
    if ($DeletedAfter.Count -ne 0) { throw "Tracked deletions detected." }

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host " SPT-023.3 CAPA 1 v1.0.1 : IMPLEMENTED / QUALITY GATE PASS" -ForegroundColor Green
    Write-Host " MOTOR            : EXISTING-CATEGORY ASSIGNMENT" -ForegroundColor Green
    Write-Host " AUTO-CREATION    : DISABLED" -ForegroundColor Green
    Write-Host " NO-INVENTION     : ENFORCED" -ForegroundColor Green
    Write-Host " TARGETED TESTS   : $TargetPassed PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE       : $SuitePassed PASSED" -ForegroundColor Green
    Write-Host " SPT-023.1/.2     : SHA-256 PRESERVED" -ForegroundColor Green
    Write-Host " COMMIT / PUSH    : NO" -ForegroundColor Green
    Write-Host " NEXT             : REVIEW + CONTROLLED PUBLICATION" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green

    exit 0
}
catch {
    Stop-Install -Message $_.Exception.Message -CreatedFiles $CreatedFiles
}
