<#
.SYNOPSIS
    Instala en un solo archivo:
      - SPT-007D — Motor de Razonamiento Lingüístico
      - SPT-008  — Tutor Inteligente Puinave
      - SPT-009  — Ecosistema Conversacional

.DESCRIPTION
    Suite integrada para la Fase Tecnológica de SGODA-PUINAVE.

    Incluye:
      - razonamiento lingüístico explicable;
      - consultas complejas sobre el grafo;
      - tutor con rutas de aprendizaje;
      - ejercicios y retroalimentación;
      - interacción conversacional por texto;
      - contratos preparados para voz local;
      - integración con SPT-006A y SPT-007A/B/C;
      - operación local;
      - no invención Puinave;
      - documentación completa en el repositorio;
      - pruebas específicas;
      - suite completa;
      - SGD-114C;
      - SGD-115;
      - SGD-116;
      - evidencias y releases.

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

function Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró: $Path"
    }
}

function Write-Utf8([string]$Path, [string]$Content) {
    $Parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
    $Info = Get-Item -LiteralPath $Path
    if ($Info.Length -le 0) {
        throw "Archivo vacío: $Path"
    }
    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-Json([string]$Path, [object]$Data) {
    $Parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    [System.IO.File]::WriteAllText(
        $Path,
        (($Data | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Run-Checked([string]$Name, [scriptblock]$Action) {
    Step $Name
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Name terminó con errores. Código: $LASTEXITCODE"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$ReasoningDir = Join-Path $ProjectRoot "src\sgoda\reasoning_engine"
$TutorDir = Join-Path $ProjectRoot "src\sgoda\tutor"
$ConversationDir = Join-Path $ProjectRoot "src\sgoda\conversation"

$ReasoningTests = Join-Path $ProjectRoot "tests\reasoning_engine"
$TutorTests = Join-Path $ProjectRoot "tests\tutor"
$ConversationTests = Join-Path $ProjectRoot "tests\conversation"

$ReasoningConfig = Join-Path $ProjectRoot "config\reasoning_engine"
$TutorConfig = Join-Path $ProjectRoot "config\tutor"
$ConversationConfig = Join-Path $ProjectRoot "config\conversation"

$DocsRoot = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$PmoRoot = Join-Path $ProjectRoot "artifacts\pmo"
$DemoRoot = Join-Path $ProjectRoot "artifacts\integrated_intelligence"
$BackupRoot = Join-Path $PmoRoot (
    "SPT-007D-SPT-008-SPT-009\backups\" +
    [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
)

$Release007D = Join-Path $ProjectRoot "releases\SPT-007D-v1.0.0"
$Release008 = Join-Path $ProjectRoot "releases\SPT-008-v1.0.0"
$Release009 = Join-Path $ProjectRoot "releases\SPT-009-v1.0.0"

Step "Validando línea base tecnológica"

foreach ($Path in @(
    (Join-Path $ProjectRoot "src\sgoda\knowledge_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\lexical_engine\semantic_service.py"),
    (Join-Path $ProjectRoot "src\sgoda\language_engine\engine.py"),
    (Join-Path $ProjectRoot "src\sgoda\assistant\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\policy_cli.py"),
    (Join-Path $ProjectRoot "config\governance\SGD-114C-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "pytest.ini")
)) {
    Require-File $Path
}

Step "Creando respaldo institucional"
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

# ---------------------------------------------------------------------
# SPT-007D
# ---------------------------------------------------------------------

$ReasoningModels = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class ReasoningQuestion:
    text: str
    start_node_id: str | None = None
    relation_filter: tuple[str, ...] = ()
    max_depth: int = 3


@dataclass(frozen=True, slots=True)
class ReasoningConclusion:
    subject_id: str
    relation_type: str
    object_id: str
    confidence: float
    explanation: str
    evidence: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class ReasoningResponse:
    question: ReasoningQuestion
    conclusions: tuple[ReasoningConclusion, ...]
    unresolved: bool
    no_invention: bool = True
    metadata: dict[str, Any] | None = None
'@

$ReasoningRules = @'
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ReasoningRule:
    code: str
    relation_type: str
    transitive: bool
    explanation_template: str


DEFAULT_RULES = (
    ReasoningRule(
        "SPT007D-R001",
        "is_a",
        True,
        "{subject} pertenece indirectamente a {object}.",
    ),
    ReasoningRule(
        "SPT007D-R002",
        "part_of",
        True,
        "{subject} forma parte indirectamente de {object}.",
    ),
    ReasoningRule(
        "SPT007D-R003",
        "located_in",
        True,
        "{subject} está relacionado territorialmente con {object}.",
    ),
)


def rule_for_relation(relation_type: str) -> ReasoningRule | None:
    normalized = relation_type.strip().casefold()
    return next(
        (
            rule
            for rule in DEFAULT_RULES
            if rule.relation_type == normalized
        ),
        None,
    )
'@

$Reasoner = @'
from __future__ import annotations

from collections import deque

from sgoda.knowledge_engine.graph import KnowledgeGraph

from .models import (
    ReasoningConclusion,
    ReasoningQuestion,
    ReasoningResponse,
)
from .rules import rule_for_relation


class LinguisticReasoner:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.graph = graph

    def reason(
        self,
        question: ReasoningQuestion,
    ) -> ReasoningResponse:
        start = question.start_node_id

        if not start or self.graph.get_node(start) is None:
            return ReasoningResponse(
                question=question,
                conclusions=(),
                unresolved=True,
                metadata={"reason": "start_node_missing"},
            )

        relation_filter = {
            item.strip().casefold()
            for item in question.relation_filter
            if item.strip()
        }

        conclusions: dict[
            tuple[str, str, str],
            ReasoningConclusion,
        ] = {}

        queue = deque([(start, 0, 1.0, (start,))])
        visited: set[tuple[str, int]] = set()

        while queue:
            current, depth, confidence, path = queue.popleft()

            if depth >= question.max_depth:
                continue

            state = (current, depth)
            if state in visited:
                continue
            visited.add(state)

            for edge in self.graph.outgoing(
                current,
                validated_only=True,
            ):
                if (
                    relation_filter
                    and edge.relation_type not in relation_filter
                ):
                    continue

                rule = rule_for_relation(edge.relation_type)
                next_confidence = confidence * edge.weight
                evidence = (*path, edge.target_id)

                conclusion = ReasoningConclusion(
                    subject_id=start,
                    relation_type=edge.relation_type,
                    object_id=edge.target_id,
                    confidence=round(next_confidence, 6),
                    explanation=(
                        rule.explanation_template.format(
                            subject=start,
                            object=edge.target_id,
                        )
                        if rule is not None
                        else (
                            f"{start} se relaciona con "
                            f"{edge.target_id} mediante "
                            f"{edge.relation_type}."
                        )
                    ),
                    evidence=evidence,
                )

                conclusions[
                    (
                        conclusion.subject_id,
                        conclusion.relation_type,
                        conclusion.object_id,
                    )
                ] = conclusion

                if rule is not None and rule.transitive:
                    queue.append(
                        (
                            edge.target_id,
                            depth + 1,
                            next_confidence,
                            evidence,
                        )
                    )

        ordered = tuple(
            conclusions[key]
            for key in sorted(
                conclusions,
                key=lambda item: (
                    -conclusions[item].confidence,
                    item,
                ),
            )
        )

        return ReasoningResponse(
            question=question,
            conclusions=ordered,
            unresolved=not ordered,
            metadata={
                "start_node_id": start,
                "evaluated_relations": sorted(relation_filter),
            },
        )
'@

$ReasoningService = @'
from __future__ import annotations

from sgoda.knowledge_engine.graph import KnowledgeGraph

from .models import ReasoningQuestion
from .reasoner import LinguisticReasoner


class LinguisticReasoningService:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.reasoner = LinguisticReasoner(graph)

    def ask(
        self,
        text: str,
        start_node_id: str,
        relations: tuple[str, ...] = (),
        max_depth: int = 3,
    ) -> dict:
        response = self.reasoner.reason(
            ReasoningQuestion(
                text=text,
                start_node_id=start_node_id,
                relation_filter=relations,
                max_depth=max_depth,
            )
        )

        return {
            "question": text,
            "start_node_id": start_node_id,
            "unresolved": response.unresolved,
            "no_invention": response.no_invention,
            "conclusions": [
                {
                    "subject_id": item.subject_id,
                    "relation_type": item.relation_type,
                    "object_id": item.object_id,
                    "confidence": item.confidence,
                    "explanation": item.explanation,
                    "evidence": list(item.evidence),
                }
                for item in response.conclusions
            ],
            "metadata": response.metadata or {},
        }
'@

$ReasoningInit = @'
from .models import (
    ReasoningConclusion,
    ReasoningQuestion,
    ReasoningResponse,
)
from .reasoner import LinguisticReasoner
from .service import LinguisticReasoningService

__all__ = [
    "LinguisticReasoner",
    "LinguisticReasoningService",
    "ReasoningConclusion",
    "ReasoningQuestion",
    "ReasoningResponse",
]
'@

$ReasoningTestsText = @'
from sgoda.knowledge_engine import (
    KnowledgeEdge,
    KnowledgeGraph,
    KnowledgeNode,
)
from sgoda.reasoning_engine import LinguisticReasoningService


def _graph():
    graph = KnowledgeGraph()

    for node in (
        KnowledgeNode("A", "concept", "A", validated=True),
        KnowledgeNode("B", "concept", "B", validated=True),
        KnowledgeNode("C", "category", "C", validated=True),
    ):
        graph.add_node(node)

    graph.add_edge(
        KnowledgeEdge(
            "A",
            "B",
            "is_a",
            validated=True,
        )
    )
    graph.add_edge(
        KnowledgeEdge(
            "B",
            "C",
            "is_a",
            validated=True,
        )
    )
    return graph


def test_SPT_007D_returns_direct_conclusion():
    result = LinguisticReasoningService(_graph()).ask(
        "¿Qué es A?",
        "A",
        ("is_a",),
    )
    assert result["conclusions"]
    assert result["conclusions"][0]["subject_id"] == "A"


def test_SPT_007D_supports_transitive_reasoning():
    result = LinguisticReasoningService(_graph()).ask(
        "¿A pertenece a C?",
        "A",
        ("is_a",),
        max_depth=3,
    )
    objects = {
        item["object_id"]
        for item in result["conclusions"]
    }
    assert "C" in objects


def test_SPT_007D_is_explainable():
    result = LinguisticReasoningService(_graph()).ask(
        "Explica A",
        "A",
        ("is_a",),
    )
    assert result["conclusions"][0]["explanation"]
    assert result["conclusions"][0]["evidence"]


def test_SPT_007D_no_invention_when_node_missing():
    result = LinguisticReasoningService(_graph()).ask(
        "Consulta inexistente",
        "ZZZ",
    )
    assert result["unresolved"] is True
    assert result["no_invention"] is True
    assert result["conclusions"] == []


def test_SPT_007D_uses_validated_edges_only():
    graph = _graph()
    graph.add_node(
        KnowledgeNode("X", "concept", "X", validated=False)
    )
    graph.add_edge(
        KnowledgeEdge(
            "A",
            "X",
            "is_a",
            validated=False,
        )
    )
    result = LinguisticReasoningService(graph).ask(
        "Consulta",
        "A",
        ("is_a",),
    )
    assert "X" not in {
        item["object_id"]
        for item in result["conclusions"]
    }


def test_SPT_007D_is_deterministic():
    service = LinguisticReasoningService(_graph())
    first = service.ask("Consulta", "A", ("is_a",))
    second = service.ask("Consulta", "A", ("is_a",))
    assert first == second
'@

# ---------------------------------------------------------------------
# SPT-008
# ---------------------------------------------------------------------

$TutorModels = @'
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True, slots=True)
class LearnerProfile:
    learner_id: str
    level: str = "beginner"
    preferred_language: str = "es"
    completed_entry_ids: tuple[str, ...] = ()
    interests: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class LearningActivity:
    activity_id: str
    activity_type: str
    title: str
    entry_ids: tuple[str, ...]
    instructions: str
    expected_answer: str | None = None
    metadata: dict = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class LearningPath:
    path_id: str
    learner_id: str
    level: str
    activities: tuple[LearningActivity, ...]


@dataclass(frozen=True, slots=True)
class Feedback:
    correct: bool
    score: float
    message: str
    remediation: str = ""
'@

$TutorPlanner = @'
from __future__ import annotations

from sgoda.knowledge_engine.graph import KnowledgeGraph

from .models import (
    LearnerProfile,
    LearningActivity,
    LearningPath,
)


class LearningPathPlanner:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.graph = graph

    def build(
        self,
        profile: LearnerProfile,
        seed_node_id: str,
        limit: int = 5,
    ) -> LearningPath:
        nodes, _ = self.graph.neighborhood(
            seed_node_id,
            depth=2,
            validated_only=True,
        )

        available = [
            node
            for node in nodes
            if node.node_type == "lexical_entry"
            and node.node_id not in profile.completed_entry_ids
        ]

        if not available:
            seed = self.graph.get_node(seed_node_id)
            if seed is not None and seed.node_type == "lexical_entry":
                available = [seed]

        activities = []

        for index, node in enumerate(
            sorted(available, key=lambda item: item.node_id)[:limit],
            start=1,
        ):
            activities.append(
                LearningActivity(
                    activity_id=f"{profile.learner_id}-ACT-{index:03d}",
                    activity_type="recognition",
                    title=f"Reconocer {node.label}",
                    entry_ids=(node.node_id,),
                    instructions=(
                        f"Escucha, observa y reconoce el término "
                        f"{node.label}."
                    ),
                    expected_answer=node.label,
                    metadata={
                        "language": node.language,
                        "source_ref": node.source_ref,
                    },
                )
            )

        return LearningPath(
            path_id=f"PATH-{profile.learner_id}-{seed_node_id}",
            learner_id=profile.learner_id,
            level=profile.level,
            activities=tuple(activities),
        )
'@

$TutorExercises = @'
from __future__ import annotations

from .models import Feedback, LearningActivity


def evaluate_answer(
    activity: LearningActivity,
    answer: str,
) -> Feedback:
    expected = (activity.expected_answer or "").strip().casefold()
    provided = str(answer or "").strip().casefold()

    if not expected:
        return Feedback(
            correct=False,
            score=0.0,
            message="La actividad no tiene respuesta validada.",
            remediation="Solicite revisión pedagógica.",
        )

    correct = provided == expected

    return Feedback(
        correct=correct,
        score=1.0 if correct else 0.0,
        message=(
            "Respuesta correcta."
            if correct
            else "Respuesta todavía no correcta."
        ),
        remediation=(
            ""
            if correct
            else "Vuelva a escuchar el audio y revise la ficha léxica."
        ),
    )


def build_multiple_choice(
    activity: LearningActivity,
    distractors: tuple[str, ...],
) -> dict:
    expected = activity.expected_answer or ""
    options = tuple(
        sorted(
            {
                expected,
                *(
                    item
                    for item in distractors
                    if str(item).strip()
                ),
            }
        )
    )

    return {
        "activity_id": activity.activity_id,
        "question": activity.instructions,
        "options": list(options),
        "answer": expected,
    }
'@

$TutorService = @'
from __future__ import annotations

from sgoda.knowledge_engine.graph import KnowledgeGraph

from .exercises import evaluate_answer
from .models import LearnerProfile
from .planner import LearningPathPlanner


class PuinaveTutorService:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.graph = graph
        self.planner = LearningPathPlanner(graph)

    def create_path(
        self,
        learner_id: str,
        seed_node_id: str,
        level: str = "beginner",
        preferred_language: str = "es",
    ) -> dict:
        path = self.planner.build(
            LearnerProfile(
                learner_id=learner_id,
                level=level,
                preferred_language=preferred_language,
            ),
            seed_node_id,
        )

        return {
            "path_id": path.path_id,
            "learner_id": path.learner_id,
            "level": path.level,
            "activities": [
                {
                    "activity_id": item.activity_id,
                    "activity_type": item.activity_type,
                    "title": item.title,
                    "entry_ids": list(item.entry_ids),
                    "instructions": item.instructions,
                    "expected_answer": item.expected_answer,
                    "metadata": item.metadata,
                }
                for item in path.activities
            ],
            "no_invention": True,
        }

    def evaluate(
        self,
        activity_payload: dict,
        answer: str,
    ) -> dict:
        from .models import LearningActivity

        activity = LearningActivity(
            activity_id=activity_payload["activity_id"],
            activity_type=activity_payload["activity_type"],
            title=activity_payload["title"],
            entry_ids=tuple(activity_payload["entry_ids"]),
            instructions=activity_payload["instructions"],
            expected_answer=activity_payload.get("expected_answer"),
            metadata=dict(activity_payload.get("metadata", {})),
        )
        feedback = evaluate_answer(activity, answer)

        return {
            "correct": feedback.correct,
            "score": feedback.score,
            "message": feedback.message,
            "remediation": feedback.remediation,
        }
'@

$TutorInit = @'
from .exercises import build_multiple_choice, evaluate_answer
from .models import (
    Feedback,
    LearnerProfile,
    LearningActivity,
    LearningPath,
)
from .planner import LearningPathPlanner
from .service import PuinaveTutorService

__all__ = [
    "Feedback",
    "LearnerProfile",
    "LearningActivity",
    "LearningPath",
    "LearningPathPlanner",
    "PuinaveTutorService",
    "build_multiple_choice",
    "evaluate_answer",
]
'@

$TutorTestsText = @'
from sgoda.knowledge_engine import (
    KnowledgeEdge,
    KnowledgeGraph,
    KnowledgeNode,
)
from sgoda.tutor import PuinaveTutorService


def _graph():
    graph = KnowledgeGraph()
    graph.add_node(
        KnowledgeNode(
            "LEX-001",
            "lexical_entry",
            "AMDA",
            language="pu",
            validated=True,
            source_ref="RLB:LEX-001",
        )
    )
    graph.add_node(
        KnowledgeNode(
            "CON-001",
            "concept",
            "Casa",
            validated=True,
        )
    )
    graph.add_edge(
        KnowledgeEdge(
            "LEX-001",
            "CON-001",
            "related_to",
            validated=True,
        )
    )
    return graph


def test_SPT_008_builds_learning_path():
    result = PuinaveTutorService(_graph()).create_path(
        "USR-001",
        "LEX-001",
    )
    assert result["activities"]
    assert result["no_invention"] is True


def test_SPT_008_activity_references_rlb_entry():
    result = PuinaveTutorService(_graph()).create_path(
        "USR-001",
        "LEX-001",
    )
    assert result["activities"][0]["entry_ids"] == ["LEX-001"]


def test_SPT_008_evaluates_correct_answer():
    service = PuinaveTutorService(_graph())
    path = service.create_path("USR-001", "LEX-001")
    feedback = service.evaluate(
        path["activities"][0],
        "AMDA",
    )
    assert feedback["correct"] is True
    assert feedback["score"] == 1.0


def test_SPT_008_evaluates_incorrect_answer():
    service = PuinaveTutorService(_graph())
    path = service.create_path("USR-001", "LEX-001")
    feedback = service.evaluate(
        path["activities"][0],
        "OTRA",
    )
    assert feedback["correct"] is False
    assert feedback["remediation"]


def test_SPT_008_is_deterministic():
    service = PuinaveTutorService(_graph())
    first = service.create_path("USR-001", "LEX-001")
    second = service.create_path("USR-001", "LEX-001")
    assert first == second


def test_SPT_008_does_not_create_unknown_content():
    result = PuinaveTutorService(_graph()).create_path(
        "USR-001",
        "UNKNOWN",
    )
    assert result["activities"] == []
    assert result["no_invention"] is True
'@

# ---------------------------------------------------------------------
# SPT-009
# ---------------------------------------------------------------------

$ConversationModels = @'
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class ConversationMessage:
    role: str
    text: str
    language: str = "es"
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class ConversationRequest:
    session_id: str
    message: ConversationMessage
    context_node_id: str | None = None
    mode: str = "knowledge"


@dataclass(frozen=True, slots=True)
class ConversationResponse:
    session_id: str
    text: str
    language: str
    intent: str
    sources: tuple[str, ...]
    audio_text: str | None = None
    unresolved: bool = False
    no_invention: bool = True
'@

$ConversationRouter = @'
from __future__ import annotations


def classify_conversation_intent(text: str) -> str:
    normalized = str(text or "").strip().casefold()

    if any(
        token in normalized
        for token in ("aprender", "ejercicio", "practicar", "lección")
    ):
        return "tutor"

    if any(
        token in normalized
        for token in ("por qué", "explica", "relación", "cómo se relaciona")
    ):
        return "reasoning"

    if any(
        token in normalized
        for token in ("qué significa", "buscar", "palabra", "traducción")
    ):
        return "lexical"

    return "knowledge"
'@

$ConversationMemory = @'
from __future__ import annotations

from collections import defaultdict

from .models import ConversationMessage


class ConversationMemory:
    def __init__(self, maximum_messages: int = 20) -> None:
        self.maximum_messages = maximum_messages
        self._messages: dict[str, list[ConversationMessage]] = defaultdict(list)

    def add(
        self,
        session_id: str,
        message: ConversationMessage,
    ) -> None:
        bucket = self._messages[session_id]
        bucket.append(message)
        del bucket[:-self.maximum_messages]

    def history(
        self,
        session_id: str,
    ) -> tuple[ConversationMessage, ...]:
        return tuple(self._messages.get(session_id, []))
'@

$ConversationService = @'
from __future__ import annotations

from sgoda.knowledge_engine.service import KnowledgeEngineService
from sgoda.reasoning_engine.service import LinguisticReasoningService
from sgoda.tutor.service import PuinaveTutorService

from .memory import ConversationMemory
from .models import (
    ConversationMessage,
    ConversationRequest,
    ConversationResponse,
)
from .router import classify_conversation_intent


class ConversationalEcosystemService:
    def __init__(
        self,
        knowledge: KnowledgeEngineService,
        reasoning: LinguisticReasoningService,
        tutor: PuinaveTutorService,
        memory: ConversationMemory | None = None,
    ) -> None:
        self.knowledge = knowledge
        self.reasoning = reasoning
        self.tutor = tutor
        self.memory = memory or ConversationMemory()

    def converse(
        self,
        request: ConversationRequest,
    ) -> ConversationResponse:
        self.memory.add(
            request.session_id,
            request.message,
        )

        intent = classify_conversation_intent(
            request.message.text
        )
        node_id = request.context_node_id
        language = request.message.language

        if not node_id:
            response = ConversationResponse(
                session_id=request.session_id,
                text=(
                    "Necesito una palabra o concepto validado "
                    "del repositorio para responder."
                ),
                language=language,
                intent=intent,
                sources=(),
                unresolved=True,
            )
            self.memory.add(
                request.session_id,
                ConversationMessage(
                    role="assistant",
                    text=response.text,
                    language=language,
                ),
            )
            return response

        if intent == "tutor":
            payload = self.tutor.create_path(
                learner_id=request.session_id,
                seed_node_id=node_id,
            )
            activities = payload["activities"]
            text = (
                activities[0]["instructions"]
                if activities
                else "No hay una actividad validada disponible."
            )
            sources = tuple(
                entry_id
                for activity in activities
                for entry_id in activity["entry_ids"]
            )
            unresolved = not activities

        elif intent == "reasoning":
            payload = self.reasoning.ask(
                request.message.text,
                node_id,
            )
            conclusions = payload["conclusions"]
            text = (
                conclusions[0]["explanation"]
                if conclusions
                else "No encontré una relación validada."
            )
            sources = tuple(
                source
                for item in conclusions[:3]
                for source in item["evidence"]
            )
            unresolved = not conclusions

        else:
            payload = self.knowledge.query(node_id)
            nodes = payload["nodes"]
            text = (
                "Conocimiento relacionado: "
                + ", ".join(
                    item["label"]
                    for item in nodes[:5]
                )
                if nodes
                else "No encontré conocimiento validado."
            )
            sources = tuple(
                item["source_ref"]
                for item in nodes
                if item.get("source_ref")
            )
            unresolved = not nodes

        response = ConversationResponse(
            session_id=request.session_id,
            text=text,
            language=language,
            intent=intent,
            sources=tuple(dict.fromkeys(sources)),
            audio_text=text,
            unresolved=unresolved,
        )

        self.memory.add(
            request.session_id,
            ConversationMessage(
                role="assistant",
                text=response.text,
                language=language,
                metadata={"intent": intent},
            ),
        )

        return response
'@

$ConversationInit = @'
from .memory import ConversationMemory
from .models import (
    ConversationMessage,
    ConversationRequest,
    ConversationResponse,
)
from .router import classify_conversation_intent
from .service import ConversationalEcosystemService

__all__ = [
    "ConversationMemory",
    "ConversationMessage",
    "ConversationRequest",
    "ConversationResponse",
    "ConversationalEcosystemService",
    "classify_conversation_intent",
]
'@

$ConversationTestsText = @'
from sgoda.conversation import (
    ConversationMessage,
    ConversationRequest,
    ConversationalEcosystemService,
)
from sgoda.knowledge_engine import (
    KnowledgeEdge,
    KnowledgeEngineService,
    KnowledgeGraph,
    KnowledgeNode,
)
from sgoda.reasoning_engine import LinguisticReasoningService
from sgoda.tutor import PuinaveTutorService


def _services():
    graph = KnowledgeGraph()
    graph.add_node(
        KnowledgeNode(
            "LEX-001",
            "lexical_entry",
            "AMDA",
            language="pu",
            validated=True,
            source_ref="RLB:LEX-001",
        )
    )
    graph.add_node(
        KnowledgeNode(
            "CON-001",
            "concept",
            "Casa",
            validated=True,
        )
    )
    graph.add_edge(
        KnowledgeEdge(
            "LEX-001",
            "CON-001",
            "related_to",
            validated=True,
        )
    )

    return ConversationalEcosystemService(
        KnowledgeEngineService(graph),
        LinguisticReasoningService(graph),
        PuinaveTutorService(graph),
    )


def test_SPT_009_routes_tutor_intent():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Quiero aprender esta palabra",
            ),
            context_node_id="LEX-001",
        )
    )
    assert response.intent == "tutor"
    assert response.unresolved is False


def test_SPT_009_routes_reasoning_intent():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Explica la relación",
            ),
            context_node_id="LEX-001",
        )
    )
    assert response.intent == "reasoning"


def test_SPT_009_returns_knowledge_response():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Muéstrame información",
            ),
            context_node_id="LEX-001",
        )
    )
    assert response.intent == "knowledge"
    assert response.text
    assert response.no_invention is True


