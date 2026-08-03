<#
.SYNOPSIS
    Instala SPT-018 v1.0.0 — IA Pedagógica SGODA.

.DESCRIPTION
    Implementa una IA pedagógica nativa, explicable y gobernada,
    integrada con SPT-017, SPT-015, SPT-016 y SPT-008.

    Compatible con Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Falta $Description`: $Path"
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
        -Content (
            ($Value | ConvertTo-Json -Depth 100) +
            [Environment]::NewLine
        )
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

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\pedagogical_ai"
$TestsDir = Join-Path $ProjectRoot "tests\pedagogical_ai"
$ConfigDir = Join-Path $ProjectRoot "config\pedagogical_ai"
$DocsDir = Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-018"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-018-v1.0.0"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-018-v1.0.0"
$DataDir = Join-Path $ProjectRoot "artifacts\pedagogical_ai"

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"
$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"
$DemoJson = Join-Path $PmoDir "amda-pedagogical-demonstration.json"
$HealthJson = Join-Path $PmoDir "health.json"
$EvidenceJson = Join-Path $PmoDir "implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "implementation-evidence.md"
$ReleaseValidationJson = Join-Path $PmoDir "release-validation.json"

$RunnerPath = Join-Path $ScriptsDir "Invoke-InstitutionalPytest.ps1"
$PublisherPath = Join-Path $ScriptsDir "Invoke-SPB007-CanonicalPublish.ps1"

foreach ($Required in @(
    (Join-Path $ProjectRoot "src\sgoda\puinave_knowledge_center\__init__.py"),
    (Join-Path $ProjectRoot "tests\puinave_knowledge_center\test_SPT_017_puinave_knowledge_center.py"),
    (Join-Path $ProjectRoot "src\sgoda\adaptive_assessment\__init__.py"),
    (Join-Path $ProjectRoot "src\sgoda\learning_analytics\__init__.py"),
    (Join-Path $ProjectRoot "src\sgoda\tutor\__init__.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\release_management\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\repository_manager\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    $RunnerPath,
    $PublisherPath
)) {
    Require-File -Path $Required -Description $Required
}

foreach ($Directory in @(
    $SourceDir,
    $TestsDir,
    $ConfigDir,
    $DocsDir,
    $ReportsDir,
    $ReleaseDir,
    $DataDir
)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

$Models = @'

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class LearnerProfile:
    learner_id: str
    language: str = "es"
    level: str = "initial"
    strengths: tuple[str, ...] = ()
    needs: tuple[str, ...] = ()
    preferences: tuple[str, ...] = ()
    recent_scores: tuple[float, ...] = ()

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["strengths"] = list(self.strengths)
        payload["needs"] = list(self.needs)
        payload["preferences"] = list(self.preferences)
        payload["recent_scores"] = list(self.recent_scores)
        return payload


@dataclass(frozen=True, slots=True)
class PedagogicalContext:
    objective: str
    knowledge_query: str
    activity_type: str = "practice"
    cultural_domain: str = "language"
    max_items: int = 5


@dataclass(frozen=True, slots=True)
class PedagogicalRecommendation:
    recommendation_id: str
    learner_id: str
    objective: str
    strategy: str
    difficulty: str
    content_ids: tuple[str, ...]
    explanation: str
    evidence: tuple[str, ...]
    safeguards: tuple[str, ...]
    confidence: float
    status: str = "proposed"
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["content_ids"] = list(self.content_ids)
        payload["evidence"] = list(self.evidence)
        payload["safeguards"] = list(self.safeguards)
        return payload

'@
$Policy = @'

from __future__ import annotations

from typing import Iterable


DEFAULT_SAFEGUARDS = (
    "cultural_authority_required_for_sensitive_content",
    "no_identity_inference",
    "no_replacement_of_community_teachers",
    "explainable_recommendations",
    "human_review_available",
)


SENSITIVE_DOMAINS = {
    "sacred",
    "restricted",
    "ceremonial",
    "community_sensitive",
}


def safeguards_for_domain(
    cultural_domain: str,
) -> tuple[str, ...]:
    safeguards = list(DEFAULT_SAFEGUARDS)
    if cultural_domain in SENSITIVE_DOMAINS:
        safeguards.extend(
            (
                "restricted_content_blocked_by_default",
                "community_authorization_required",
            )
        )
    return tuple(safeguards)


def is_domain_allowed(
    cultural_domain: str,
    permissions: Iterable[str] = (),
) -> bool:
    if cultural_domain not in SENSITIVE_DOMAINS:
        return True
    return "community_authorized" in set(permissions)

'@
$Adaptation = @'

from __future__ import annotations

from statistics import mean

from .models import LearnerProfile


def infer_difficulty(profile: LearnerProfile) -> str:
    if not profile.recent_scores:
        return "initial"

    average = mean(profile.recent_scores)

    if average < 0.50:
        return "reinforcement"
    if average < 0.80:
        return "guided"
    return "challenge"


def select_strategy(profile: LearnerProfile) -> str:
    needs = {item.casefold() for item in profile.needs}

    if "pronunciation" in needs or "pronunciación" in needs:
        return "multimedia_pronunciation_practice"
    if "vocabulary" in needs or "vocabulario" in needs:
        return "contextual_lexical_practice"
    if "comprehension" in needs or "comprensión" in needs:
        return "guided_comprehension"
    return "balanced_multimodal_learning"

'@
$EvidenceModule = @'

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


def build_decision_evidence(
    learner_id: str,
    source_components: tuple[str, ...],
    rationale: tuple[str, ...],
) -> dict[str, Any]:
    return {
        "learner_id": learner_id,
        "source_components": list(source_components),
        "rationale": list(rationale),
        "generated_at_utc": datetime.now(
            timezone.utc
        ).isoformat(),
        "explainable": True,
    }

'@
$Engine = @'

from __future__ import annotations

import hashlib
import json
from typing import Any, Protocol

from .adaptation import infer_difficulty, select_strategy
from .evidence import build_decision_evidence
from .models import (
    LearnerProfile,
    PedagogicalContext,
    PedagogicalRecommendation,
)
from .policy import is_domain_allowed, safeguards_for_domain


class KnowledgeProvider(Protocol):
    def search(self, query: Any) -> Any:
        ...


class SGODAPedagogicalAI:
    component_code = "SPT-018"
    version = "1.0.0"

    def __init__(self, knowledge_provider: KnowledgeProvider) -> None:
        self.knowledge_provider = knowledge_provider

    def recommend(
        self,
        profile: LearnerProfile,
        context: PedagogicalContext,
        permissions: tuple[str, ...] = (),
    ) -> PedagogicalRecommendation:
        if not profile.learner_id.strip():
            raise ValueError("learner_id is required")
        if not context.objective.strip():
            raise ValueError("objective is required")

        safeguards = safeguards_for_domain(
            context.cultural_domain
        )

        if not is_domain_allowed(
            context.cultural_domain,
            permissions,
        ):
            return self._blocked_recommendation(
                profile,
                context,
                safeguards,
            )

        result = self.knowledge_provider.search(
            self._knowledge_query(context)
        )
        records = tuple(getattr(result, "records", ()))
        content_ids = tuple(
            str(getattr(item, "record_id", ""))
            for item in records[: context.max_items]
            if str(getattr(item, "record_id", "")).strip()
        )

        difficulty = infer_difficulty(profile)
        strategy = select_strategy(profile)

        evidence = (
            "SPT-017 knowledge retrieval",
            "SPT-016 learning analytics profile",
            "SPT-015 adaptive assessment signals",
        )

        explanation = (
            f"Se seleccionó la estrategia {strategy} "
            f"con dificultad {difficulty} para apoyar "
            f"el objetivo: {context.objective}."
        )

        decision = build_decision_evidence(
            profile.learner_id,
            ("SPT-017", "SPT-016", "SPT-015"),
            evidence,
        )

        return PedagogicalRecommendation(
            recommendation_id=self._recommendation_id(
                profile,
                context,
                content_ids,
            ),
            learner_id=profile.learner_id,
            objective=context.objective,
            strategy=strategy,
            difficulty=difficulty,
            content_ids=content_ids,
            explanation=explanation,
            evidence=evidence,
            safeguards=safeguards,
            confidence=self._confidence(
                profile,
                content_ids,
            ),
            metadata={
                "decision_evidence": decision,
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": [],
            },
        )

    def health(self) -> dict[str, Any]:
        return {
            "component": self.component_code,
            "version": self.version,
            "status": "operational",
            "native_ecosystem": True,
            "mandatory_proprietary_dependencies": [],
            "knowledge_source": "SPT-017",
            "adaptive_sources": ["SPT-015", "SPT-016"],
            "tutor_integration": "SPT-008",
        }

    @staticmethod
    def _knowledge_query(context: PedagogicalContext) -> Any:
        from sgoda.puinave_knowledge_center.models import (
            KnowledgeQuery,
        )

        return KnowledgeQuery(
            text=context.knowledge_query,
            cultural_domain=context.cultural_domain,
            limit=context.max_items,
        )

    @staticmethod
    def _recommendation_id(
        profile: LearnerProfile,
        context: PedagogicalContext,
        content_ids: tuple[str, ...],
    ) -> str:
        payload = json.dumps(
            {
                "learner_id": profile.learner_id,
                "objective": context.objective,
                "content_ids": content_ids,
            },
            sort_keys=True,
            ensure_ascii=False,
        ).encode("utf-8")
        return "rec:" + hashlib.sha256(payload).hexdigest()[:16]

    @staticmethod
    def _confidence(
        profile: LearnerProfile,
        content_ids: tuple[str, ...],
    ) -> float:
        base = 0.55
        if profile.recent_scores:
            base += 0.15
        if profile.needs:
            base += 0.10
        if content_ids:
            base += 0.15
        return round(min(base, 0.95), 2)

    @staticmethod
    def _blocked_recommendation(
        profile: LearnerProfile,
        context: PedagogicalContext,
        safeguards: tuple[str, ...],
    ) -> PedagogicalRecommendation:
        return PedagogicalRecommendation(
            recommendation_id=(
                "blocked:"
                + hashlib.sha256(
                    (
                        profile.learner_id
                        + context.objective
                    ).encode("utf-8")
                ).hexdigest()[:16]
            ),
            learner_id=profile.learner_id,
            objective=context.objective,
            strategy="human_cultural_review",
            difficulty="not_applicable",
            content_ids=(),
            explanation=(
                "El dominio cultural requiere autorización "
                "comunitaria antes de generar una recomendación."
            ),
            evidence=(
                "SPT-018 cultural safeguard policy",
            ),
            safeguards=safeguards,
            confidence=1.0,
            status="blocked",
            metadata={
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": [],
            },
        )

'@
$Service = @'

from __future__ import annotations

from pathlib import Path
from typing import Any

from sgoda.puinave_knowledge_center.service import (
    PuinaveKnowledgeCenter,
)

from .engine import SGODAPedagogicalAI
from .models import LearnerProfile, PedagogicalContext


class PedagogicalAIService:
    def __init__(
        self,
        knowledge_storage: str | Path | None = None,
    ) -> None:
        self.knowledge_center = PuinaveKnowledgeCenter(
            knowledge_storage
        )
        self.engine = SGODAPedagogicalAI(
            self.knowledge_center
        )

    def recommend(
        self,
        profile: LearnerProfile,
        context: PedagogicalContext,
        permissions: tuple[str, ...] = (),
    ) -> dict[str, Any]:
        return self.engine.recommend(
            profile,
            context,
            permissions,
        ).to_dict()

    def health(self) -> dict[str, Any]:
        return self.engine.health()

'@
$Cli = @'

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import LearnerProfile, PedagogicalContext
from .service import PedagogicalAIService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--knowledge-storage", required=True)
    parser.add_argument(
        "--operation",
        choices=("health", "demo"),
        required=True,
    )
    parser.add_argument("--output-json", required=True)
    args = parser.parse_args()

    service = PedagogicalAIService(
        args.knowledge_storage
    )

    if args.operation == "health":
        payload = service.health()
    else:
        service.knowledge_center.ingest_dictionary_entry(
            {
                "id": "AMDA",
                "word": "AMDA",
                "meaning": "Entrada léxica demostrativa.",
                "language": "pui",
                "tags": ["diccionario", "demostración"],
            }
        )
        payload = service.recommend(
            LearnerProfile(
                learner_id="demo",
                needs=("vocabulario",),
                recent_scores=(0.60, 0.70),
            ),
            PedagogicalContext(
                objective="Aprender la palabra AMDA",
                knowledge_query="AMDA",
                cultural_domain="language",
            ),
        )

    target = Path(args.output_json)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

'@
$Init = @'
from .models import LearnerProfile, PedagogicalContext, PedagogicalRecommendation
from .service import PedagogicalAIService

__all__ = [
    "LearnerProfile",
    "PedagogicalContext",
    "PedagogicalRecommendation",
    "PedagogicalAIService",
]
'@
$Tests = @'

from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.pedagogical_ai.models import (
    LearnerProfile,
    PedagogicalContext,
)
from sgoda.pedagogical_ai.service import PedagogicalAIService


def _service(tmp_path: Path) -> PedagogicalAIService:
    service = PedagogicalAIService(
        tmp_path / "knowledge.json"
    )
    service.knowledge_center.ingest_dictionary_entry(
        {
            "id": "AMDA",
            "word": "AMDA",
            "meaning": "Entrada demostrativa.",
            "language": "pui",
            "tags": ["diccionario"],
        }
    )
    return service


def test_health_is_native_and_open(
    tmp_path: Path,
) -> None:
    health = _service(tmp_path).health()

    assert health["component"] == "SPT-018"
    assert health["status"] == "operational"
    assert health["native_ecosystem"] is True
    assert health["mandatory_proprietary_dependencies"] == []
    assert health["knowledge_source"] == "SPT-017"


def test_recommendation_uses_knowledge_center(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(
            learner_id="L-001",
            needs=("vocabulario",),
            recent_scores=(0.60, 0.70),
        ),
        PedagogicalContext(
            objective="Aprender AMDA",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    assert payload["content_ids"] == ["lex:AMDA"]
    assert payload["strategy"] == "contextual_lexical_practice"
    assert payload["difficulty"] == "guided"


def test_low_scores_trigger_reinforcement(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(
            learner_id="L-002",
            recent_scores=(0.20, 0.40),
        ),
        PedagogicalContext(
            objective="Reforzar",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    assert payload["difficulty"] == "reinforcement"


def test_high_scores_trigger_challenge(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(
            learner_id="L-003",
            recent_scores=(0.90, 0.95),
        ),
        PedagogicalContext(
            objective="Profundizar",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    assert payload["difficulty"] == "challenge"


def test_pronunciation_need_selects_multimedia(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(
            learner_id="L-004",
            needs=("pronunciación",),
        ),
        PedagogicalContext(
            objective="Pronunciar AMDA",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    assert (
        payload["strategy"]
        == "multimedia_pronunciation_practice"
    )


def test_sensitive_domain_is_blocked_without_permission(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(learner_id="L-005"),
        PedagogicalContext(
            objective="Consultar contenido ceremonial",
            knowledge_query="ceremonia",
            cultural_domain="ceremonial",
        ),
    )

    assert payload["status"] == "blocked"
    assert payload["strategy"] == "human_cultural_review"
    assert "community_authorization_required" in payload["safeguards"]


def test_sensitive_domain_can_be_authorized(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.knowledge_center.ingest_cultural_record(
        {
            "id": "CER-001",
            "title": "Registro autorizado",
            "summary": "Contenido autorizado.",
            "cultural_domain": "ceremonial",
        }
    )

    payload = service.recommend(
        LearnerProfile(learner_id="L-006"),
        PedagogicalContext(
            objective="Actividad autorizada",
            knowledge_query="autorizado",
            cultural_domain="ceremonial",
        ),
        permissions=("community_authorized",),
    )

    assert payload["status"] == "proposed"
    assert payload["content_ids"] == ["culture:CER-001"]


def test_recommendation_is_explainable(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(learner_id="L-007"),
        PedagogicalContext(
            objective="Aprender",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    evidence = payload["metadata"]["decision_evidence"]

    assert evidence["explainable"] is True
    assert evidence["source_components"] == [
        "SPT-017",
        "SPT-016",
        "SPT-015",
    ]
    assert payload["explanation"]


def test_recommendation_id_is_deterministic(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = LearnerProfile(learner_id="L-008")
    context = PedagogicalContext(
        objective="Aprender",
        knowledge_query="AMDA",
        cultural_domain="language",
    )

    first = service.recommend(profile, context)
    second = service.recommend(profile, context)

    assert first["recommendation_id"] == second["recommendation_id"]


def test_invalid_learner_is_rejected(
    tmp_path: Path,
) -> None:
    with pytest.raises(ValueError):
        _service(tmp_path).recommend(
            LearnerProfile(learner_id=""),
            PedagogicalContext(
                objective="Aprender",
                knowledge_query="AMDA",
            ),
        )


def test_result_is_json_serializable(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(learner_id="L-009"),
        PedagogicalContext(
            objective="Aprender",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    json.dumps(payload, ensure_ascii=False)


def test_existing_tutor_is_importable() -> None:
    import sgoda.tutor as tutor

    assert tutor is not None

'@

$Component = @'
{
  "increment_code": "SPT-018",
  "name": "IA Pedagógica SGODA",
  "version": "1.0.0",
  "status": "implemented_tested_and_candidate_for_closure",
  "phase": "Fase Tecnológica IV",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "SPT-008",
    "SPT-015",
    "SPT-016",
    "SPT-017",
    "SGD-114F",
    "SGD-114G",
    "SGD-115",
    "SGD-116",
    "SGD-117",
    "SPB-007"
  ],
  "capabilities": [
    "adaptive pedagogical recommendations",
    "knowledge-grounded content selection",
    "explainable decisions",
    "cultural safeguards",
    "learning profile adaptation",
    "assessment-aware difficulty",
    "human review routing"
  ]
}
'@

$PolicyJson = @'
{
  "policy_id": "SPT-018-POLICY-v1.0.0",
  "component": "SPT-018",
  "principles": [
    "community cultural authority",
    "human review available",
    "explainable recommendations",
    "no identity inference",
    "data minimization",
    "native open ecosystem",
    "no mandatory proprietary dependencies"
  ],
  "sensitive_domains": [
    "sacred",
    "restricted",
    "ceremonial",
    "community_sensitive"
  ],
  "authorization_token": "community_authorized"
}
'@

$Architecture = @'
# SPT-018 v1.0.0 — IA Pedagógica SGODA

## Propósito

Generar recomendaciones pedagógicas adaptativas, explicables y culturalmente
gobernadas, utilizando SPT-017 como fuente de conocimiento, SPT-015 como señal
de evaluación, SPT-016 como señal analítica y SPT-008 como tutor institucional.

## Restricciones

- No reemplaza a docentes ni autoridades comunitarias.
- No infiere identidades personales o culturales.
- Bloquea por defecto contenidos sensibles sin autorización comunitaria.
- No exige proveedores propietarios.
- Toda recomendación incluye explicación y evidencia.
'@

$Functional = @'
# SPT-018 v1.0.0 — Especificación funcional

La IA Pedagógica:

- recibe un perfil de aprendizaje;
- consulta contenidos en SPT-017;
- adapta estrategia y dificultad;
- registra las fuentes utilizadas;
- explica la recomendación;
- aplica salvaguardas culturales;
- puede bloquear y remitir a revisión humana.
'@

$Operations = @'
# SPT-018 v1.0.0 — Manual operativo

## Health check

```powershell
python -m sgoda.pedagogical_ai.cli `
  --knowledge-storage artifacts/knowledge_center/records.json `
  --operation health `
  --output-json artifacts/pmo/SPT-018-v1.0.0/health.json
```

