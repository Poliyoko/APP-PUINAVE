<#
.SYNOPSIS
    Implementa SPT-019.1 v1.0.0 — Workflow Engine Core.

.DESCRIPTION
    Crea el núcleo Python del motor de workflows, su registro,
    validador, simulador básico, workflows de referencia,
    pruebas, documentación y evidencias.

    Este archivo NO instala ni inicia n8n.
    Este archivo NO publica en GitHub.
    Este archivo NO requiere servicios de pago.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Utf8 {
    param(
        [string]$Path,
        [string]$Content
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item `
            -ItemType Directory `
            -Path $Parent `
            -Force |
            Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se pudo escribir: $Path"
    }
}

function Invoke-Checked {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

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

if (-not (Test-Path -LiteralPath $env:PYTHONPATH -PathType Container)) {
    throw "No existe la carpeta src del proyecto: $env:PYTHONPATH"
}

$SourceDir = Join-Path `
    $ProjectRoot `
    "src\sgoda\automation\workflow_engine"

$TestsDir = Join-Path `
    $ProjectRoot `
    "tests\automation\workflow_engine"

$WorkflowRoot = Join-Path `
    $ProjectRoot `
    "automation\n8n\workflows"

$ConfigDir = Join-Path `
    $ProjectRoot `
    "config\automation"

$DocsDir = Join-Path `
    $ProjectRoot `
    "docs\08_Fase_Tecnologica_IV\SPT-019\SPT-019.1"

$ArtifactDir = Join-Path `
    $ProjectRoot `
    "artifacts\technology\SPT-019.1-v1.0.0"

foreach ($Directory in @(
    $SourceDir,
    $TestsDir,
    $WorkflowRoot,
    $ConfigDir,
    $DocsDir,
    $ArtifactDir
)) {
    New-Item `
        -ItemType Directory `
        -Path $Directory `
        -Force |
        Out-Null
}

$Module = @'

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


SUPPORTED_TRIGGER_TYPES = {
    "n8n-nodes-base.webhook",
    "n8n-nodes-base.scheduleTrigger",
    "n8n-nodes-base.manualTrigger",
}


@dataclass(frozen=True, slots=True)
class WorkflowRecord:
    workflow_id: str
    name: str
    version: str
    status: str
    category: str
    file: str
    trigger_types: tuple[str, ...]
    dependencies: tuple[str, ...]
    sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "workflow_id": self.workflow_id,
            "name": self.name,
            "version": self.version,
            "status": self.status,
            "category": self.category,
            "file": self.file,
            "trigger_types": list(self.trigger_types),
            "dependencies": list(self.dependencies),
            "sha256": self.sha256,
        }


@dataclass(frozen=True, slots=True)
class ValidationResult:
    approved: bool
    errors: tuple[str, ...]
    warnings: tuple[str, ...]
    record: WorkflowRecord | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "approved": self.approved,
            "errors": list(self.errors),
            "warnings": list(self.warnings),
            "record": None if self.record is None else self.record.to_dict(),
        }


def canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def sha256_payload(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def load_workflow(path_value: str | Path) -> dict[str, Any]:
    path = Path(path_value)
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict):
        raise ValueError("La raíz del workflow debe ser un objeto JSON.")
    return payload


def _metadata(payload: dict[str, Any]) -> dict[str, Any]:
    meta = payload.get("meta", {})
    return meta if isinstance(meta, dict) else {}