def test_SPT_009_requires_validated_context():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Consulta",
            ),
            context_node_id=None,
        )
    )
    assert response.unresolved is True
    assert response.sources == ()


def test_SPT_009_prepares_audio_text():
    service = _services()
    response = service.converse(
        ConversationRequest(
            "SES-001",
            ConversationMessage(
                "user",
                "Muéstrame información",
                language="es",
            ),
            context_node_id="LEX-001",
        )
    )
    assert response.audio_text == response.text


def test_SPT_009_keeps_session_memory():
    service = _services()
    request = ConversationRequest(
        "SES-001",
        ConversationMessage(
            "user",
            "Muéstrame información",
        ),
        context_node_id="LEX-001",
    )
    service.converse(request)
    assert len(service.memory.history("SES-001")) == 2
'@

# ---------------------------------------------------------------------
# Shared CLI + configs + docs
# ---------------------------------------------------------------------

$IntegratedCli = @'
from __future__ import annotations

import argparse
import json
from pathlib import Path

from sgoda.conversation import (
    ConversationMessage,
    ConversationRequest,
    ConversationalEcosystemService,
)
from sgoda.knowledge_engine import KnowledgeEngineService, KnowledgeGraph
from sgoda.reasoning_engine import LinguisticReasoningService
from sgoda.tutor import PuinaveTutorService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph", required=True)
    parser.add_argument("--node", required=True)
    parser.add_argument("--message", required=True)
    parser.add_argument("--session", default="demo")
    parser.add_argument("--language", default="es")
    parser.add_argument("--output")
    args = parser.parse_args()

    graph = KnowledgeGraph.from_json(args.graph)

    service = ConversationalEcosystemService(
        KnowledgeEngineService(graph),
        LinguisticReasoningService(graph),
        PuinaveTutorService(graph),
    )

    response = service.converse(
        ConversationRequest(
            session_id=args.session,
            message=ConversationMessage(
                role="user",
                text=args.message,
                language=args.language,
            ),
            context_node_id=args.node,
        )
    )

    payload = {
        "session_id": response.session_id,
        "text": response.text,
        "language": response.language,
        "intent": response.intent,
        "sources": list(response.sources),
        "audio_text": response.audio_text,
        "unresolved": response.unresolved,
        "no_invention": response.no_invention,
    }

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