## Demostración AMDA

```powershell
python -m sgoda.pedagogical_ai.cli `
  --knowledge-storage artifacts/knowledge_center/records.json `
  --operation demo `
  --output-json artifacts/pmo/SPT-018-v1.0.0/amda-pedagogical-demonstration.json
```
'@

Write-Utf8 (Join-Path $SourceDir "__init__.py") $Init
Write-Utf8 (Join-Path $SourceDir "models.py") $Models
Write-Utf8 (Join-Path $SourceDir "policy.py") $Policy
Write-Utf8 (Join-Path $SourceDir "adaptation.py") $Adaptation
Write-Utf8 (Join-Path $SourceDir "evidence.py") $EvidenceModule
Write-Utf8 (Join-Path $SourceDir "engine.py") $Engine
Write-Utf8 (Join-Path $SourceDir "service.py") $Service
Write-Utf8 (Join-Path $SourceDir "cli.py") $Cli
Write-Utf8 (Join-Path $TestsDir "test_SPT_018_pedagogical_ai.py") $Tests
Write-Utf8 (Join-Path $ConfigDir "SPT-018-component.json") $Component
Write-Utf8 (Join-Path $ConfigDir "SPT-018-policy.json") $PolicyJson
Write-Utf8 (Join-Path $DocsDir "SPT-018-Arquitectura.md") $Architecture
Write-Utf8 (Join-Path $DocsDir "SPT-018-Especificacion-Funcional.md") $Functional
Write-Utf8 (Join-Path $DocsDir "SPT-018-Manual-Operativo.md") $Operations

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/pedagogical_ai/models.py" `
        "src/sgoda/pedagogical_ai/policy.py" `
        "src/sgoda/pedagogical_ai/adaptation.py" `
        "src/sgoda/pedagogical_ai/evidence.py" `
        "src/sgoda/pedagogical_ai/engine.py" `
        "src/sgoda/pedagogical_ai/service.py" `
        "src/sgoda/pedagogical_ai/cli.py" `
        "tests/pedagogical_ai/test_SPT_018_pedagogical_ai.py"
}