def validate_workflow(
    path_value: str | Path,
    *,
    relative_to: str | Path | None = None,
) -> ValidationResult:
    path = Path(path_value)
    errors: list[str] = []
    warnings: list[str] = []

    try:
        payload = load_workflow(path)
    except Exception as exc:
        return ValidationResult(
            approved=False,
            errors=(f"JSON inválido: {exc}",),
            warnings=(),
            record=None,
        )

    name = str(payload.get("name", "")).strip()
    if not name:
        errors.append("Falta name.")
    elif not name.startswith("SPT-019"):
        errors.append("El nombre debe iniciar con SPT-019.")

    meta = _metadata(payload)
    workflow_id = str(meta.get("workflow_id", "")).strip()
    version = str(meta.get("version", "")).strip()
    category = str(meta.get("category", "")).strip()
    status = str(meta.get("status", "draft")).strip()
    dependencies_raw = meta.get("dependencies", [])

    if not workflow_id:
        errors.append("Falta meta.workflow_id.")
    elif not workflow_id.startswith("SPT-019-WF-"):
        errors.append("workflow_id no cumple la nomenclatura SPT-019-WF-*.")

    if not version:
        errors.append("Falta meta.version.")

    if category not in {
        "governance",
        "pmo",
        "learning",
        "analytics",
        "multimedia",
        "ai",
        "repository",
    }:
        errors.append("meta.category no pertenece al catálogo institucional.")

    if status not in {"draft", "validated", "released", "retired"}:
        errors.append("meta.status inválido.")

    if not isinstance(dependencies_raw, list):
        errors.append("meta.dependencies debe ser una lista.")
        dependencies: tuple[str, ...] = ()
    else:
        dependencies = tuple(
            sorted(
                {
                    str(item).strip()
                    for item in dependencies_raw
                    if str(item).strip()
                }
            )
        )

    nodes = payload.get("nodes", [])
    if not isinstance(nodes, list) or not nodes:
        errors.append("nodes debe contener al menos un nodo.")
        nodes = []

    connections = payload.get("connections")
    if not isinstance(connections, dict):
        errors.append("connections debe ser un objeto.")

    node_ids: set[str] = set()
    node_names: set[str] = set()
    trigger_types: list[str] = []

    for index, node in enumerate(nodes):
        if not isinstance(node, dict):
            errors.append(f"Nodo {index} inválido.")
            continue

        node_id = str(node.get("id", "")).strip()
        node_name = str(node.get("name", "")).strip()
        node_type = str(node.get("type", "")).strip()

        if not node_id:
            errors.append(f"Nodo {index} sin id.")
        elif node_id in node_ids:
            errors.append(f"id de nodo duplicado: {node_id}")
        node_ids.add(node_id)

        if not node_name:
            errors.append(f"Nodo {index} sin name.")
        elif node_name in node_names:
            errors.append(f"name de nodo duplicado: {node_name}")
        node_names.add(node_name)

        if not node_type:
            errors.append(f"Nodo {index} sin type.")
        elif node_type in SUPPORTED_TRIGGER_TYPES:
            trigger_types.append(node_type)

    if not trigger_types:
        errors.append("El workflow no contiene un trigger institucional soportado.")

    if payload.get("active", False):
        warnings.append("El workflow está activo; los artefactos de repositorio deben entregarse inactivos.")

    if relative_to is None:
        relative_file = path.as_posix()
    else:
        relative_file = path.resolve().relative_to(Path(relative_to).resolve()).as_posix()

    record = None
    if not errors:
        record = WorkflowRecord(
            workflow_id=workflow_id,
            name=name,
            version=version,
            status=status,
            category=category,
            file=relative_file,
            trigger_types=tuple(sorted(set(trigger_types))),
            dependencies=dependencies,
            sha256=sha256_payload(payload),
        )

    return ValidationResult(
        approved=not errors,
        errors=tuple(errors),
        warnings=tuple(warnings),
        record=record,
    )


def build_registry(
    workflow_paths: Iterable[str | Path],
    *,
    relative_to: str | Path,
) -> dict[str, Any]:
    results = [
        validate_workflow(path, relative_to=relative_to)
        for path in workflow_paths
    ]

    records = [
        result.record
        for result in results
        if result.record is not None
    ]

    ids = [record.workflow_id for record in records]
    names = [record.name for record in records]
    duplicate_ids = sorted({item for item in ids if ids.count(item) > 1})
    duplicate_names = sorted({item for item in names if names.count(item) > 1})

    errors: list[str] = []
    if duplicate_ids:
        errors.append("workflow_id duplicados: " + ", ".join(duplicate_ids))
    if duplicate_names:
        errors.append("nombres duplicados: " + ", ".join(duplicate_names))

    for result in results:
        errors.extend(result.errors)

    registry = {
        "component": "SPT-019",
        "layer": "A",
        "version": "0.1.0",
        "workflow_count": len(records),
        "workflows": [
            record.to_dict()
            for record in sorted(records, key=lambda item: item.workflow_id)
        ],
        "errors": errors,
        "approved": not errors,
    }
    registry["sha256"] = sha256_payload(
        {
            "component": registry["component"],
            "layer": registry["layer"],
            "version": registry["version"],
            "workflows": registry["workflows"],
        }
    )
    return registry