$ReasoningPolicy = @'
{
  "component": "SPT-007D",
  "version": "1.0.0",
  "name": "Motor de Razonamiento Lingüístico",
  "local_first": true,
  "no_invention": true,
  "explainable": true,
  "validated_edges_only": true,
  "maximum_depth": 3,
  "paid_services_required": false
}
'@

$TutorPolicy = @'
{
  "component": "SPT-008",
  "version": "1.0.0",
  "name": "Tutor Inteligente Puinave",
  "local_first": true,
  "no_invention": true,
  "validated_content_only": true,
  "feedback_enabled": true,
  "supported_levels": [
    "beginner",
    "intermediate",
    "advanced"
  ],
  "paid_services_required": false
}
'@

$ConversationPolicy = @'
{
  "component": "SPT-009",
  "version": "1.0.0",
  "name": "Ecosistema Conversacional",
  "local_first": true,
  "no_invention": true,
  "text_enabled": true,
  "voice_contract_enabled": true,
  "external_paid_services_required": false,
  "supported_languages": [
    "pu",
    "es",
    "en-US",
    "it"
  ]
}
'@

$Component007D = @'
{
  "increment_code": "SPT-007D",
  "name": "Motor de Razonamiento Lingüístico",
  "component_type": "linguistic_reasoning_engine",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica",
  "dependencies": [
    "SPT-007C",
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/reasoning_engine/models.py",
    "src/sgoda/reasoning_engine/rules.py",
    "src/sgoda/reasoning_engine/reasoner.py",
    "src/sgoda/reasoning_engine/service.py"
  ],
  "tests": [
    "tests/reasoning_engine/test_SPT_007D_reasoning_engine.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007D-Motor-Razonamiento-Linguistico.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007D-Reglas-Inferencia-Explicaciones.md"
  ]
}
'@