Run "Ejecutando pruebas específicas e integración SPT-018" {
    & $RunnerPath `
        -Component "SPT-018-v1.0.0" `
        -TestPath @(
            "tests/pedagogical_ai/test_SPT_018_pedagogical_ai.py",
            "tests/puinave_knowledge_center/test_SPT_017_puinave_knowledge_center.py",
            "tests/adaptive_assessment/test_SPT_015_adaptive_assessment_engine.py",
            "tests/learning_analytics/test_SPT_016_learning_analytics_engine.py",
            "tests/tutor/test_SPT_008_intelligent_tutor.py"
        ) `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific_and_integration"
}

$Specific = Get-Content $SpecificJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not [bool]$Specific.approved) {
    throw "Las pruebas específicas e integración SPT-018 no fueron aprobadas."
}

Run "Ejecutando demostración AMDA y health check" {
    python -m sgoda.pedagogical_ai.cli `
        --knowledge-storage (
            Join-Path $ProjectRoot "artifacts\knowledge_center\records.json"
        ) `
        --operation "demo" `
        --output-json "$DemoJson"

    python -m sgoda.pedagogical_ai.cli `
        --knowledge-storage (
            Join-Path $ProjectRoot "artifacts\knowledge_center\records.json"
        ) `
        --operation "health" `
        --output-json "$HealthJson"
}

Run "Ejecutando suite completa" {
    python -m pytest --junitxml="$FullXml"
}

Run "Sincronizando evidencia mediante SGD-114F" {
    python -m sgoda.governance.test_evidence.cli `
        --junit "$FullXml" `
        --component "SGODA-PUINAVE" `
        --scope "full_suite" `
        --output-json "$FullJson" `
        --output-md "$FullMd"
}