def simulate_workflow(
    path_value: str | Path,
    event: dict[str, Any],
) -> dict[str, Any]:
    validation = validate_workflow(path_value)
    if not validation.approved or validation.record is None:
        raise ValueError("No se puede simular un workflow inválido.")

    if not isinstance(event, dict):
        raise TypeError("El evento debe ser un objeto.")

    return {
        "workflow_id": validation.record.workflow_id,
        "workflow_version": validation.record.version,
        "simulation": True,
        "executed": False,
        "event": event,
        "trigger_types": list(validation.record.trigger_types),
        "result": "accepted_for_simulation",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("workflow")

    registry_parser = subparsers.add_parser("registry")
    registry_parser.add_argument("--workflows-dir", required=True)
    registry_parser.add_argument("--output", required=True)

    simulate_parser = subparsers.add_parser("simulate")
    simulate_parser.add_argument("workflow")
    simulate_parser.add_argument("--event-json", required=True)

    args = parser.parse_args()

    if args.command == "validate":
        result = validate_workflow(args.workflow)
        print(json.dumps(result.to_dict(), ensure_ascii=False))
        return 0 if result.approved else 2

    if args.command == "registry":
        workflows_dir = Path(args.workflows_dir)
        registry = build_registry(
            sorted(workflows_dir.rglob("*.json")),
            relative_to=workflows_dir.parent,
        )
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(
            json.dumps(registry, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(registry, ensure_ascii=False))
        return 0 if registry["approved"] else 2

    event = json.loads(args.event_json)
    result = simulate_workflow(args.workflow, event)
    print(json.dumps(result, ensure_ascii=False))
    return 0

'@

$MainPy = @'
from . import main
raise SystemExit(main())

'@

$Tests = @'

from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.automation.workflow_engine import (
    build_registry,
    canonical_json,
    load_workflow,
    sha256_payload,
    simulate_workflow,
    validate_workflow,
)


def workflow(
    *,
    workflow_id: str = "SPT-019-WF-001",
    name: str = "SPT-019 — Workflow de prueba",
    category: str = "governance",
    status: str = "draft",
    active: bool = False,
) -> dict:
    return {
        "name": name,
        "nodes": [
            {
                "id": "trigger-1",
                "name": "Webhook",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 2,
                "position": [0, 0],
                "parameters": {
                    "httpMethod": "POST",
                    "path": "test",
                },
            },
            {
                "id": "set-1",
                "name": "Normalizar",
                "type": "n8n-nodes-base.set",
                "typeVersion": 3,
                "position": [240, 0],
                "parameters": {},
            },
        ],
        "connections": {
            "Webhook": {
                "main": [[{"node": "Normalizar", "type": "main", "index": 0}]]
            }
        },
        "active": active,
        "settings": {"executionOrder": "v1"},
        "meta": {
            "workflow_id": workflow_id,
            "version": "0.1.0",
            "status": status,
            "category": category,
            "dependencies": ["POL-001"],
        },
    }


def write(path: Path, payload: dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return path


def test_load_workflow(tmp_path: Path) -> None:
    path = write(tmp_path / "workflow.json", workflow())
    assert load_workflow(path)["name"].startswith("SPT-019")


def test_valid_workflow_is_approved(tmp_path: Path) -> None:
    result = validate_workflow(write(tmp_path / "workflow.json", workflow()))
    assert result.approved
    assert result.record is not None


def test_invalid_json_is_rejected(tmp_path: Path) -> None:
    path = tmp_path / "workflow.json"
    path.write_text("{", encoding="utf-8")
    assert not validate_workflow(path).approved


def test_missing_trigger_is_rejected(tmp_path: Path) -> None:
    payload = workflow()
    payload["nodes"][0]["type"] = "n8n-nodes-base.set"
    assert not validate_workflow(write(tmp_path / "workflow.json", payload)).approved


def test_duplicate_node_id_is_rejected(tmp_path: Path) -> None:
    payload = workflow()
    payload["nodes"][1]["id"] = "trigger-1"
    assert not validate_workflow(write(tmp_path / "workflow.json", payload)).approved


def test_invalid_category_is_rejected(tmp_path: Path) -> None:
    payload = workflow(category="unknown")
    assert not validate_workflow(write(tmp_path / "workflow.json", payload)).approved


def test_active_workflow_generates_warning(tmp_path: Path) -> None:
    result = validate_workflow(
        write(tmp_path / "workflow.json", workflow(active=True))
    )
    assert result.approved
    assert result.warnings


def test_hash_is_deterministic() -> None:
    assert sha256_payload({"b": 2, "a": 1}) == sha256_payload({"a": 1, "b": 2})
    assert canonical_json({"b": 2, "a": 1}) == canonical_json({"a": 1, "b": 2})


def test_registry_is_sorted_and_approved(tmp_path: Path) -> None:
    workflows_dir = tmp_path / "workflows"
    first = write(
        workflows_dir / "b.json",
        workflow(workflow_id="SPT-019-WF-002", name="SPT-019 — B"),
    )
    second = write(
        workflows_dir / "a.json",
        workflow(workflow_id="SPT-019-WF-001", name="SPT-019 — A"),
    )
    registry = build_registry([first, second], relative_to=tmp_path)
    assert registry["approved"]
    assert [item["workflow_id"] for item in registry["workflows"]] == [
        "SPT-019-WF-001",
        "SPT-019-WF-002",
    ]


def test_registry_rejects_duplicate_ids(tmp_path: Path) -> None:
    workflows_dir = tmp_path / "workflows"
    first = write(workflows_dir / "a.json", workflow(name="SPT-019 — A"))
    second = write(workflows_dir / "b.json", workflow(name="SPT-019 — B"))
    registry = build_registry([first, second], relative_to=tmp_path)
    assert not registry["approved"]


def test_simulator_does_not_execute_external_actions(tmp_path: Path) -> None:
    path = write(tmp_path / "workflow.json", workflow())
    result = simulate_workflow(path, {"event": "test"})
    assert result["simulation"] is True
    assert result["executed"] is False


def test_simulator_rejects_invalid_workflow(tmp_path: Path) -> None:
    path = write(tmp_path / "workflow.json", workflow(category="invalid"))
    with pytest.raises(ValueError):
        simulate_workflow(path, {"event": "test"})

'@

$Component = @'
{
  "increment_code": "SPT-019.1",
  "layer": "A",
  "version": "1.0.0",
  "name": "Workflow Engine Core",
  "status": "implemented_tested_and_candidate_for_integration",
  "scope": [
    "Workflow Engine Core",
    "Workflow Registry",
    "Workflow Validator",
    "Workflow Simulator básico"
  ],
  "dependencies": [
    "POL-001-v1.0.2"
  ],
  "paid_services_required": false,
  "internet_required_for_tests": false
}
'@

$Policy = @'
{
  "policy_id": "SPT-019.1-POLICY-v1.0.0",
  "workflow_names_must_start_with": "SPT-019",
  "workflow_id_pattern": "SPT-019-WF-*",
  "allowed_categories": [
    "governance",
    "pmo",
    "learning",
    "analytics",
    "multimedia",
    "ai",
    "repository"
  ],
  "repository_workflows_must_be_inactive": true,
  "simulation_must_not_execute_external_actions": true,
  "component": "SPT-019.1",
  "version": "1.0.0"
}
'@

$Architecture = @'
# SPT-019 — Capa A: Arquitectura del núcleo

La Capa A introduce un núcleo independiente de la instancia n8n. Su función es
validar, registrar, versionar y simular workflows antes de importarlos o
activarlos en n8n Community Edition.

## Principios

- Los workflows del repositorio permanecen inactivos.
- La validación no necesita Internet.
- La simulación no ejecuta acciones externas.
- El registro se genera de manera determinística.
- Todo workflow tiene identificador, versión, categoría y dependencias.

'@

$Manual = @'
# SPT-019 — Capa A: Manual de validación

Desde la raíz del repositorio:

```powershell
$env:PYTHONPATH = Join-Path (Get-Location) "src"
python -m pytest tests/automation/workflow_engine -q
python -m sgoda.automation.workflow_engine registry `
  --workflows-dir automation/n8n/workflows `
  --output artifacts/technology/SPT-019-Layer-A-v0.1.0/workflow-registry.json
```

Esta capa no instala ni inicia n8n.

'@

$WorkflowOne = @'
{
  "name": "SPT-019 — Policy Audit Request",
  "nodes": [
    {
      "id": "trigger-policy-audit",
      "name": "Webhook POL-001",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [
        0,
        0
      ],
      "parameters": {
        "httpMethod": "POST",
        "path": "sgoda/policy-audit",
        "responseMode": "onReceived"
      }
    },
    {
      "id": "normalize-policy-audit",
      "name": "Normalizar solicitud",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3,
      "position": [
        240,
        0
      ],
      "parameters": {}
    }
  ],
  "connections": {
    "Webhook POL-001": {
      "main": [
        [
          {
            "node": "Normalizar solicitud",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "active": false,
  "settings": {
    "executionOrder": "v1"
  },
  "meta": {
    "workflow_id": "SPT-019-WF-001",
    "version": "0.1.0",
    "status": "validated",
    "category": "governance",
    "dependencies": [
      "POL-001",
      "SGD-117"
    ]
  }
}

'@

$WorkflowTwo = @'
{
  "name": "SPT-019 — PMO Event Gateway",
  "nodes": [
    {
      "id": "trigger-pmo-event",
      "name": "Webhook PMO",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [
        0,
        0
      ],
      "parameters": {
        "httpMethod": "POST",
        "path": "sgoda/pmo-event",
        "responseMode": "onReceived"
      }
    },
    {
      "id": "normalize-pmo-event",
      "name": "Normalizar evento PMO",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3,
      "position": [
        240,
        0
      ],
      "parameters": {}
    }
  ],
  "connections": {
    "Webhook PMO": {
      "main": [
        [
          {
            "node": "Normalizar evento PMO",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "active": false,
  "settings": {
    "executionOrder": "v1"
  },
  "meta": {
    "workflow_id": "SPT-019-WF-002",
    "version": "0.1.0",
    "status": "validated",
    "category": "pmo",
    "dependencies": [
      "PMO-DIGITAL",
      "SGD-117"
    ]
  }
}

'@

Step "Instalando código fuente SPT-019.1"

Write-Utf8 `
    (Join-Path $SourceDir "__init__.py") `
    $Module

Write-Utf8 `
    (Join-Path $SourceDir "__main__.py") `
    $MainPy

Write-Utf8 `
    (Join-Path $TestsDir "test_SPT_019_1_workflow_engine_core.py") `
    $Tests

Write-Utf8 `
    (Join-Path $ConfigDir "SPT-019.1-component.json") `
    $Component

Write-Utf8 `
    (Join-Path $ConfigDir "SPT-019.1-policy.json") `
    $Policy

Write-Utf8 `
    (Join-Path $DocsDir "SPT-019.1-Arquitectura.md") `
    $Architecture

Write-Utf8 `
    (Join-Path $DocsDir "SPT-019.1-Manual-Validacion.md") `
    $Manual

Write-Utf8 `
    (Join-Path `
        $WorkflowRoot `
        "governance\SPT-019-WF-001-Policy-Audit-Request.json") `
    $WorkflowOne

Write-Utf8 `
    (Join-Path `
        $WorkflowRoot `
        "pmo\SPT-019-WF-002-PMO-Event-Gateway.json") `
    $WorkflowTwo

Invoke-Checked "Validando sintaxis Python SPT-019.1" {
    python -m py_compile `
        "src\sgoda\automation\workflow_engine\__init__.py" `
        "src\sgoda\automation\workflow_engine\__main__.py" `
        "tests\automation\workflow_engine\test_SPT_019_1_workflow_engine_core.py"
}

$JUnitPath = Join-Path `
    $ArtifactDir `
    "unit-tests.xml"

Invoke-Checked "Ejecutando pruebas SPT-019.1" {
    python -m pytest `
        "tests\automation\workflow_engine\test_SPT_019_1_workflow_engine_core.py" `
        -q `
        "--junitxml=$JUnitPath"
}

$RegistryPath = Join-Path `
    $ArtifactDir `
    "workflow-registry.json"

Invoke-Checked "Generando registro institucional de workflows" {
    python -m sgoda.automation.workflow_engine registry `
        --workflows-dir "automation\n8n\workflows" `
        --output "$RegistryPath"
}

$Registry = Get-Content `
    -LiteralPath $RegistryPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Registry.approved) {
    throw "El registro institucional de workflows no fue aprobado."
}

$SimulationPath = Join-Path `
    $ArtifactDir `
    "simulation-result.json"

$SimulationOutput = python -m sgoda.automation.workflow_engine simulate `
    "automation\n8n\workflows\governance\SPT-019-WF-001-Policy-Audit-Request.json" `
    --event-json '{"event":"policy.audit.requested","component":"POL-001"}'

if ($LASTEXITCODE -ne 0) {
    throw "Falló la simulación controlada SPT-019.1."
}

Write-Utf8 `
    $SimulationPath `
    (
        $SimulationOutput +
        [Environment]::NewLine
    )

$Simulation = Get-Content `
    -LiteralPath $SimulationPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Simulation.simulation) {
    throw "La simulación no fue marcada como simulación."
}

if ([bool]$Simulation.executed) {
    throw "La simulación intentó ejecutar acciones externas."
}

$Evidence = [ordered]@{
    component = "SPT-019.1"
    name = "Workflow Engine Core"
    version = "1.0.0"
    python_syntax = "approved"
    unit_tests = "approved"
    workflow_registry = [ordered]@{
        approved = [bool]$Registry.approved
        workflow_count = [int]$Registry.workflow_count
        sha256 = [string]$Registry.sha256
    }
    simulator = [ordered]@{
        approved = $true
        external_actions_executed = $false
    }
    n8n_installed = $false
    n8n_started = $false
    paid_services_required = $false
    internet_required_for_tests = $false
    status = "implemented_tested_and_candidate_for_integration"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
}

Write-Utf8 `
    (Join-Path $ArtifactDir "implementation-evidence.json") `
    (
        ($Evidence | ConvertTo-Json -Depth 50) +
        [Environment]::NewLine
    )

$Manifest = [ordered]@{
    component = "SPT-019.1"
    version = "1.0.0"
    name = "Workflow Engine Core"
    status = "candidate_for_integration"
    tests_approved = $true
    workflows_registered = [int]$Registry.workflow_count
    registry_approved = [bool]$Registry.approved
    simulator_external_execution = $false
    paid_services_required = $false
}

Write-Utf8 `
    (Join-Path $ArtifactDir "manifest.json") `
    (
        ($Manifest | ConvertTo-Json -Depth 50) +
        [Environment]::NewLine
    )

Step "Resultado final"

Write-Host "SPT-019.1 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Sintaxis Python: APROBADA." -ForegroundColor Green
Write-Host "Pruebas: APROBADAS." -ForegroundColor Green
Write-Host (
    "Workflows registrados: " +
    [string]$Registry.workflow_count
) -ForegroundColor Green
Write-Host "Simulación externa ejecutada: NO." -ForegroundColor Green
Write-Host "n8n instalado o iniciado: NO." -ForegroundColor Green
Write-Host "Servicios de pago requeridos: NO." -ForegroundColor Green
Write-Host (
    "Evidencias: " +
    $ArtifactDir
) -ForegroundColor Cyan