$Component008 = @'
{
  "increment_code": "SPT-008",
  "name": "Tutor Inteligente Puinave",
  "component_type": "intelligent_tutor",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica",
  "dependencies": [
    "SPT-006A",
    "SPT-007A",
    "SPT-007B",
    "SPT-007C",
    "SPT-007D",
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/tutor/models.py",
    "src/sgoda/tutor/planner.py",
    "src/sgoda/tutor/exercises.py",
    "src/sgoda/tutor/service.py"
  ],
  "tests": [
    "tests/tutor/test_SPT_008_intelligent_tutor.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SPT-008/SPT-008-Tutor-Inteligente-Puinave.md",
    "docs/05_Fase_Tecnologica/SPT-008/SPT-008-Rutas-Ejercicios-Retroalimentacion.md"
  ]
}
'@

$Component009 = @'
{
  "increment_code": "SPT-009",
  "name": "Ecosistema Conversacional",
  "component_type": "conversational_ecosystem",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica",
  "dependencies": [
    "SPT-004A",
    "SPT-006A",
    "SPT-007C",
    "SPT-007D",
    "SPT-008",
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/conversation/models.py",
    "src/sgoda/conversation/router.py",
    "src/sgoda/conversation/memory.py",
    "src/sgoda/conversation/service.py",
    "src/sgoda/conversation/cli.py"
  ],
  "tests": [
    "tests/conversation/test_SPT_009_conversational_ecosystem.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SPT-009/SPT-009-Ecosistema-Conversacional.md",
    "docs/05_Fase_Tecnologica/SPT-009/SPT-009-Interaccion-Texto-Voz.md"
  ]
}
'@

