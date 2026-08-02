<#
.SYNOPSIS
    Instala SPT-007C v1.0.0 — Motor de Conocimiento Lingüístico y Cultural.

.DESCRIPTION
    Amplía SPT-007A y SPT-007B para transformar el buscador semántico en
    un motor de conocimiento lingüístico y cultural gobernado.

    Incluye:
      - grafo de conocimiento local;
      - nodos léxicos, culturales, multimedia y ODA;
      - relaciones tipadas y validadas;
      - ontología mínima institucional;
      - inferencia controlada y explicable;
      - navegación conceptual;
      - recomendación de conocimiento relacionado;
      - integración con SPT-006, SPT-007A, SPT-007B y SPT-002;
      - no invención de conocimiento Puinave;
      - operación local y sin servicios de pago;
      - pruebas específicas;
      - suite completa;
      - SGD-114C;
      - SGD-115;
      - SGD-116;
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\knowledge_engine"
$TestsDir = Join-Path $ProjectRoot "tests\knowledge_engine"
$ConfigDir = Join-Path $ProjectRoot "config\knowledge_engine"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-007"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\knowledge_engine\SPT-007C"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-007C"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-007C-v1.0.0"

$ModelsPath = Join-Path $SourceDir "models.py"
$OntologyPath = Join-Path $SourceDir "ontology.py"
$GraphPath = Join-Path $SourceDir "graph.py"
$InferencePath = Join-Path $SourceDir "inference.py"
$NavigationPath = Join-Path $SourceDir "navigation.py"
$OdaBridgePath = Join-Path $SourceDir "oda_bridge.py"
$ServicePath = Join-Path $SourceDir "service.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path $TestsDir "test_SPT_007C_knowledge_engine.py"
$PolicyPath = Join-Path $ConfigDir "SPT-007C-knowledge-policy.json"
$OntologyConfigPath = Join-Path $ConfigDir "SPT-007C-ontology.json"
$ComponentPath = Join-Path $ConfigDir "SPT-007C-component.json"

$DocPath = Join-Path $DocsDir "SPT-007C-Motor-Conocimiento-Linguistico-Cultural.md"
$ArchitecturePath = Join-Path $DocsDir "SPT-007C-Arquitectura-Grafo-Conocimiento.md"
$OntologyDocPath = Join-Path $DocsDir "SPT-007C-Ontologia-Linguistica-Cultural.md"
$InferenceDocPath = Join-Path $DocsDir "SPT-007C-Inferencia-Controlada-Explicable.md"
$OdaDocPath = Join-Path $DocsDir "SPT-007C-Integracion-ODA-Multimedia.md"
$AcceptanceDocPath = Join-Path $DocsDir "SPT-007C-Pruebas-Criterios-Aceptacion.md"
$OperationDocPath = Join-Path $DocsDir "SPT-007C-Operacion-Mantenimiento.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT007C-KnowledgeEngine.ps1"