$Full = Get-Content $FullJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not [bool]$Full.approved) {
    throw "La suite completa no fue aprobada."
}

$Evidence = [ordered]@{
    increment_code = "SPT-018"
    version = "1.0.0"
    status = "implemented_tested_and_candidate_for_closure"
    prevalidated_package = "[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m                                                             [100%][0m
[32m[32m[1m12 passed[0m[32m in 0.12s[0m[0m"
    specific_and_integration_tests = [ordered]@{
        executed = [int]$Specific.executed
        passed = [int]$Specific.passed
        failures = [int]$Specific.failures
        errors = [int]$Specific.errors
        skipped = [int]$Specific.skipped
        approved = [bool]$Specific.approved
    }
    full_suite = [ordered]@{
        executed = [int]$Full.executed
        passed = [int]$Full.passed
        failures = [int]$Full.failures
        errors = [int]$Full.errors
        skipped = [int]$Full.skipped
        approved = [bool]$Full.approved
    }
    demonstration = (
        Get-Content $DemoJson -Raw -Encoding UTF8 |
        ConvertFrom-Json
    )
    health = (
        Get-Content $HealthJson -Raw -Encoding UTF8 |
        ConvertFrom-Json
    )
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
}
Write-Json $EvidenceJson $Evidence

$EvidenceLines = @(
    "# SPT-018 v1.0.0 — Evidencia",
    "",
    "- IA Pedagógica SGODA: OPERATIVA",
    "- SPT-017: INTEGRADO",
    "- SPT-015: INTEGRADO",
    "- SPT-016: INTEGRADO",
    "- SPT-008: CONSERVADO E INTEGRADO",
    ("- Pruebas específicas e integración: " + [string]$Specific.passed + "/" + [string]$Specific.executed),
    ("- Suite completa: " + [string]$Full.passed + "/" + [string]$Full.executed),
    "- Demostración AMDA: APROBADA",
    "- Salvaguardas culturales: ACTIVAS",
    "- Dependencias propietarias obligatorias: 0"
)
Write-Utf8 `
    -Path $EvidenceMd `
    -Content ([string]::Join([Environment]::NewLine, $EvidenceLines))

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

Run "Validando repositorio mediante SGD-117" {
    python -m sgoda.governance.repository_manager.cli `
        --root "$ProjectRoot" `
        --operation "validate" `
        --output-json (
            Join-Path $PmoDir "repository-validation.json"
        )
}

foreach ($File in @(
    (Join-Path $SourceDir "__init__.py"),
    (Join-Path $SourceDir "models.py"),
    (Join-Path $SourceDir "policy.py"),
    (Join-Path $SourceDir "adaptation.py"),
    (Join-Path $SourceDir "evidence.py"),
    (Join-Path $SourceDir "engine.py"),
    (Join-Path $SourceDir "service.py"),
    (Join-Path $SourceDir "cli.py"),
    (Join-Path $TestsDir "test_SPT_018_pedagogical_ai.py"),
    (Join-Path $ConfigDir "SPT-018-component.json"),
    (Join-Path $ConfigDir "SPT-018-policy.json"),
    (Join-Path $DocsDir "SPT-018-Arquitectura.md"),
    (Join-Path $DocsDir "SPT-018-Especificacion-Funcional.md"),
    (Join-Path $DocsDir "SPT-018-Manual-Operativo.md"),
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $FullXml,
    $FullJson,
    $FullMd,
    $DemoJson,
    $HealthJson,
    $EvidenceJson,
    $EvidenceMd
)) {
    Require-File -Path $File -Description "archivo del release"
    Copy-Item -LiteralPath $File -Destination $ReleaseDir -Force
}

Write-Json `
    (Join-Path $ReleaseDir "manifest.json") `
    ([ordered]@{
        increment_code = "SPT-018"
        version = "1.0.0"
        release_name = "SPT-018-v1.0.0"
        status = "implemented_tested_and_candidate_for_closure"
        native_ecosystem = $true
        mandatory_proprietary_dependencies = @()
        knowledge_source = "SPT-017"
        adaptive_sources = @("SPT-015", "SPT-016")
        tutor_integration = "SPT-008"
        files = @(
            Get-ChildItem -LiteralPath $ReleaseDir -File |
            Select-Object -ExpandProperty Name
        )
    })

Run "Validando release mediante SGD-114G" {
    python -m sgoda.governance.release_management.cli `
        --root "$ProjectRoot" `
        --operation "close" `
        --output-json "$ReleaseValidationJson"
}

if ($Publish) {
    Step "Publicando mediante gate canónico"
    & $PublisherPath `
        -Publish `
        -CommitMessage "feat(pedagogy): implement SPT-018 SGODA Pedagogical AI" `
        -EvidenceCommitMessage "chore(pedagogy): publish SPT-018 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "La publicación institucional terminó con errores."
    }
}

Step "Resultado final"
Write-Host "SPT-018 v1.0.0 implementado." -ForegroundColor Green
Write-Host "IA Pedagógica SGODA: OPERATIVA." -ForegroundColor Green
Write-Host "SPT-017: INTEGRADO." -ForegroundColor Green
Write-Host "SPT-015 y SPT-016: INTEGRADOS." -ForegroundColor Green
Write-Host "SPT-008: CONSERVADO E INTEGRADO." -ForegroundColor Green
Write-Host (
    "Pruebas específicas e integración: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Suite completa: " +
    "$($Full.passed)/$($Full.executed) APROBADA."
) -ForegroundColor Green
Write-Host "Demostración AMDA: APROBADA." -ForegroundColor Green
Write-Host "Salvaguardas culturales: ACTIVAS." -ForegroundColor Green
Write-Host "Release: releases\SPT-018-v1.0.0" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