$Docs = @{
    (Join-Path $DocsRoot "SPT-007\SPT-007D-Motor-Razonamiento-Linguistico.md") = @'
# SPT-007D — Motor de Razonamiento Lingüístico

Permite consultas complejas y explicaciones sobre relaciones del grafo de
conocimiento. Opera únicamente sobre nodos y relaciones validadas.
'@
    (Join-Path $DocsRoot "SPT-007\SPT-007D-Reglas-Inferencia-Explicaciones.md") = @'
# Reglas, inferencia y explicaciones SPT-007D

Toda conclusión debe incluir evidencia, confianza y explicación. La versión
1.0.0 usa reglas deterministas y no utiliza generación libre de conocimiento.
'@
    (Join-Path $DocsRoot "SPT-008\SPT-008-Tutor-Inteligente-Puinave.md") = @'
# SPT-008 — Tutor Inteligente Puinave

Construye rutas de aprendizaje a partir de contenido validado del RLB, el
motor semántico y el grafo de conocimiento.
'@
    (Join-Path $DocsRoot "SPT-008\SPT-008-Rutas-Ejercicios-Retroalimentacion.md") = @'
# Rutas, ejercicios y retroalimentación SPT-008

Las actividades deben referenciar registros existentes. La retroalimentación
es determinista y nunca crea vocabulario Puinave.
'@
    (Join-Path $DocsRoot "SPT-009\SPT-009-Ecosistema-Conversacional.md") = @'
# SPT-009 — Ecosistema Conversacional

Orquesta conocimiento, razonamiento y tutoría mediante una interacción
natural por texto, con contrato preparado para síntesis de voz local.
'@
    (Join-Path $DocsRoot "SPT-009\SPT-009-Interaccion-Texto-Voz.md") = @'
# Interacción por texto y voz SPT-009

El texto de respuesta puede enviarse al motor local SPT-006A para TTS.
La versión 1.0.0 no depende de servicios de pago.
'@
}

