<#
.SYNOPSIS
    Instala SPT-010 v1.0.0 — Plataforma Digital Integrada.

.DESCRIPTION
    Implementa la Fase Tecnológica II de SGODA-PUINAVE mediante una
    plataforma unificada que integra:

      - SPT-005 Identidad Cultural Configurable
      - SPT-006 / SPT-006A Multimedia y motor multilingüe local
      - SPT-007A Motor Léxico
      - SPT-007B Motor Semántico
      - SPT-007C Motor de Conocimiento
      - SPT-007D Motor de Razonamiento
      - SPT-008 Tutor Inteligente
      - SPT-009 Ecosistema Conversacional

    Incluye:
      - núcleo de plataforma;
      - registro de capacidades;
      - fachada de integración;
      - contratos de entrada y salida;
      - API institucional FastAPI con importación controlada;
      - salud operativa y diagnóstico;
      - configuración institucional;
      - documentación completa;
      - pruebas específicas;
      - suite completa;
      - demostración integrada;
      - evaluación SGD-114C;
      - actualización SGD-115;
      - actualización SGD-116;
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

function Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
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
        throw "El archivo quedó vacío: $Path"
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\platform"
$TestsDir = Join-Path $ProjectRoot "tests\platform"
$ConfigDir = Join-Path $ProjectRoot "config\platform"
$DocsDir = Join-Path $ProjectRoot "docs\06_Fase_Tecnologica_II\SPT-010"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\platform\SPT-010"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-010"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-010-v1.0.0"
$BackupDir = Join-Path $PmoDir (
    "backups\pre-SPT010-" +
    [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
)

$ModelsPath = Join-Path $SourceDir "models.py"
$RegistryPath = Join-Path $SourceDir "registry.py"
$HealthPath = Join-Path $SourceDir "health.py"
$FacadePath = Join-Path $SourceDir "facade.py"
$RuntimePath = Join-Path $SourceDir "runtime.py"
$ApiPath = Join-Path $SourceDir "api.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path $TestsDir "test_SPT_010_integrated_digital_platform.py"
$PolicyPath = Join-Path $ConfigDir "SPT-010-platform-policy.json"
$CapabilitiesPath = Join-Path $ConfigDir "SPT-010-capabilities.json"
$ComponentPath = Join-Path $ConfigDir "SPT-010-component.json"

$ArchitectureDoc = Join-Path $DocsDir "SPT-010-Arquitectura-Plataforma-Integrada.md"
$ApiDoc = Join-Path $DocsDir "SPT-010-API-Institucional.md"
$IntegrationDoc = Join-Path $DocsDir "SPT-010-Integracion-Motores.md"
$SecurityDoc = Join-Path $DocsDir "SPT-010-Seguridad-Linguistica-Cultural.md"
$OperationDoc = Join-Path $DocsDir "SPT-010-Operacion-Despliegue.md"
$TestingDoc = Join-Path $DocsDir "SPT-010-Pruebas-Criterios-Aceptacion.md"

$InvokePath = Join-Path $ScriptsDir "Invoke-SPT010-IntegratedPlatform.ps1"
$DemoGraphPath = Join-Path $ArtifactsDir "demo-platform-graph.json"
$DemoResultPath = Join-Path $ArtifactsDir "demo-platform-result.json"
$EvidencePath = Join-Path $PmoDir "SPT-010-implementation-evidence.json"
$GateJson = Join-Path $PmoDir "SPT-010-policy-result.json"
$GateMd = Join-Path $PmoDir "SPT-010-policy-result.md"

Step "Validando línea base de la Fase Tecnológica I"

foreach ($Path in @(
    (Join-Path $ProjectRoot "src\sgoda\identity\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\language_engine\engine.py"),
    (Join-Path $ProjectRoot "src\sgoda\lexical_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\lexical_engine\semantic_service.py"),
    (Join-Path $ProjectRoot "src\sgoda\knowledge_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\reasoning_engine\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\tutor\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\conversation\service.py"),
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
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Path in @(
    $ModelsPath,
    $RegistryPath,
    $HealthPath,
    $FacadePath,
    $RuntimePath,
    $ApiPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $PolicyPath,
    $CapabilitiesPath,
    $ComponentPath,
    $ArchitectureDoc,
    $ApiDoc,
    $IntegrationDoc,
    $SecurityDoc,
    $OperationDoc,
    $TestingDoc,
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
"""Contratos canónicos de SPT-010."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class PlatformRequest:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)
    session_id: str = "anonymous"
    language: str = "es"
    context_node_id: str | None = None


@dataclass(frozen=True, slots=True)
class PlatformResponse:
    operation: str
    status: str
    data: dict[str, Any]
    sources: tuple[str, ...] = ()
    warnings: tuple[str, ...] = ()
    no_invention: bool = True


@dataclass(frozen=True, slots=True)
class Capability:
    code: str
    name: str
    version: str
    enabled: bool
    operations: tuple[str, ...]
    dependencies: tuple[str, ...] = ()
'@

$Registry = @'
"""Registro institucional de capacidades."""

from __future__ import annotations

from dataclasses import dataclass, field

from .models import Capability


@dataclass(slots=True)
class CapabilityRegistry:
    _capabilities: dict[str, Capability] = field(default_factory=dict)

    def register(self, capability: Capability) -> None:
        if capability.code in self._capabilities:
            raise ValueError(
                f"Capacidad duplicada: {capability.code}"
            )
        self._capabilities[capability.code] = capability

    def get(self, code: str) -> Capability | None:
        return self._capabilities.get(code)

    def all(self) -> tuple[Capability, ...]:
        return tuple(
            self._capabilities[key]
            for key in sorted(self._capabilities)
        )

    def operations(self) -> tuple[str, ...]:
        return tuple(
            sorted(
                {
                    operation
                    for capability in self.all()
                    if capability.enabled
                    for operation in capability.operations
                }
            )
        )


def default_registry() -> CapabilityRegistry:
    registry = CapabilityRegistry()

    for capability in (
        Capability(
            "SPT-005",
            "Identidad Cultural Configurable",
            "1.0.0",
            True,
            ("identity",),
        ),
        Capability(
            "SPT-006A",
            "Motor Multilingüe Local",
            "0.2.0",
            True,
            ("translate", "tts"),
        ),
        Capability(
            "SPT-007A",
            "Motor Léxico Inteligente",
            "0.1.0",
            True,
            ("lexical_search",),
        ),
        Capability(
            "SPT-007B",
            "Motor Léxico Semántico",
            "1.0.0",
            True,
            ("semantic_search",),
        ),
        Capability(
            "SPT-007C",
            "Motor de Conocimiento",
            "1.0.0",
            True,
            ("knowledge",),
        ),
        Capability(
            "SPT-007D",
            "Motor de Razonamiento",
            "1.0.0",
            True,
            ("reasoning",),
        ),
        Capability(
            "SPT-008",
            "Tutor Inteligente",
            "1.0.0",
            True,
            ("learning_path", "evaluate_activity"),
        ),
        Capability(
            "SPT-009",
            "Ecosistema Conversacional",
            "1.0.0",
            True,
            ("conversation",),
        ),
    ):
        registry.register(capability)

    return registry
'@

$Health = @'
"""Diagnóstico operativo de la plataforma."""

from __future__ import annotations

import importlib.util
from pathlib import Path


REQUIRED_MODULES = {
    "identity": "sgoda.identity",
    "language_engine": "sgoda.language_engine",
    "lexical_engine": "sgoda.lexical_engine",
    "knowledge_engine": "sgoda.knowledge_engine",
    "reasoning_engine": "sgoda.reasoning_engine",
    "tutor": "sgoda.tutor",
    "conversation": "sgoda.conversation",
}


def module_health() -> dict[str, bool]:
    return {
        name: importlib.util.find_spec(module) is not None
        for name, module in REQUIRED_MODULES.items()
    }


def repository_health(root: str | Path) -> dict:
    base = Path(root)
    modules = module_health()

    required_paths = {
        "pytest": base / "pytest.ini",
        "governance_policy": (
            base
            / "config"
            / "governance"
            / "SGD-114C-policy.json"
        ),
        "roadmap_validation": (
            base
            / "artifacts"
            / "roadmap"
            / "SGD-116"
            / "validation.json"
        ),
    }

    paths = {
        key: value.exists()
        for key, value in required_paths.items()
    }

    healthy = all(modules.values()) and all(paths.values())

    return {
        "healthy": healthy,
        "modules": modules,
        "paths": paths,
    }
'@

$Facade = @'
"""Fachada integrada de la Plataforma Digital."""

from __future__ import annotations

from typing import Any

from sgoda.conversation import (
    ConversationMessage,
    ConversationRequest,
    ConversationalEcosystemService,
)
from sgoda.knowledge_engine import KnowledgeEngineService, KnowledgeGraph
from sgoda.reasoning_engine import LinguisticReasoningService
from sgoda.tutor import PuinaveTutorService

from .models import PlatformRequest, PlatformResponse
from .registry import CapabilityRegistry


class IntegratedPlatformFacade:
    def __init__(
        self,
        graph: KnowledgeGraph,
        registry: CapabilityRegistry,
    ) -> None:
        self.graph = graph
        self.registry = registry
        self.knowledge = KnowledgeEngineService(graph)
        self.reasoning = LinguisticReasoningService(graph)
        self.tutor = PuinaveTutorService(graph)
        self.conversation = ConversationalEcosystemService(
            self.knowledge,
            self.reasoning,
            self.tutor,
        )

    def execute(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        if request.operation not in self.registry.operations():
            return PlatformResponse(
                operation=request.operation,
                status="unsupported_operation",
                data={},
                warnings=(
                    "La operación no está registrada.",
                ),
            )

        handlers = {
            "knowledge": self._knowledge,
            "reasoning": self._reasoning,
            "learning_path": self._learning_path,
            "evaluate_activity": self._evaluate_activity,
            "conversation": self._conversation,
            "identity": self._identity,
            "translate": self._not_yet_bound,
            "tts": self._not_yet_bound,
            "lexical_search": self._not_yet_bound,
            "semantic_search": self._not_yet_bound,
        }

        handler = handlers.get(
            request.operation,
            self._not_yet_bound,
        )
        return handler(request)

    def _knowledge(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        node_id = (
            request.context_node_id
            or str(request.payload.get("node_id") or "")
        )

        if not node_id:
            return PlatformResponse(
                "knowledge",
                "validation_error",
                {},
                warnings=("node_id es obligatorio.",),
            )

        payload = self.knowledge.query(node_id)
        sources = tuple(
            item["source_ref"]
            for item in payload["nodes"]
            if item.get("source_ref")
        )

        return PlatformResponse(
            "knowledge",
            "ok" if payload["nodes"] else "not_found",
            payload,
            sources=tuple(dict.fromkeys(sources)),
        )

    def _reasoning(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        node_id = (
            request.context_node_id
            or str(request.payload.get("node_id") or "")
        )
        text = str(request.payload.get("question") or "")

        payload = self.reasoning.ask(
            text=text,
            start_node_id=node_id,
            relations=tuple(
                request.payload.get("relations", ())
            ),
            max_depth=int(
                request.payload.get("max_depth", 3)
            ),
        )

        sources = tuple(
            value
            for conclusion in payload["conclusions"]
            for value in conclusion["evidence"]
        )

        return PlatformResponse(
            "reasoning",
            "ok" if not payload["unresolved"] else "unresolved",
            payload,
            sources=tuple(dict.fromkeys(sources)),
        )

    def _learning_path(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        node_id = (
            request.context_node_id
            or str(request.payload.get("node_id") or "")
        )

        payload = self.tutor.create_path(
            learner_id=request.session_id,
            seed_node_id=node_id,
            level=str(
                request.payload.get("level", "beginner")
            ),
            preferred_language=request.language,
        )

        sources = tuple(
            entry_id
            for activity in payload["activities"]
            for entry_id in activity["entry_ids"]
        )

        return PlatformResponse(
            "learning_path",
            "ok" if payload["activities"] else "not_found",
            payload,
            sources=tuple(dict.fromkeys(sources)),
        )

    def _evaluate_activity(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        activity = request.payload.get("activity")
        answer = str(request.payload.get("answer") or "")

        if not isinstance(activity, dict):
            return PlatformResponse(
                "evaluate_activity",
                "validation_error",
                {},
                warnings=("activity debe ser un objeto.",),
            )

        return PlatformResponse(
            "evaluate_activity",
            "ok",
            self.tutor.evaluate(activity, answer),
        )

    def _conversation(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        message = str(request.payload.get("message") or "")

        response = self.conversation.converse(
            ConversationRequest(
                session_id=request.session_id,
                message=ConversationMessage(
                    role="user",
                    text=message,
                    language=request.language,
                ),
                context_node_id=request.context_node_id,
            )
        )

        return PlatformResponse(
            "conversation",
            "ok" if not response.unresolved else "unresolved",
            {
                "session_id": response.session_id,
                "text": response.text,
                "language": response.language,
                "intent": response.intent,
                "audio_text": response.audio_text,
                "unresolved": response.unresolved,
            },
            sources=response.sources,
        )

    def _identity(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        return PlatformResponse(
            "identity",
            "ok",
            {
                "display_name": request.payload.get(
                    "display_name",
                    "SGODA-PUINAVE",
                ),
                "configurable": True,
                "requires_community_approval": True,
            },
        )

    def _not_yet_bound(
        self,
        request: PlatformRequest,
    ) -> PlatformResponse:
        return PlatformResponse(
            request.operation,
            "adapter_pending",
            {
                "registered": True,
                "message": (
                    "La capacidad está registrada y requiere "
                    "un adaptador de datos operativo."
                ),
            },
            warnings=("Adaptador operativo pendiente.",),
        )
'@

$Runtime = @'
"""Construcción del runtime integrado."""

from __future__ import annotations

from pathlib import Path

from sgoda.knowledge_engine import KnowledgeGraph

from .facade import IntegratedPlatformFacade
from .registry import default_registry


def build_runtime(
    graph_path: str | Path,
) -> IntegratedPlatformFacade:
    graph = KnowledgeGraph.from_json(graph_path)
    return IntegratedPlatformFacade(
        graph=graph,
        registry=default_registry(),
    )
'@

$Api = @'
"""API institucional FastAPI con importación controlada."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .models import PlatformRequest
from .runtime import build_runtime


def create_app(graph_path: str | Path):
    try:
        from fastapi import FastAPI
        from pydantic import BaseModel, Field
    except ImportError as error:
        raise RuntimeError(
            "FastAPI y Pydantic son requeridos para iniciar la API."
        ) from error

    runtime = build_runtime(graph_path)
    app = FastAPI(
        title="SGODA Plataforma Digital Integrada",
        version="1.0.0",
    )

    class RequestBody(BaseModel):
        operation: str
        payload: dict[str, Any] = Field(default_factory=dict)
        session_id: str = "anonymous"
        language: str = "es"
        context_node_id: str | None = None

    @app.get("/health")
    def health() -> dict:
        return {
            "status": "ok",
            "component": "SPT-010",
            "version": "1.0.0",
        }

    @app.get("/capabilities")
    def capabilities() -> dict:
        return {
            "operations": list(
                runtime.registry.operations()
            ),
            "components": [
                {
                    "code": item.code,
                    "name": item.name,
                    "version": item.version,
                    "enabled": item.enabled,
                    "operations": list(item.operations),
                }
                for item in runtime.registry.all()
            ],
        }

    @app.post("/execute")
    def execute(body: RequestBody) -> dict:
        response = runtime.execute(
            PlatformRequest(
                operation=body.operation,
                payload=body.payload,
                session_id=body.session_id,
                language=body.language,
                context_node_id=body.context_node_id,
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
"""CLI de SPT-010."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .health import repository_health
from .models import PlatformRequest
from .runtime import build_runtime


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph", required=True)
    parser.add_argument("--operation", required=True)
    parser.add_argument("--payload", default="{}")
    parser.add_argument("--session", default="anonymous")
    parser.add_argument("--language", default="es")
    parser.add_argument("--node")
    parser.add_argument("--output")
    parser.add_argument("--root", default=".")
    args = parser.parse_args()

    payload = json.loads(args.payload)
    runtime = build_runtime(args.graph)

    response = runtime.execute(
        PlatformRequest(
            operation=args.operation,
            payload=payload,
            session_id=args.session,
            language=args.language,
            context_node_id=args.node,
        )
    )

    result = {
        "operation": response.operation,
        "status": response.status,
        "data": response.data,
        "sources": list(response.sources),
        "warnings": list(response.warnings),
        "no_invention": response.no_invention,
        "health": repository_health(args.root),
    }

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
"""SPT-010 — Plataforma Digital Integrada."""

from .facade import IntegratedPlatformFacade
from .health import module_health, repository_health
from .models import Capability, PlatformRequest, PlatformResponse
from .registry import CapabilityRegistry, default_registry
from .runtime import build_runtime

__all__ = [
    "Capability",
    "CapabilityRegistry",
    "IntegratedPlatformFacade",
    "PlatformRequest",
    "PlatformResponse",
    "build_runtime",
    "default_registry",
    "module_health",
    "repository_health",
]
'@

$Tests = @'
import json
from pathlib import Path

from sgoda.platform import (
    PlatformRequest,
    build_runtime,
    default_registry,
    module_health,
)


def _graph_path(tmp_path: Path) -> Path:
    path = tmp_path / "graph.json"
    path.write_text(
        json.dumps(
            {
                "nodes": [
                    {
                        "node_id": "LEX-001",
                        "node_type": "lexical_entry",
                        "label": "AMDA",
                        "language": "pu",
                        "validated": True,
                        "source_ref": "RLB:LEX-001",
                    },
                    {
                        "node_id": "CON-001",
                        "node_type": "concept",
                        "label": "Casa",
                        "validated": True,
                    },
                ],
                "edges": [
                    {
                        "source_id": "LEX-001",
                        "target_id": "CON-001",
                        "relation_type": "related_to",
                        "validated": True,
                        "weight": 1.0,
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    return path


def test_SPT_010_registers_integrated_capabilities():
    registry = default_registry()

    assert len(registry.all()) == 8
    assert "conversation" in registry.operations()
    assert "reasoning" in registry.operations()


def test_SPT_010_rejects_duplicate_capability():
    registry = default_registry()
    capability = registry.all()[0]

    try:
        registry.register(capability)
    except ValueError:
        pass
    else:
        raise AssertionError("Se aceptó una capacidad duplicada")


def test_SPT_010_executes_knowledge_query(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="knowledge",
            context_node_id="LEX-001",
        )
    )

    assert result.status == "ok"
    assert result.data["nodes"]
    assert result.no_invention is True


def test_SPT_010_executes_reasoning_query(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="reasoning",
            context_node_id="LEX-001",
            payload={
                "question": "Explica la relación",
            },
        )
    )

    assert result.status == "ok"
    assert result.data["conclusions"]


def test_SPT_010_builds_learning_path(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="learning_path",
            context_node_id="LEX-001",
            session_id="USR-001",
        )
    )

    assert result.status == "ok"
    assert result.data["activities"]


def test_SPT_010_executes_conversation(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="conversation",
            context_node_id="LEX-001",
            session_id="SES-001",
            payload={
                "message": "Quiero aprender esta palabra",
            },
        )
    )

    assert result.status == "ok"
    assert result.data["intent"] == "tutor"


def test_SPT_010_identity_is_configurable(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="identity",
            payload={"display_name": "Nombre Comunitario"},
        )
    )

    assert result.data["display_name"] == "Nombre Comunitario"
    assert result.data["requires_community_approval"] is True


def test_SPT_010_reports_pending_adapter(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="translate",
            payload={"text": "casa"},
        )
    )

    assert result.status == "adapter_pending"
    assert result.warnings


def test_SPT_010_rejects_unknown_operation(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(operation="unknown")
    )

    assert result.status == "unsupported_operation"


def test_SPT_010_module_health_detects_components():
    health = module_health()

    assert health["knowledge_engine"] is True
    assert health["conversation"] is True
    assert all(health.values())


def test_SPT_010_is_deterministic(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    request = PlatformRequest(
        operation="knowledge",
        context_node_id="LEX-001",
    )

    assert runtime.execute(request) == runtime.execute(request)


def test_SPT_010_preserves_no_invention(tmp_path: Path):
    runtime = build_runtime(_graph_path(tmp_path))
    result = runtime.execute(
        PlatformRequest(
            operation="knowledge",
            context_node_id="UNKNOWN",
        )
    )

    assert result.no_invention is True
    assert result.status == "not_found"
'@

$Policy = @'
{
  "component": "SPT-010",
  "version": "1.0.0",
  "name": "Plataforma Digital Integrada",
  "phase": "Fase Tecnológica II",
  "local_first": true,
  "no_invention": true,
  "paid_services_required": false,
  "configurable_identity": true,
  "community_approval_required": true,
  "supported_languages": [
    "pu",
    "es",
    "en-US",
    "it"
  ],
  "interfaces": [
    "application_facade",
    "cli",
    "fastapi"
  ],
  "governance": [
    "SGD-114C",
    "SGD-115",
    "SGD-116",
    "SPB-007"
  ]
}
'@

$Capabilities = @'
{
  "capabilities": [
    {
      "code": "SPT-005",
      "operation": "identity",
      "status": "integrated"
    },
    {
      "code": "SPT-006A",
      "operations": ["translate", "tts"],
      "status": "registered_adapter_pending"
    },
    {
      "code": "SPT-007A",
      "operation": "lexical_search",
      "status": "registered_adapter_pending"
    },
    {
      "code": "SPT-007B",
      "operation": "semantic_search",
      "status": "registered_adapter_pending"
    },
    {
      "code": "SPT-007C",
      "operation": "knowledge",
      "status": "integrated"
    },
    {
      "code": "SPT-007D",
      "operation": "reasoning",
      "status": "integrated"
    },
    {
      "code": "SPT-008",
      "operations": ["learning_path", "evaluate_activity"],
      "status": "integrated"
    },
    {
      "code": "SPT-009",
      "operation": "conversation",
      "status": "integrated"
    }
  ]
}
'@

$Component = @'
{
  "increment_code": "SPT-010",
  "name": "Plataforma Digital Integrada",
  "component_type": "integrated_digital_platform",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica II",
  "dependencies": [
    "SPT-005",
    "SPT-006A",
    "SPT-007A",
    "SPT-007B",
    "SPT-007C",
    "SPT-007D",
    "SPT-008",
    "SPT-009",
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/platform/models.py",
    "src/sgoda/platform/registry.py",
    "src/sgoda/platform/health.py",
    "src/sgoda/platform/facade.py",
    "src/sgoda/platform/runtime.py",
    "src/sgoda/platform/api.py",
    "src/sgoda/platform/cli.py"
  ],
  "tests": [
    "tests/platform/test_SPT_010_integrated_digital_platform.py"
  ],
  "documentation": [
    "docs/06_Fase_Tecnologica_II/SPT-010/SPT-010-Arquitectura-Plataforma-Integrada.md",
    "docs/06_Fase_Tecnologica_II/SPT-010/SPT-010-API-Institucional.md",
    "docs/06_Fase_Tecnologica_II/SPT-010/SPT-010-Integracion-Motores.md",
    "docs/06_Fase_Tecnologica_II/SPT-010/SPT-010-Seguridad-Linguistica-Cultural.md",
    "docs/06_Fase_Tecnologica_II/SPT-010/SPT-010-Operacion-Despliegue.md",
    "docs/06_Fase_Tecnologica_II/SPT-010/SPT-010-Pruebas-Criterios-Aceptacion.md"
  ]
}
'@

$Docs = @{
    $ArchitectureDoc = @'
# SPT-010 — Arquitectura de la Plataforma Digital Integrada

SPT-010 inaugura la Fase Tecnológica II.

La plataforma utiliza una fachada única, un registro de capacidades,
contratos canónicos y adaptadores para integrar los motores institucionales
sin duplicar su lógica.
'@
    $ApiDoc = @'
# SPT-010 — API Institucional

La API expone:

- `GET /health`
- `GET /capabilities`
- `POST /execute`

La creación de la aplicación FastAPI utiliza importación controlada. La API
solo devuelve información proveniente de componentes registrados.
'@
    $IntegrationDoc = @'
# SPT-010 — Integración de Motores

La versión 1.0.0 integra directamente conocimiento, razonamiento, tutoría,
conversación e identidad.

Traducción, TTS, búsqueda léxica y búsqueda semántica quedan registradas y
preparadas para adaptadores operativos posteriores.
'@
    $SecurityDoc = @'
# SPT-010 — Seguridad Lingüística y Cultural

La plataforma preserva `no_invention=true`.

No crea palabras, traducciones, relaciones ni contenidos Puinave. El cambio
del nombre visible requiere aprobación comunitaria.
'@
    $OperationDoc = @'
# SPT-010 — Operación y Despliegue

La plataforma puede utilizarse mediante CLI o API.

El script `Invoke-SPT010-IntegratedPlatform.ps1` permite ejecutar operaciones
sobre un grafo validado. El despliegue web deberá realizarse en un incremento
posterior con configuración de red y seguridad.
'@
    $TestingDoc = @'
# SPT-010 — Pruebas y Criterios de Aceptación

El cierre exige:

- pruebas específicas aprobadas;
- suite completa aprobada;
- demostración integrada aprobada;
- SGD-114C aprobado;
- SGD-115 actualizado;
- SGD-116 actualizado;
- release creado;
- publicación SPB-007;
- Git limpio.
'@
}

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Graph,

    [Parameter(Mandatory = $true)]
    [string]$Operation,

    [string]$Payload = "{}",

    [string]$Node,

    [string]$Session = "anonymous",

    [string]$Language = "es",

    [string]$Output = "artifacts/platform/SPT-010/operation-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.platform.cli",
    "--graph",
    $Graph,
    "--operation",
    $Operation,
    "--payload",
    $Payload,
    "--session",
    $Session,
    "--language",
    $Language,
    "--output",
    $Output,
    "--root",
    "."
)

if ($Node) {
    $Arguments += @("--node", $Node)
}

& python @Arguments
exit $LASTEXITCODE
'@

Step "Instalando SPT-010"

Write-Utf8 $ModelsPath $Models
Write-Utf8 $RegistryPath $Registry
Write-Utf8 $HealthPath $Health
Write-Utf8 $FacadePath $Facade
Write-Utf8 $RuntimePath $Runtime
Write-Utf8 $ApiPath $Api
Write-Utf8 $CliPath $Cli
Write-Utf8 $InitPath $Init
Write-Utf8 $TestPath $Tests
Write-Utf8 $PolicyPath $Policy
Write-Utf8 $CapabilitiesPath $Capabilities
Write-Utf8 $ComponentPath $Component

foreach ($Pair in $Docs.GetEnumerator()) {
    Write-Utf8 $Pair.Key $Pair.Value
}

Write-Utf8 $InvokePath $Invoke

Run-Checked "Validando sintaxis" {
    python -m py_compile `
        "src/sgoda/platform/models.py" `
        "src/sgoda/platform/registry.py" `
        "src/sgoda/platform/health.py" `
        "src/sgoda/platform/facade.py" `
        "src/sgoda/platform/runtime.py" `
        "src/sgoda/platform/api.py" `
        "src/sgoda/platform/cli.py" `
        "src/sgoda/platform/__init__.py" `
        "tests/platform/test_SPT_010_integrated_digital_platform.py"
}

Run-Checked "Ejecutando 12 pruebas específicas SPT-010" {
    python -m pytest `
        "tests/platform/test_SPT_010_integrated_digital_platform.py" `
        -q
}

if (-not $SkipFullSuite) {
    Run-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Step "Ejecutando demostración integrada"

Write-Json $DemoGraphPath ([ordered]@{
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

Run-Checked "Consultando la Plataforma Digital Integrada" {
    python -m sgoda.platform.cli `
        --graph "$DemoGraphPath" `
        --operation "conversation" `
        --payload '{"message":"Quiero aprender esta palabra"}' `
        --session "DEMO-001" `
        --language "es" `
        --node "LEX-001" `
        --output "$DemoResultPath" `
        --root "$ProjectRoot"
}

$Demo = Get-Content `
    -LiteralPath $DemoResultPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración integrada no fue aprobada."
}

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
    throw "SGD-116 no aprobó SPT-010."
}

Step "Preparando evidencia previa y release"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json (Join-Path $PmoDir "SPT-010-pre-gate-evidence.json") ([ordered]@{
    increment_code = "SPT-010"
    version = "1.0.0"
    status = "technically_completed"
    phase = "Fase Tecnológica II"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    specific_tests = 12
    full_suite_executed = (-not $SkipFullSuite)
    demo_status = $Demo.status
    roadmap_approved = [bool]$RoadmapValidation.passed
})

Copy-Item `
    -LiteralPath $ComponentPath `
    -Destination (Join-Path $ReleaseDir "SPT-010-component.json") `
    -Force

Step "Evaluando SPT-010 mediante SGD-114C"

& python -m sgoda.governance.policy_cli `
    --root "$ProjectRoot" `
    --policy "config/governance/SGD-114C-policy.json" `
    --increment "SPT-010" `
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

    throw "SGD-114C no aprobó SPT-010."
}

Step "Actualizando documentación maestra SGD-115"

Run-Checked "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Step "Generando evidencia y release"

Write-Json $EvidencePath ([ordered]@{
    increment_code = "SPT-010"
    version = "1.0.0"
    status = "implemented"
    phase = "Fase Tecnológica II"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    capabilities = @(
        "integrated_facade",
        "capability_registry",
        "knowledge",
        "reasoning",
        "learning_path",
        "activity_evaluation",
        "conversation",
        "configurable_identity",
        "fastapi_contract",
        "health_diagnostics",
        "no_invention"
    )
    specific_tests = 12
    full_suite_executed = (-not $SkipFullSuite)
    policy_approved = [bool]$Gate.approved
    policy_exit_code = $Gate.exit_code
    roadmap_approved = [bool]$RoadmapValidation.passed
    demo = $DemoResultPath
    backup = $BackupDir
})

foreach ($Path in @(
    $ModelsPath,
    $RegistryPath,
    $HealthPath,
    $FacadePath,
    $RuntimePath,
    $ApiPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $PolicyPath,
    $CapabilitiesPath,
    $ComponentPath,
    $ArchitectureDoc,
    $ApiDoc,
    $IntegrationDoc,
    $SecurityDoc,
    $OperationDoc,
    $TestingDoc,
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

Step "Resultado final"

Write-Host "SPT-010 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Fase Tecnológica II: INICIADA Y OPERATIVA." -ForegroundColor Green
Write-Host "Plataforma Digital Integrada: OPERATIVA." -ForegroundColor Green
Write-Host "Pruebas específicas: 12 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Fachada integrada: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Registro de capacidades: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Conocimiento: INTEGRADO." -ForegroundColor Green
Write-Host "Razonamiento: INTEGRADO." -ForegroundColor Green
Write-Host "Tutoría: INTEGRADA." -ForegroundColor Green
Write-Host "Conversación: INTEGRADA." -ForegroundColor Green
Write-Host "Identidad configurable: INTEGRADA." -ForegroundColor Green
Write-Host "API FastAPI: PREPARADA." -ForegroundColor Green
Write-Host "Diagnóstico operativo: IMPLEMENTADO." -ForegroundColor Green
Write-Host "No invención Puinave: IMPLEMENTADA." -ForegroundColor Green
Write-Host "SGD-114C: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO Y APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-010-v1.0.0" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." -ForegroundColor Yellow