$DemoGraphPath = Join-Path $ArtifactsDir "demo-knowledge-graph.json"
$DemoResultPath = Join-Path $ArtifactsDir "demo-knowledge-query.json"
$EvidencePath = Join-Path $PmoDir "SPT-007C-implementation-evidence.json"
$GateJson = Join-Path $PmoDir "SPT-007C-policy-result.json"
$GateMd = Join-Path $PmoDir "SPT-007C-policy-result.md"
$BackupDir = Join-Path $PmoDir (
    "backups\pre-SPT007C-" +
    [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
)

Write-Step "Validando línea base SPT-007B y gobernanza"

foreach ($Path in @(
    (Join-Path $ProjectRoot "src\sgoda\lexical_engine\semantic_service.py"),
    (Join-Path $ProjectRoot "config\lexical_engine\SPT-007B-component.json"),
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
    $ModelsPath,
    $OntologyPath,
    $GraphPath,
    $InferencePath,
    $NavigationPath,
    $OdaBridgePath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $PolicyPath,
    $OntologyConfigPath,
    $ComponentPath,
    $DocPath,
    $ArchitecturePath,
    $OntologyDocPath,
    $InferenceDocPath,
    $OdaDocPath,
    $AcceptanceDocPath,
    $OperationDocPath,
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
"""Modelos del Motor de Conocimiento SPT-007C."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class KnowledgeNode:
    node_id: str
    node_type: str
    label: str
    language: str | None = None
    validated: bool = False
    cultural_status: str = "pending"
    source_ref: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class KnowledgeEdge:
    source_id: str
    target_id: str
    relation_type: str
    weight: float = 1.0
    validated: bool = False
    cultural: bool = False
    source_ref: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class InferenceStep:
    source_id: str
    relation_type: str
    target_id: str
    rule_code: str
    explanation: str


@dataclass(frozen=True, slots=True)
class KnowledgeResult:
    query_node_id: str
    nodes: tuple[KnowledgeNode, ...]
    edges: tuple[KnowledgeEdge, ...]
    inference_steps: tuple[InferenceStep, ...]
    no_invention: bool = True
'@

$Ontology = @'
"""Ontología mínima institucional de SPT-007C."""

from __future__ import annotations


ALLOWED_NODE_TYPES = {
    "lexical_entry",
    "concept",
    "cultural_practice",
    "place",
    "person",
    "animal",
    "plant",
    "object",
    "story",
    "media",
    "oda",
    "category",
}


ALLOWED_RELATION_TYPES = {
    "is_a",
    "part_of",
    "related_to",
    "synonym_of",
    "variant_of",
    "family_of",
    "used_in",
    "located_in",
    "appears_in",
    "has_media",
    "has_oda",
    "teaches",
    "broader_than",
    "narrower_than",
    "cultural_relation",
}


TRANSITIVE_RELATIONS = {
    "is_a",
    "part_of",
    "broader_than",
    "narrower_than",
}


SYMMETRIC_RELATIONS = {
    "related_to",
    "synonym_of",
    "family_of",
    "cultural_relation",
}


def is_allowed_node_type(value: str) -> bool:
    return str(value).strip().casefold() in ALLOWED_NODE_TYPES


def is_allowed_relation_type(value: str) -> bool:
    return str(value).strip().casefold() in ALLOWED_RELATION_TYPES
'@

$Graph = @'
"""Grafo de conocimiento local, determinista y gobernado."""

from __future__ import annotations

import json
from collections import defaultdict, deque
from pathlib import Path
from typing import Any

from .models import KnowledgeEdge, KnowledgeNode
from .ontology import (
    SYMMETRIC_RELATIONS,
    is_allowed_node_type,
    is_allowed_relation_type,
)


class KnowledgeGraph:
    def __init__(self) -> None:
        self._nodes: dict[str, KnowledgeNode] = {}
        self._outgoing: dict[str, list[KnowledgeEdge]] = defaultdict(list)
        self._incoming: dict[str, list[KnowledgeEdge]] = defaultdict(list)

    def add_node(self, node: KnowledgeNode) -> None:
        if not node.node_id.strip():
            raise ValueError("node_id es obligatorio.")

        if not is_allowed_node_type(node.node_type):
            raise ValueError(
                f"Tipo de nodo no permitido: {node.node_type}"
            )

        self._nodes[node.node_id] = node

    def add_edge(self, edge: KnowledgeEdge) -> None:
        if edge.source_id == edge.target_id:
            raise ValueError("No se permiten relaciones autorreferenciales.")

        if edge.source_id not in self._nodes:
            raise KeyError(f"Nodo origen inexistente: {edge.source_id}")

        if edge.target_id not in self._nodes:
            raise KeyError(f"Nodo destino inexistente: {edge.target_id}")

        if not is_allowed_relation_type(edge.relation_type):
            raise ValueError(
                f"Tipo de relación no permitido: {edge.relation_type}"
            )

        normalized = KnowledgeEdge(
            source_id=edge.source_id,
            target_id=edge.target_id,
            relation_type=edge.relation_type.casefold(),
            weight=max(0.0, min(1.0, edge.weight)),
            validated=edge.validated,
            cultural=edge.cultural,
            source_ref=edge.source_ref,
            metadata=edge.metadata,
        )

        self._outgoing[normalized.source_id].append(normalized)
        self._incoming[normalized.target_id].append(normalized)

        if normalized.relation_type in SYMMETRIC_RELATIONS:
            reverse = KnowledgeEdge(
                source_id=normalized.target_id,
                target_id=normalized.source_id,
                relation_type=normalized.relation_type,
                weight=normalized.weight,
                validated=normalized.validated,
                cultural=normalized.cultural,
                source_ref=normalized.source_ref,
                metadata={
                    **normalized.metadata,
                    "generated_reverse": True,
                },
            )
            self._outgoing[reverse.source_id].append(reverse)
            self._incoming[reverse.target_id].append(reverse)

    def get_node(self, node_id: str) -> KnowledgeNode | None:
        return self._nodes.get(node_id)

    def nodes(self) -> tuple[KnowledgeNode, ...]:
        return tuple(
            self._nodes[key]
            for key in sorted(self._nodes)
        )

    def outgoing(
        self,
        node_id: str,
        validated_only: bool = True,
    ) -> tuple[KnowledgeEdge, ...]:
        edges = self._outgoing.get(node_id, [])

        if validated_only:
            edges = [item for item in edges if item.validated]

        return tuple(
            sorted(
                edges,
                key=lambda item: (
                    item.relation_type,
                    item.target_id,
                ),
            )
        )

    def neighborhood(
        self,
        node_id: str,
        depth: int = 1,
        validated_only: bool = True,
    ) -> tuple[tuple[KnowledgeNode, ...], tuple[KnowledgeEdge, ...]]:
        if node_id not in self._nodes:
            return (), ()

        visited = {node_id}
        queue = deque([(node_id, 0)])
        edges: list[KnowledgeEdge] = []

        while queue:
            current, current_depth = queue.popleft()

            if current_depth >= max(0, depth):
                continue

            for edge in self.outgoing(
                current,
                validated_only=validated_only,
            ):
                edges.append(edge)

                if edge.target_id not in visited:
                    visited.add(edge.target_id)
                    queue.append(
                        (edge.target_id, current_depth + 1)
                    )

        nodes = tuple(
            self._nodes[item]
            for item in sorted(visited)
            if item in self._nodes
        )

        unique_edges = {
            (
                item.source_id,
                item.target_id,
                item.relation_type,
            ): item
            for item in edges
        }

        return nodes, tuple(
            unique_edges[key]
            for key in sorted(unique_edges)
        )

    @classmethod
    def from_records(
        cls,
        nodes: list[dict[str, Any]],
        edges: list[dict[str, Any]],
    ) -> "KnowledgeGraph":
        graph = cls()

        for item in nodes:
            graph.add_node(
                KnowledgeNode(
                    node_id=str(item.get("node_id") or "").strip(),
                    node_type=str(item.get("node_type") or "").strip(),
                    label=str(item.get("label") or "").strip(),
                    language=(
                        str(item.get("language")).strip()
                        if item.get("language")
                        else None
                    ),
                    validated=bool(item.get("validated", False)),
                    cultural_status=str(
                        item.get("cultural_status", "pending")
                    ),
                    source_ref=(
                        str(item.get("source_ref")).strip()
                        if item.get("source_ref")
                        else None
                    ),
                    metadata={
                        key: value
                        for key, value in item.items()
                        if key not in {
                            "node_id",
                            "node_type",
                            "label",
                            "language",
                            "validated",
                            "cultural_status",
                            "source_ref",
                        }
                    },
                )
            )

        for item in edges:
            graph.add_edge(
                KnowledgeEdge(
                    source_id=str(
                        item.get("source_id") or ""
                    ).strip(),
                    target_id=str(
                        item.get("target_id") or ""
                    ).strip(),
                    relation_type=str(
                        item.get("relation_type") or ""
                    ).strip(),
                    weight=float(item.get("weight", 1.0)),
                    validated=bool(item.get("validated", False)),
                    cultural=bool(item.get("cultural", False)),
                    source_ref=(
                        str(item.get("source_ref")).strip()
                        if item.get("source_ref")
                        else None
                    ),
                    metadata={
                        key: value
                        for key, value in item.items()
                        if key not in {
                            "source_id",
                            "target_id",
                            "relation_type",
                            "weight",
                            "validated",
                            "cultural",
                            "source_ref",
                        }
                    },
                )
            )

        return graph

    @classmethod
    def from_json(cls, path: str | Path) -> "KnowledgeGraph":
        payload = json.loads(
            Path(path).read_text(encoding="utf-8-sig")
        )

        return cls.from_records(
            list(payload.get("nodes", [])),
            list(payload.get("edges", [])),
        )
'@

$Inference = @'
"""Inferencia controlada, explicable y sin invención."""

from __future__ import annotations

from collections import defaultdict

from .graph import KnowledgeGraph
from .models import InferenceStep, KnowledgeEdge
from .ontology import TRANSITIVE_RELATIONS


def infer_transitive_edges(
    graph: KnowledgeGraph,
    source_id: str,
    max_depth: int = 3,
) -> tuple[KnowledgeEdge, ...]:
    inferred: dict[
        tuple[str, str, str],
        KnowledgeEdge,
    ] = {}

    grouped: dict[str, list[KnowledgeEdge]] = defaultdict(list)

    for edge in graph.outgoing(source_id, validated_only=True):
        if edge.relation_type in TRANSITIVE_RELATIONS:
            grouped[edge.relation_type].append(edge)

    for relation_type, first_edges in grouped.items():
        frontier = [
            (edge.target_id, 1, edge.weight)
            for edge in first_edges
        ]
        visited = {source_id}

        while frontier:
            current, depth, weight = frontier.pop(0)

            if current in visited:
                continue

            visited.add(current)

            if depth >= 2:
                inferred[
                    (source_id, current, relation_type)
                ] = KnowledgeEdge(
                    source_id=source_id,
                    target_id=current,
                    relation_type=relation_type,
                    weight=round(weight, 6),
                    validated=True,
                    cultural=False,
                    source_ref="SPT-007C-INFERENCE",
                    metadata={
                        "inferred": True,
                        "depth": depth,
                    },
                )

            if depth >= max_depth:
                continue

            for edge in graph.outgoing(
                current,
                validated_only=True,
            ):
                if edge.relation_type != relation_type:
                    continue

                frontier.append(
                    (
                        edge.target_id,
                        depth + 1,
                        weight * edge.weight,
                    )
                )

    return tuple(
        inferred[key]
        for key in sorted(inferred)
    )


def explain_inference(
    edges: tuple[KnowledgeEdge, ...],
) -> tuple[InferenceStep, ...]:
    return tuple(
        InferenceStep(
            source_id=edge.source_id,
            relation_type=edge.relation_type,
            target_id=edge.target_id,
            rule_code="SPT007C-RULE-TRANSITIVE",
            explanation=(
                f"{edge.source_id} se relaciona con "
                f"{edge.target_id} mediante transitividad "
                f"de {edge.relation_type}."
            ),
        )
        for edge in edges
    )
'@

$Navigation = @'
"""Navegación conceptual y recomendaciones."""

from __future__ import annotations

from .graph import KnowledgeGraph


def concept_path(
    graph: KnowledgeGraph,
    source_id: str,
    target_id: str,
    max_depth: int = 4,
) -> tuple[str, ...]:
    if source_id == target_id:
        return (source_id,)

    queue: list[tuple[str, tuple[str, ...]]] = [
        (source_id, (source_id,))
    ]
    visited = {source_id}

    while queue:
        current, path = queue.pop(0)

        if len(path) > max_depth + 1:
            continue

        for edge in graph.outgoing(
            current,
            validated_only=True,
        ):
            if edge.target_id == target_id:
                return (*path, target_id)

            if edge.target_id not in visited:
                visited.add(edge.target_id)
                queue.append(
                    (
                        edge.target_id,
                        (*path, edge.target_id),
                    )
                )

    return ()


def recommend_related(
    graph: KnowledgeGraph,
    node_id: str,
    limit: int = 10,
) -> tuple[str, ...]:
    scores: dict[str, float] = {}

    for edge in graph.outgoing(
        node_id,
        validated_only=True,
    ):
        scores[edge.target_id] = max(
            scores.get(edge.target_id, 0.0),
            edge.weight,
        )

    return tuple(
        item
        for item, _ in sorted(
            scores.items(),
            key=lambda pair: (-pair[1], pair[0]),
        )[: max(0, limit)]
    )
'@

$OdaBridge = @'
"""Integración gobernada con ODA y multimedia."""

from __future__ import annotations

from .graph import KnowledgeGraph


def learning_resources(
    graph: KnowledgeGraph,
    node_id: str,
) -> dict:
    media = []
    odas = []

    for edge in graph.outgoing(
        node_id,
        validated_only=True,
    ):
        target = graph.get_node(edge.target_id)

        if target is None:
            continue

        if edge.relation_type == "has_media":
            media.append(
                {
                    "node_id": target.node_id,
                    "label": target.label,
                    "source_ref": target.source_ref,
                    "metadata": target.metadata,
                }
            )

        if edge.relation_type == "has_oda":
            odas.append(
                {
                    "node_id": target.node_id,
                    "label": target.label,
                    "source_ref": target.source_ref,
                    "metadata": target.metadata,
                }
            )

    return {
        "node_id": node_id,
        "media": sorted(media, key=lambda item: item["node_id"]),
        "odas": sorted(odas, key=lambda item: item["node_id"]),
    }
'@

$Service = @'
"""Servicio principal del Motor de Conocimiento SPT-007C."""

from __future__ import annotations

from .graph import KnowledgeGraph
from .inference import explain_inference, infer_transitive_edges
from .models import KnowledgeResult
from .navigation import concept_path, recommend_related
from .oda_bridge import learning_resources


class KnowledgeEngineService:
    def __init__(self, graph: KnowledgeGraph) -> None:
        self.graph = graph

    def explore(
        self,
        node_id: str,
        depth: int = 2,
        include_inference: bool = True,
    ) -> KnowledgeResult:
        nodes, edges = self.graph.neighborhood(
            node_id,
            depth=depth,
            validated_only=True,
        )

        inferred = (
            infer_transitive_edges(
                self.graph,
                node_id,
                max_depth=max(2, depth + 1),
            )
            if include_inference
            else ()
        )

        known_ids = {item.node_id for item in nodes}

        inferred_targets = [
            self.graph.get_node(item.target_id)
            for item in inferred
            if item.target_id not in known_ids
        ]

        merged_nodes = {
            item.node_id: item
            for item in (
                *nodes,
                *(
                    item
                    for item in inferred_targets
                    if item is not None
                ),
            )
        }

        merged_edges = {
            (
                item.source_id,
                item.target_id,
                item.relation_type,
            ): item
            for item in (*edges, *inferred)
        }

        return KnowledgeResult(
            query_node_id=node_id,
            nodes=tuple(
                merged_nodes[key]
                for key in sorted(merged_nodes)
            ),
            edges=tuple(
                merged_edges[key]
                for key in sorted(merged_edges)
            ),
            inference_steps=explain_inference(inferred),
            no_invention=True,
        )

    def query(self, node_id: str) -> dict:
        result = self.explore(node_id)

        return {
            "query_node_id": result.query_node_id,
            "no_invention": result.no_invention,
            "nodes": [
                {
                    "node_id": item.node_id,
                    "node_type": item.node_type,
                    "label": item.label,
                    "language": item.language,
                    "validated": item.validated,
                    "cultural_status": item.cultural_status,
                    "source_ref": item.source_ref,
                    "metadata": item.metadata,
                }
                for item in result.nodes
            ],
            "edges": [
                {
                    "source_id": item.source_id,
                    "target_id": item.target_id,
                    "relation_type": item.relation_type,
                    "weight": item.weight,
                    "validated": item.validated,
                    "cultural": item.cultural,
                    "source_ref": item.source_ref,
                    "metadata": item.metadata,
                }
                for item in result.edges
            ],
            "inference": [
                {
                    "source_id": item.source_id,
                    "target_id": item.target_id,
                    "relation_type": item.relation_type,
                    "rule_code": item.rule_code,
                    "explanation": item.explanation,
                }
                for item in result.inference_steps
            ],
            "recommendations": list(
                recommend_related(self.graph, node_id)
            ),
            "learning_resources": learning_resources(
                self.graph,
                node_id,
            ),
        }

    def path(
        self,
        source_id: str,
        target_id: str,
    ) -> tuple[str, ...]:
        return concept_path(
            self.graph,
            source_id,
            target_id,
        )
'@

$Cli = @'
"""CLI de SPT-007C."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .graph import KnowledgeGraph
from .service import KnowledgeEngineService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph", required=True)
    parser.add_argument("--node", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()

    service = KnowledgeEngineService(
        KnowledgeGraph.from_json(args.graph)
    )
    payload = service.query(args.node)

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

$Init = @'
"""SPT-007C — Motor de Conocimiento Lingüístico y Cultural."""

from .graph import KnowledgeGraph
from .inference import explain_inference, infer_transitive_edges
from .models import (
    InferenceStep,
    KnowledgeEdge,
    KnowledgeNode,
    KnowledgeResult,
)
from .navigation import concept_path, recommend_related
from .oda_bridge import learning_resources
from .service import KnowledgeEngineService

__all__ = [
    "InferenceStep",
    "KnowledgeEdge",
    "KnowledgeEngineService",
    "KnowledgeGraph",
    "KnowledgeNode",
    "KnowledgeResult",
    "concept_path",
    "explain_inference",
    "infer_transitive_edges",
    "learning_resources",
    "recommend_related",
]
'@

$Tests = @'
import json
from pathlib import Path

import pytest

from sgoda.knowledge_engine import (
    KnowledgeEdge,
    KnowledgeEngineService,
    KnowledgeGraph,
    KnowledgeNode,
    concept_path,
    infer_transitive_edges,
    learning_resources,
    recommend_related,
)


def _graph() -> KnowledgeGraph:
    graph = KnowledgeGraph()

    for node in (
        KnowledgeNode(
            "LEX-001",
            "lexical_entry",
            "AMDA",
            language="pu",
            validated=True,
            source_ref="RLB:LEX-001",
        ),
        KnowledgeNode(
            "CON-001",
            "concept",
            "Casa",
            language="es",
            validated=True,
        ),
        KnowledgeNode(
            "CON-002",
            "concept",
            "Vivienda",
            language="es",
            validated=True,
        ),
        KnowledgeNode(
            "CAT-001",
            "category",
            "Construcciones",
            validated=True,
        ),
        KnowledgeNode(
            "ODA-001",
            "oda",
            "Aprender AMDA",
            validated=True,
            source_ref="ODA:ODA-001",
        ),
        KnowledgeNode(
            "MED-001",
            "media",
            "Imagen de casa",
            validated=True,
            source_ref="media/images/LEX-001.webp",
        ),
    ):
        graph.add_node(node)

    for edge in (
        KnowledgeEdge(
            "LEX-001",
            "CON-001",
            "related_to",
            validated=True,
        ),
        KnowledgeEdge(
            "CON-001",
            "CON-002",
            "is_a",
            validated=True,
        ),
        KnowledgeEdge(
            "CON-002",
            "CAT-001",
            "is_a",
            validated=True,
        ),
        KnowledgeEdge(
            "LEX-001",
            "ODA-001",
            "has_oda",
            validated=True,
        ),
        KnowledgeEdge(
            "LEX-001",
            "MED-001",
            "has_media",
            validated=True,
        ),
    ):
        graph.add_edge(edge)

    return graph


def test_SPT_007C_builds_knowledge_graph() -> None:
    graph = _graph()

    assert graph.get_node("LEX-001").label == "AMDA"
    assert len(graph.nodes()) == 6


def test_SPT_007C_rejects_unknown_node_type() -> None:
    graph = KnowledgeGraph()

    with pytest.raises(ValueError):
        graph.add_node(
            KnowledgeNode(
                "X",
                "unknown_type",
                "X",
            )
        )


def test_SPT_007C_rejects_unknown_relation() -> None:
    graph = KnowledgeGraph()
    graph.add_node(KnowledgeNode("A", "concept", "A"))
    graph.add_node(KnowledgeNode("B", "concept", "B"))

    with pytest.raises(ValueError):
        graph.add_edge(
            KnowledgeEdge(
                "A",
                "B",
                "invented_relation",
            )
        )


def test_SPT_007C_creates_symmetric_relation() -> None:
    graph = _graph()
    reverse = [
        item
        for item in graph.outgoing("CON-001")
        if item.target_id == "LEX-001"
    ]

    assert reverse
    assert reverse[0].metadata["generated_reverse"] is True


def test_SPT_007C_neighborhood_is_deterministic() -> None:
    graph = _graph()

    first = graph.neighborhood("LEX-001", depth=2)
    second = graph.neighborhood("LEX-001", depth=2)

    assert first == second


def test_SPT_007C_infers_transitive_relation() -> None:
    inferred = infer_transitive_edges(
        _graph(),
        "CON-001",
        max_depth=3,
    )

    targets = {
        item.target_id
        for item in inferred
        if item.relation_type == "is_a"
    }

    assert "CAT-001" in targets


def test_SPT_007C_inference_is_explainable() -> None:
    result = KnowledgeEngineService(_graph()).explore(
        "CON-001",
        depth=2,
        include_inference=True,
    )

    assert result.inference_steps
    assert result.inference_steps[0].rule_code


def test_SPT_007C_finds_concept_path() -> None:
    path = concept_path(
        _graph(),
        "CON-001",
        "CAT-001",
    )

    assert path == (
        "CON-001",
        "CON-002",
        "CAT-001",
    )


def test_SPT_007C_recommends_related_nodes() -> None:
    recommendations = recommend_related(
        _graph(),
        "LEX-001",
    )

    assert "CON-001" in recommendations
    assert "ODA-001" in recommendations


def test_SPT_007C_integrates_oda_and_media() -> None:
    resources = learning_resources(
        _graph(),
        "LEX-001",
    )

    assert resources["odas"][0]["node_id"] == "ODA-001"
    assert resources["media"][0]["node_id"] == "MED-001"


def test_SPT_007C_no_invention_contract() -> None:
    payload = KnowledgeEngineService(_graph()).query(
        "LEX-001"
    )

    assert payload["no_invention"] is True
    assert all(
        _graph().get_node(item["node_id"]) is not None
        for item in payload["nodes"]
    )


def test_SPT_007C_uses_validated_edges_only() -> None:
    graph = _graph()
    graph.add_node(
        KnowledgeNode(
            "CON-999",
            "concept",
            "No validado",
            validated=False,
        )
    )
    graph.add_edge(
        KnowledgeEdge(
            "LEX-001",
            "CON-999",
            "related_to",
            validated=False,
        )
    )

    nodes, _ = graph.neighborhood(
        "LEX-001",
        depth=1,
        validated_only=True,
    )

    assert "CON-999" not in {
        item.node_id for item in nodes
    }


def test_SPT_007C_reads_json_graph(tmp_path: Path) -> None:
    path = tmp_path / "graph.json"
    path.write_text(
        json.dumps(
            {
                "nodes": [
                    {
                        "node_id": "A",
                        "node_type": "concept",
                        "label": "A",
                        "validated": True,
                    },
                    {
                        "node_id": "B",
                        "node_type": "concept",
                        "label": "B",
                        "validated": True,
                    },
                ],
                "edges": [
                    {
                        "source_id": "A",
                        "target_id": "B",
                        "relation_type": "related_to",
                        "validated": True,
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    graph = KnowledgeGraph.from_json(path)

    assert graph.get_node("A").label == "A"
    assert graph.outgoing("A")[0].target_id == "B"


def test_SPT_007C_service_serializes_query() -> None:
    payload = KnowledgeEngineService(_graph()).query(
        "LEX-001"
    )

    assert payload["query_node_id"] == "LEX-001"
    assert payload["learning_resources"]["odas"]
    assert payload["recommendations"]
'@

$Policy = @'
{
  "component": "SPT-007C",
  "version": "1.0.0",
  "name": "Motor de Conocimiento Lingüístico y Cultural",
  "local_first": true,
  "paid_services_required": false,
  "generative_models_required": false,
  "no_invention": true,
  "validated_edges_only": true,
  "cultural_validation_required": true,
  "inference": {
    "enabled": true,
    "explainable": true,
    "maximum_depth": 3,
    "allowed_rules": [
      "SPT007C-RULE-TRANSITIVE"
    ]
  },
  "integrations": [
    "SPT-002",
    "SPT-006",
    "SPT-007A",
    "SPT-007B",
    "SPT-004A"
  ]
}
'@

$OntologyConfig = @'
{
  "node_types": [
    "lexical_entry",
    "concept",
    "cultural_practice",
    "place",
    "person",
    "animal",
    "plant",
    "object",
    "story",
    "media",
    "oda",
    "category"
  ],
  "relation_types": [
    "is_a",
    "part_of",
    "related_to",
    "synonym_of",
    "variant_of",
    "family_of",
    "used_in",
    "located_in",
    "appears_in",
    "has_media",
    "has_oda",
    "teaches",
    "broader_than",
    "narrower_than",
    "cultural_relation"
  ]
}
'@

$Component = @'
{
  "increment_code": "SPT-007C",
  "name": "Motor de Conocimiento Lingüístico y Cultural",
  "component_type": "linguistic_cultural_knowledge_engine",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica",
  "dependencies": [
    "SPT-007A",
    "SPT-007B",
    "SPT-006",
    "SPT-004A",
    "SPT-002",
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/knowledge_engine/models.py",
    "src/sgoda/knowledge_engine/ontology.py",
    "src/sgoda/knowledge_engine/graph.py",
    "src/sgoda/knowledge_engine/inference.py",
    "src/sgoda/knowledge_engine/navigation.py",
    "src/sgoda/knowledge_engine/oda_bridge.py",
    "src/sgoda/knowledge_engine/service.py",
    "src/sgoda/knowledge_engine/cli.py"
  ],
  "tests": [
    "tests/knowledge_engine/test_SPT_007C_knowledge_engine.py"
  ],
  "documentation": [
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007C-Motor-Conocimiento-Linguistico-Cultural.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007C-Arquitectura-Grafo-Conocimiento.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007C-Ontologia-Linguistica-Cultural.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007C-Inferencia-Controlada-Explicable.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007C-Integracion-ODA-Multimedia.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007C-Pruebas-Criterios-Aceptacion.md",
    "docs/05_Fase_Tecnologica/SPT-007/SPT-007C-Operacion-Mantenimiento.md"
  ]
}
'@

$Doc = @'
# SPT-007C — Motor de Conocimiento Lingüístico y Cultural

SPT-007C transforma el motor semántico en una red de conocimiento
lingüístico, cultural, multimedia y educativo.

El componente opera localmente, no usa servicios de pago y no inventa
conocimiento Puinave.
'@

$Architecture = @'
# Arquitectura del Grafo de Conocimiento SPT-007C

La arquitectura contiene:

1. nodos de conocimiento;
2. relaciones tipadas;
3. ontología institucional;
4. grafo local;
5. inferencia explicable;
6. navegación conceptual;
7. integración con ODA;
8. integración con multimedia;
9. servicio y CLI.

Toda relación utilizada por defecto debe estar validada.
'@

$OntologyDoc = @'
# Ontología Lingüística y Cultural SPT-007C

La ontología define tipos de nodos y relaciones permitidas.

No se aceptan tipos desconocidos, relaciones inventadas ni relaciones
autorreferenciales.

Los conceptos culturales deben mantener estado de validación y referencia
de origen.
'@

$InferenceDoc = @'
# Inferencia Controlada y Explicable SPT-007C

La versión 1.0.0 permite únicamente inferencia transitiva sobre relaciones
autorizadas.

Cada inferencia debe registrar:

- regla utilizada;
- nodo origen;
- relación;
- nodo destino;
- explicación;
- profundidad;
- referencia institucional.

No se utiliza IA generativa para crear conocimiento.
'@

$OdaDoc = @'
# Integración ODA y Multimedia SPT-007C

Los nodos léxicos y conceptuales pueden asociarse con:

- Objetos Digitales de Aprendizaje;
- audios;
- imágenes;
- videos;
- ejercicios;
- narraciones.

Las relaciones `has_oda` y `has_media` solo exponen recursos existentes y
validados.
'@

$AcceptanceDoc = @'
# Pruebas y Criterios de Aceptación SPT-007C

El incremento solo se acepta cuando:

- las pruebas específicas aprueban;
- la suite completa aprueba;
- SGD-114C aprueba;
- SGD-115 se actualiza;
- SGD-116 se actualiza sin dependencias faltantes;
- el release existe;
- la documentación queda en el repositorio;
- Git queda limpio después de SPB-007.
'@

$OperationDoc = @'
# Operación y Mantenimiento SPT-007C

La operación se realiza mediante:

`scripts/Invoke-SPT007C-KnowledgeEngine.ps1`

Las nuevas relaciones deben agregarse con validación, trazabilidad y
referencia de origen. Los cambios en la ontología requieren un nuevo
incremento institucional.
'@

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Graph,

    [Parameter(Mandatory = $true)]
    [string]$Node,

    [string]$Output = "artifacts/knowledge_engine/SPT-007C/query-result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.knowledge_engine.cli `
    --graph $Graph `
    --node $Node `
    --output $Output

exit $LASTEXITCODE
'@

Write-Step "Instalando SPT-007C"

Write-Utf8 $ModelsPath $Models
Write-Utf8 $OntologyPath $Ontology
Write-Utf8 $GraphPath $Graph
Write-Utf8 $InferencePath $Inference
Write-Utf8 $NavigationPath $Navigation
Write-Utf8 $OdaBridgePath $OdaBridge
Write-Utf8 $ServicePath $Service
Write-Utf8 $CliPath $Cli
Write-Utf8 $InitPath $Init
Write-Utf8 $TestPath $Tests
Write-Utf8 $PolicyPath $Policy
Write-Utf8 $OntologyConfigPath $OntologyConfig
Write-Utf8 $ComponentPath $Component
Write-Utf8 $DocPath $Doc
Write-Utf8 $ArchitecturePath $Architecture
Write-Utf8 $OntologyDocPath $OntologyDoc
Write-Utf8 $InferenceDocPath $InferenceDoc
Write-Utf8 $OdaDocPath $OdaDoc
Write-Utf8 $AcceptanceDocPath $AcceptanceDoc
Write-Utf8 $OperationDocPath $OperationDoc
Write-Utf8 $InvokePath $Invoke

Invoke-Checked "Validando sintaxis" {
    python -m py_compile `
        "src/sgoda/knowledge_engine/models.py" `
        "src/sgoda/knowledge_engine/ontology.py" `
        "src/sgoda/knowledge_engine/graph.py" `
        "src/sgoda/knowledge_engine/inference.py" `
        "src/sgoda/knowledge_engine/navigation.py" `
        "src/sgoda/knowledge_engine/oda_bridge.py" `
        "src/sgoda/knowledge_engine/service.py" `
        "src/sgoda/knowledge_engine/cli.py" `
        "src/sgoda/knowledge_engine/__init__.py" `
        "tests/knowledge_engine/test_SPT_007C_knowledge_engine.py"
}

Invoke-Checked "Ejecutando 14 pruebas específicas SPT-007C" {
    python -m pytest `
        "tests/knowledge_engine/test_SPT_007C_knowledge_engine.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Ejecutando demostración de conocimiento"

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
            language = "es"
            validated = $true
        },
        [ordered]@{
            node_id = "CON-002"
            node_type = "concept"
            label = "Vivienda"
            language = "es"
            validated = $true
        },
        [ordered]@{
            node_id = "CAT-001"
            node_type = "category"
            label = "Construcciones"
            validated = $true
        },
        [ordered]@{
            node_id = "ODA-001"
            node_type = "oda"
            label = "Aprender AMDA"
            validated = $true
            source_ref = "ODA:ODA-001"
        }
    )
    edges = @(
        [ordered]@{
            source_id = "LEX-001"
            target_id = "CON-001"
            relation_type = "related_to"
            validated = $true
            weight = 1.0
        },
        [ordered]@{
            source_id = "CON-001"
            target_id = "CON-002"
            relation_type = "is_a"
            validated = $true
            weight = 1.0
        },
        [ordered]@{
            source_id = "CON-002"
            target_id = "CAT-001"
            relation_type = "is_a"
            validated = $true
            weight = 1.0
        },
        [ordered]@{
            source_id = "LEX-001"
            target_id = "ODA-001"
            relation_type = "has_oda"
            validated = $true
            weight = 1.0
        }
    )
})

Invoke-Checked "Consultando objeto de conocimiento AMDA" {
    python -m sgoda.knowledge_engine.cli `
        --graph "$DemoGraphPath" `
        --node "LEX-001" `
        --output "$DemoResultPath"
}

$Demo = Get-Content `
    -LiteralPath $DemoResultPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not $Demo.no_invention) {
    throw "La demostración no respetó el contrato de no invención."
}

if (@($Demo.nodes).Count -lt 3) {
    throw "La demostración no recuperó el conocimiento esperado."
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
    throw "SGD-116 no aprobó la incorporación de SPT-007C."
}

Write-Step "Preparando evidencia previa y release"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json (Join-Path $PmoDir "SPT-007C-pre-gate-evidence.json") ([ordered]@{
    increment_code = "SPT-007C"
    version = "1.0.0"
    status = "technically_completed"
    phase = "Fase Tecnológica"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    specific_tests = 14
    full_suite_executed = (-not $SkipFullSuite)
    knowledge_demo_nodes = @($Demo.nodes).Count
    roadmap_approved = [bool]$RoadmapValidation.passed
})

Copy-Item `
    -LiteralPath $ComponentPath `
    -Destination (Join-Path $ReleaseDir "SPT-007C-component.json") `
    -Force

Write-Step "Evaluando SPT-007C mediante SGD-114C"

& python -m sgoda.governance.policy_cli `
    --root "$ProjectRoot" `
    --policy "config/governance/SGD-114C-policy.json" `
    --increment "SPT-007C" `
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

    throw "SGD-114C no aprobó SPT-007C."
}

Write-Step "Actualizando documentación maestra SGD-115"

Invoke-Checked "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Write-Step "Generando evidencia y release"

Write-Json $EvidencePath ([ordered]@{
    increment_code = "SPT-007C"
    version = "1.0.0"
    status = "implemented"
    phase = "Fase Tecnológica"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    capabilities = @(
        "knowledge_graph",
        "controlled_ontology",
        "validated_relations",
        "explainable_inference",
        "concept_navigation",
        "knowledge_recommendations",
        "oda_integration",
        "multimedia_integration",
        "no_invention"
    )
    specific_tests = 14
    full_suite_executed = (-not $SkipFullSuite)
    policy_approved = [bool]$Gate.approved
    policy_exit_code = $Gate.exit_code
    roadmap_approved = [bool]$RoadmapValidation.passed
    demo = $DemoResultPath
    backup = $BackupDir
})

foreach ($Path in @(
    $ModelsPath,
    $OntologyPath,
    $GraphPath,
    $InferencePath,
    $NavigationPath,
    $OdaBridgePath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $PolicyPath,
    $OntologyConfigPath,
    $ComponentPath,
    $DocPath,
    $ArchitecturePath,
    $OntologyDocPath,
    $InferenceDocPath,
    $OdaDocPath,
    $AcceptanceDocPath,
    $OperationDocPath,
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

Write-Host "SPT-007C v1.0.0 implementado." -ForegroundColor Green
Write-Host "Fase Tecnológica: ACTUALIZADA." -ForegroundColor Green
Write-Host "Motor de Conocimiento: OPERATIVO." -ForegroundColor Green
Write-Host "Pruebas específicas: 14 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Grafo de conocimiento: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Ontología controlada: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Inferencia explicable: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Navegación conceptual: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Integración ODA y multimedia: IMPLEMENTADA." -ForegroundColor Green
Write-Host "No invención Puinave: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Servicios de pago: NO REQUERIDOS." -ForegroundColor Green
Write-Host "SGD-114C: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO Y APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-007C-v1.0.0" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan

Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