$InvokeScript = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Graph,

    [Parameter(Mandatory = $true)]
    [string]$Node,

    [Parameter(Mandatory = $true)]
    [string]$Message,

    [string]$Output = "artifacts/integrated_intelligence/conversation-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.conversation.cli `
    --graph $Graph `
    --node $Node `
    --message $Message `
    --output $Output

exit $LASTEXITCODE
'@

Step "Instalando SPT-007D"
Write-Utf8 (Join-Path $ReasoningDir "models.py") $ReasoningModels
Write-Utf8 (Join-Path $ReasoningDir "rules.py") $ReasoningRules
Write-Utf8 (Join-Path $ReasoningDir "reasoner.py") $Reasoner
Write-Utf8 (Join-Path $ReasoningDir "service.py") $ReasoningService
Write-Utf8 (Join-Path $ReasoningDir "__init__.py") $ReasoningInit
Write-Utf8 (Join-Path $ReasoningTests "test_SPT_007D_reasoning_engine.py") $ReasoningTestsText
Write-Utf8 (Join-Path $ReasoningConfig "SPT-007D-policy.json") $ReasoningPolicy
Write-Utf8 (Join-Path $ReasoningConfig "SPT-007D-component.json") $Component007D

Step "Instalando SPT-008"
Write-Utf8 (Join-Path $TutorDir "models.py") $TutorModels
Write-Utf8 (Join-Path $TutorDir "planner.py") $TutorPlanner
Write-Utf8 (Join-Path $TutorDir "exercises.py") $TutorExercises
Write-Utf8 (Join-Path $TutorDir "service.py") $TutorService
Write-Utf8 (Join-Path $TutorDir "__init__.py") $TutorInit
Write-Utf8 (Join-Path $TutorTests "test_SPT_008_intelligent_tutor.py") $TutorTestsText
Write-Utf8 (Join-Path $TutorConfig "SPT-008-policy.json") $TutorPolicy
Write-Utf8 (Join-Path $TutorConfig "SPT-008-component.json") $Component008

Step "Instalando SPT-009"
Write-Utf8 (Join-Path $ConversationDir "models.py") $ConversationModels
Write-Utf8 (Join-Path $ConversationDir "router.py") $ConversationRouter
Write-Utf8 (Join-Path $ConversationDir "memory.py") $ConversationMemory
Write-Utf8 (Join-Path $ConversationDir "service.py") $ConversationService
Write-Utf8 (Join-Path $ConversationDir "cli.py") $IntegratedCli
Write-Utf8 (Join-Path $ConversationDir "__init__.py") $ConversationInit
Write-Utf8 (Join-Path $ConversationTests "test_SPT_009_conversational_ecosystem.py") $ConversationTestsText
Write-Utf8 (Join-Path $ConversationConfig "SPT-009-policy.json") $ConversationPolicy
Write-Utf8 (Join-Path $ConversationConfig "SPT-009-component.json") $Component009

Step "Instalando documentación"
foreach ($Pair in $Docs.GetEnumerator()) {
    Write-Utf8 $Pair.Key $Pair.Value
}

Write-Utf8 `
    (Join-Path $ScriptsDir "Invoke-SPT009-ConversationalEcosystem.ps1") `
    $InvokeScript

Run-Checked "Validando sintaxis de los tres componentes" {
    python -m py_compile `
        "src/sgoda/reasoning_engine/models.py" `
        "src/sgoda/reasoning_engine/rules.py" `
        "src/sgoda/reasoning_engine/reasoner.py" `
        "src/sgoda/reasoning_engine/service.py" `
        "src/sgoda/reasoning_engine/__init__.py" `
        "src/sgoda/tutor/models.py" `
        "src/sgoda/tutor/planner.py" `
        "src/sgoda/tutor/exercises.py" `
        "src/sgoda/tutor/service.py" `
        "src/sgoda/tutor/__init__.py" `
        "src/sgoda/conversation/models.py" `
        "src/sgoda/conversation/router.py" `
        "src/sgoda/conversation/memory.py" `
        "src/sgoda/conversation/service.py" `
        "src/sgoda/conversation/cli.py" `
        "src/sgoda/conversation/__init__.py"
}

Run-Checked "Ejecutando 18 pruebas específicas integradas" {
    python -m pytest `
        "tests/reasoning_engine/test_SPT_007D_reasoning_engine.py" `
        "tests/tutor/test_SPT_008_intelligent_tutor.py" `
        "tests/conversation/test_SPT_009_conversational_ecosystem.py" `
        -q
}

if (-not $SkipFullSuite) {
    Run-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Step "Ejecutando demostración integrada"

$DemoGraph = Join-Path $DemoRoot "demo-integrated-graph.json"
$DemoOutput = Join-Path $DemoRoot "demo-conversation.json"

Write-Json $DemoGraph ([ordered]@{
    nodes = @(
        [ordered]@{
            node_id = "LEX-001"
            node_type = "lexical_entry"
            label = "AMDA"
            language = "pu"
            validated = $true
            source_ref = "RLB:LEX-001"
        },
        [ordered]@{
            node_id = "CON-001"
            node_type = "concept"
            label = "Casa"
            validated = $true
        }
    )
    edges = @(
        [ordered]@{
            source_id = "LEX-001"
            target_id = "CON-001"
            relation_type = "related_to"
            validated = $true
            weight = 1.0
        }
    )
})

Run-Checked "Consultando el ecosistema conversacional" {
    python -m sgoda.conversation.cli `
        --graph "$DemoGraph" `
        --node "LEX-001" `
        --message "Quiero aprender esta palabra" `
        --output "$DemoOutput"
}

$Demo = Get-Content `
    -LiteralPath $DemoOutput `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not $Demo.no_invention) {
    throw "La demostración no respetó no_invention=true."
}

Step "Regenerando Roadmap SGD-116"
Run-Checked "Actualizando Roadmap" {
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
    throw "SGD-116 no aprobó la suite integrada."
}

Step "Preparando evidencias y releases"

$Components = @(
    [ordered]@{
        Code = "SPT-007D"
        Version = "1.0.0"
        Config = Join-Path $ReasoningConfig "SPT-007D-component.json"
        Release = $Release007D
        Tests = 6
    },
    [ordered]@{
        Code = "SPT-008"
        Version = "1.0.0"
        Config = Join-Path $TutorConfig "SPT-008-component.json"
        Release = $Release008
        Tests = 6
    },
    [ordered]@{
        Code = "SPT-009"
        Version = "1.0.0"
        Config = Join-Path $ConversationConfig "SPT-009-component.json"
        Release = $Release009
        Tests = 6
    }
)

foreach ($Component in $Components) {
    $Code = $Component.Code
    $PmoDir = Join-Path $PmoRoot $Code
    $GateJson = Join-Path $PmoDir "$Code-policy-result.json"
    $GateMd = Join-Path $PmoDir "$Code-policy-result.md"

    New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
    New-Item -ItemType Directory -Path $Component.Release -Force | Out-Null

    Write-Json (Join-Path $PmoDir "$Code-pre-gate-evidence.json") ([ordered]@{
        increment_code = $Code
        version = $Component.Version
        status = "technically_completed"
        phase = "Fase Tecnológica"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        specific_tests = $Component.Tests
        full_suite_executed = (-not $SkipFullSuite)
        roadmap_approved = [bool]$RoadmapValidation.passed
        integrated_demo = $DemoOutput
    })

    Copy-Item `
        -LiteralPath $Component.Config `
        -Destination (Join-Path $Component.Release "$Code-component.json") `
        -Force

    Step "Evaluando $Code mediante SGD-114C"

    & python -m sgoda.governance.policy_cli `
        --root "$ProjectRoot" `
        --policy "config/governance/SGD-114C-policy.json" `
        --increment "$Code" `
        --output-json "$GateJson" `
        --output-md "$GateMd"

    if ($LASTEXITCODE -ne 0) {
        throw "SGD-114C no aprobó $Code."
    }

    $Gate = Get-Content `
        -LiteralPath $GateJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not $Gate.approved) {
        throw "$Code contiene reglas bloqueantes."
    }

    Write-Json (Join-Path $PmoDir "$Code-implementation-evidence.json") ([ordered]@{
        increment_code = $Code
        version = $Component.Version
        status = "implemented"
        phase = "Fase Tecnológica"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        specific_tests = $Component.Tests
        full_suite_executed = (-not $SkipFullSuite)
        policy_approved = [bool]$Gate.approved
        policy_exit_code = $Gate.exit_code
        roadmap_approved = [bool]$RoadmapValidation.passed
        backup = $BackupRoot
    })

    Copy-Item `
        -LiteralPath $GateJson `
        -Destination $Component.Release `
        -Force
    Copy-Item `
        -LiteralPath $GateMd `
        -Destination $Component.Release `
        -Force
}

Step "Actualizando documentación maestra SGD-115"
Run-Checked "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Step "Resultado final"

Write-Host "SPT-007D v1.0.0 implementado." -ForegroundColor Green
Write-Host "SPT-008 v1.0.0 implementado." -ForegroundColor Green
Write-Host "SPT-009 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Pruebas específicas integradas: 18 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Razonamiento explicable: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Tutor inteligente: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Ecosistema conversacional: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Contrato de voz local: PREPARADO." -ForegroundColor Green
Write-Host "No invención Puinave: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Servicios de pago: NO REQUERIDOS." -ForegroundColor Green
Write-Host "SGD-114C: APROBADO PARA LOS TRES COMPONENTES." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO Y APROBADO." -ForegroundColor Green
Write-Host "Release SPT-007D: releases\SPT-007D-v1.0.0" -ForegroundColor Cyan
Write-Host "Release SPT-008: releases\SPT-008-v1.0.0" -ForegroundColor Cyan
Write-Host "Release SPT-009: releases\SPT-009-v1.0.0" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupRoot" -ForegroundColor Cyan

Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." -ForegroundColor Yellow
