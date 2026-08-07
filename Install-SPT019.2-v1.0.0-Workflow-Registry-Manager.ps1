<#
.SYNOPSIS
    Instala SPT-019.2 v1.0.0 — Workflow Registry Manager.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Publish
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Step { param([string]$Message) Write-Host ""; Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Utf8 {
    param([string]$Path,[string]$Content)
    $Parent=Split-Path -Parent $Path
    if($Parent){New-Item -ItemType Directory -Path $Parent -Force|Out-Null}
    [System.IO.File]::WriteAllText($Path,$Content,(New-Object System.Text.UTF8Encoding($false)))
}
function Require-Path { param([string]$Path) if(-not(Test-Path -LiteralPath $Path)){throw "Falta elemento requerido: $Path"}}
function Invoke-Checked {
    param([string]$Description,[scriptblock]$Action)
    Step $Description
    $global:LASTEXITCODE=0
    & $Action
    if($LASTEXITCODE -ne 0){throw "$Description terminó con errores. Código: $LASTEXITCODE"}
}

$ProjectRoot=[System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH=Join-Path $ProjectRoot "src"
if(-not(Test-Path -LiteralPath $env:PYTHONPATH -PathType Container)){throw "No existe la carpeta src: $env:PYTHONPATH"}

$SourceDir=Join-Path $ProjectRoot "src\sgoda\automation\workflow_registry"
$TestsDir=Join-Path $ProjectRoot "tests\automation\workflow_registry"
$ConfigDir=Join-Path $ProjectRoot "config\automation"
$DocsDir=Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-019"
$ArtifactDir=Join-Path $ProjectRoot "artifacts\technology\SPT-019.2-v1.0.0"
$ReleaseDir=Join-Path $ProjectRoot "releases\SPT-019.2-v1.0.0"
$WorkflowDir=Join-Path $ProjectRoot "automation\n8n\workflows"

foreach($Directory in @($SourceDir,$TestsDir,$ConfigDir,$DocsDir,$ArtifactDir,$ReleaseDir,$WorkflowDir)){
    New-Item -ItemType Directory -Path $Directory -Force|Out-Null
}

$Module=@'

from __future__ import annotations
import argparse, hashlib, json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

VALID_STATUSES = {"draft", "validated", "released", "retired"}
VALID_CATEGORIES = {"governance","pmo","learning","analytics","multimedia","ai","repository"}

@dataclass(frozen=True, slots=True)
class RegistryEntry:
    workflow_id: str
    name: str
    version: str
    status: str
    category: str
    file: str
    dependencies: tuple[str, ...]
    trigger_types: tuple[str, ...]
    sha256: str
    def to_dict(self) -> dict[str, Any]:
        return {
            "workflow_id": self.workflow_id,
            "name": self.name,
            "version": self.version,
            "status": self.status,
            "category": self.category,
            "file": self.file,
            "dependencies": list(self.dependencies),
            "trigger_types": list(self.trigger_types),
            "sha256": self.sha256,
        }

def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))

def sha256_payload(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()

def read_json(path_value: str | Path) -> Any:
    return json.loads(Path(path_value).read_text(encoding="utf-8-sig"))

def write_json(path_value: str | Path, payload: Any) -> None:
    path = Path(path_value)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def _trigger_types(payload: dict[str, Any]) -> tuple[str, ...]:
    nodes = payload.get("nodes", [])
    if not isinstance(nodes, list):
        return ()
    found = set()
    for node in nodes:
        if not isinstance(node, dict):
            continue
        node_type = str(node.get("type", "")).strip()
        if node_type.endswith(".webhook") or node_type.endswith("Trigger") or "Trigger" in node_type:
            found.add(node_type)
    return tuple(sorted(found))

def entry_from_workflow(path_value: str | Path, *, relative_to: str | Path) -> RegistryEntry:
    path = Path(path_value)
    payload = read_json(path)
    if not isinstance(payload, dict):
        raise ValueError("La raíz del workflow debe ser un objeto JSON.")
    meta = payload.get("meta", {})
    if not isinstance(meta, dict):
        meta = {}
    workflow_id = str(meta.get("workflow_id", "")).strip()
    name = str(payload.get("name", "")).strip()
    version = str(meta.get("version", "")).strip()
    status = str(meta.get("status", "")).strip()
    category = str(meta.get("category", "")).strip()
    dependencies_raw = meta.get("dependencies", [])
    errors = []
    if not workflow_id.startswith("SPT-019-WF-"):
        errors.append("workflow_id inválido")
    if not name.startswith("SPT-019"):
        errors.append("name inválido")
    if not version:
        errors.append("version ausente")
    if status not in VALID_STATUSES:
        errors.append("status inválido")
    if category not in VALID_CATEGORIES:
        errors.append("category inválida")
    if not isinstance(dependencies_raw, list):
        errors.append("dependencies debe ser lista")
    trigger_types = _trigger_types(payload)
    if not trigger_types:
        errors.append("workflow sin trigger")
    if errors:
        raise ValueError("; ".join(errors))
    dependencies = tuple(sorted({str(x).strip() for x in dependencies_raw if str(x).strip()}))
    return RegistryEntry(
        workflow_id=workflow_id,
        name=name,
        version=version,
        status=status,
        category=category,
        file=path.resolve().relative_to(Path(relative_to).resolve()).as_posix(),
        dependencies=dependencies,
        trigger_types=trigger_types,
        sha256=sha256_payload(payload),
    )

def discover_workflows(workflows_dir_value: str | Path) -> list[Path]:
    root = Path(workflows_dir_value)
    if not root.is_dir():
        return []
    return sorted(root.rglob("*.json"), key=lambda p: p.as_posix().casefold())

def build_registry(workflows_dir_value: str | Path) -> dict[str, Any]:
    workflows_dir = Path(workflows_dir_value).resolve()
    entries = []
    errors = []
    for path in discover_workflows(workflows_dir):
        try:
            entries.append(entry_from_workflow(path, relative_to=workflows_dir.parent))
        except Exception as exc:
            errors.append({"file": path.relative_to(workflows_dir.parent).as_posix(), "error": str(exc)})
    ids = [e.workflow_id for e in entries]
    names = [e.name for e in entries]
    duplicate_ids = sorted({x for x in ids if ids.count(x) > 1})
    duplicate_names = sorted({x for x in names if names.count(x) > 1})
    if duplicate_ids:
        errors.append({"file":"<registry>","error":"workflow_id duplicados: " + ", ".join(duplicate_ids)})
    if duplicate_names:
        errors.append({"file":"<registry>","error":"nombres duplicados: " + ", ".join(duplicate_names)})
    records = [e.to_dict() for e in sorted(entries, key=lambda e: e.workflow_id)]
    registry = {
        "component":"SPT-019.2",
        "name":"Workflow Registry Manager",
        "version":"1.0.0",
        "generated_at_utc":datetime.now(timezone.utc).isoformat(),
        "workflow_count":len(records),
        "active_count":sum(x["status"] in {"validated","released"} for x in records),
        "retired_count":sum(x["status"] == "retired" for x in records),
        "workflows":records,
        "errors":errors,
        "approved":not errors,
    }
    registry["sha256"] = sha256_payload({"component":registry["component"],"version":registry["version"],"workflows":records})
    return registry

def load_registry(path_value: str | Path) -> dict[str, Any]:
    payload = read_json(path_value)
    if not isinstance(payload, dict) or payload.get("component") != "SPT-019.2":
        raise ValueError("Registro inválido o de otro componente.")
    if not isinstance(payload.get("workflows"), list):
        raise ValueError("workflows debe ser una lista.")
    return payload

def query_registry(registry: dict[str, Any], *, workflow_id: str | None=None, category: str | None=None, status: str | None=None) -> list[dict[str, Any]]:
    result = []
    for item in registry.get("workflows", []):
        if not isinstance(item, dict):
            continue
        if workflow_id and item.get("workflow_id") != workflow_id:
            continue
        if category and item.get("category") != category:
            continue
        if status and item.get("status") != status:
            continue
        result.append(item)
    return sorted(result, key=lambda x: str(x.get("workflow_id","")))

def retire_workflow(registry: dict[str, Any], workflow_id: str) -> dict[str, Any]:
    updated = json.loads(json.dumps(registry))
    found = False
    for item in updated.get("workflows", []):
        if item.get("workflow_id") == workflow_id:
            item["status"] = "retired"
            found = True
    if not found:
        raise KeyError(f"Workflow no encontrado: {workflow_id}")
    updated["retired_count"] = sum(x.get("status") == "retired" for x in updated["workflows"])
    updated["active_count"] = sum(x.get("status") in {"validated","released"} for x in updated["workflows"])
    updated["sha256"] = sha256_payload({"component":updated["component"],"version":updated["version"],"workflows":updated["workflows"]})
    return updated

def compare_registries(previous: dict[str, Any], current: dict[str, Any]) -> dict[str, Any]:
    p = {x["workflow_id"]:x for x in previous.get("workflows",[]) if isinstance(x,dict) and x.get("workflow_id")}
    c = {x["workflow_id"]:x for x in current.get("workflows",[]) if isinstance(x,dict) and x.get("workflow_id")}
    added = sorted(set(c)-set(p))
    removed = sorted(set(p)-set(c))
    changed = sorted(k for k in set(p)&set(c) if p[k].get("sha256") != c[k].get("sha256") or p[k].get("status") != c[k].get("status") or p[k].get("version") != c[k].get("version"))
    return {"added":added,"removed":removed,"changed":changed,"has_changes":bool(added or removed or changed)}

def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build"); b.add_argument("--workflows-dir",required=True); b.add_argument("--output",required=True)
    q = sub.add_parser("query"); q.add_argument("--registry",required=True); q.add_argument("--workflow-id"); q.add_argument("--category"); q.add_argument("--status")
    r = sub.add_parser("retire"); r.add_argument("--registry",required=True); r.add_argument("--workflow-id",required=True); r.add_argument("--output",required=True)
    c = sub.add_parser("compare"); c.add_argument("--previous",required=True); c.add_argument("--current",required=True)
    args = parser.parse_args()
    if args.command == "build":
        registry = build_registry(args.workflows_dir); write_json(args.output, registry); print(json.dumps(registry, ensure_ascii=False)); return 0 if registry["approved"] else 2
    if args.command == "query":
        print(json.dumps(query_registry(load_registry(args.registry), workflow_id=args.workflow_id, category=args.category, status=args.status), ensure_ascii=False)); return 0
    if args.command == "retire":
        updated = retire_workflow(load_registry(args.registry), args.workflow_id); write_json(args.output, updated); print(json.dumps(updated, ensure_ascii=False)); return 0
    print(json.dumps(compare_registries(load_registry(args.previous), load_registry(args.current)), ensure_ascii=False)); return 0

'@
$Tests=@'

from __future__ import annotations
import json
from pathlib import Path
import pytest
from sgoda.automation.workflow_registry import *

def workflow(workflow_id: str, name: str, *, version: str="1.0.0", status: str="validated", category: str="governance") -> dict:
    return {
        "name":name,
        "nodes":[{"id":"trigger-1","name":"Webhook","type":"n8n-nodes-base.webhook","typeVersion":2,"position":[0,0],"parameters":{}}],
        "connections":{},
        "active":False,
        "meta":{"workflow_id":workflow_id,"version":version,"status":status,"category":category,"dependencies":["POL-001"]},
    }

def write_workflow(path: Path, payload: dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return path

def test_hash_deterministic():
    assert sha256_payload({"b":2,"a":1}) == sha256_payload({"a":1,"b":2})

def test_discovery_sorted(tmp_path):
    root=tmp_path/"workflows"
    write_workflow(root/"b.json",workflow("SPT-019-WF-002","SPT-019 — B"))
    write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    assert [p.name for p in discover_workflows(root)] == ["a.json","b.json"]

def test_valid_entry(tmp_path):
    root=tmp_path/"workflows"; path=write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    assert entry_from_workflow(path, relative_to=tmp_path).workflow_id == "SPT-019-WF-001"

def test_invalid_entry(tmp_path):
    root=tmp_path/"workflows"; path=write_workflow(root/"a.json",workflow("BAD","SPT-019 — A"))
    with pytest.raises(ValueError): entry_from_workflow(path, relative_to=tmp_path)

def test_build_approved(tmp_path):
    root=tmp_path/"workflows"
    write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    write_workflow(root/"b.json",workflow("SPT-019-WF-002","SPT-019 — B"))
    r=build_registry(root)
    assert r["approved"] and r["workflow_count"] == 2

def test_duplicate_ids_rejected(tmp_path):
    root=tmp_path/"workflows"
    write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    write_workflow(root/"b.json",workflow("SPT-019-WF-001","SPT-019 — B"))
    assert not build_registry(root)["approved"]

def test_query_category(tmp_path):
    root=tmp_path/"workflows"
    write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A",category="governance"))
    write_workflow(root/"b.json",workflow("SPT-019-WF-002","SPT-019 — B",category="pmo"))
    assert query_registry(build_registry(root),category="pmo")[0]["workflow_id"] == "SPT-019-WF-002"

def test_query_status(tmp_path):
    root=tmp_path/"workflows"; write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A",status="released"))
    assert len(query_registry(build_registry(root),status="released")) == 1

def test_retire(tmp_path):
    root=tmp_path/"workflows"; write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    updated=retire_workflow(build_registry(root),"SPT-019-WF-001")
    assert updated["workflows"][0]["status"] == "retired"

def test_retire_unknown(tmp_path):
    root=tmp_path/"workflows"; write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    with pytest.raises(KeyError): retire_workflow(build_registry(root),"SPT-019-WF-999")

def test_compare_added(tmp_path):
    a=tmp_path/"a"; b=tmp_path/"b"
    write_workflow(a/"x.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    write_workflow(b/"x.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    write_workflow(b/"y.json",workflow("SPT-019-WF-002","SPT-019 — B"))
    assert compare_registries(build_registry(a),build_registry(b))["added"] == ["SPT-019-WF-002"]

def test_compare_changed(tmp_path):
    a=tmp_path/"a"; b=tmp_path/"b"
    write_workflow(a/"x.json",workflow("SPT-019-WF-001","SPT-019 — A",status="validated"))
    write_workflow(b/"x.json",workflow("SPT-019-WF-001","SPT-019 — A",status="released"))
    assert compare_registries(build_registry(a),build_registry(b))["changed"] == ["SPT-019-WF-001"]

def test_write_load(tmp_path):
    root=tmp_path/"workflows"; write_workflow(root/"a.json",workflow("SPT-019-WF-001","SPT-019 — A"))
    p=tmp_path/"registry.json"; write_json(p,build_registry(root))
    assert load_registry(p)["component"] == "SPT-019.2"

'@
$Component=@'
{
  "increment_code":"SPT-019.2",
  "name":"Workflow Registry Manager",
  "version":"1.0.0",
  "status":"implemented_tested_and_candidate_for_integration",
  "parent":"SPT-019",
  "depends_on":["SPT-019.1-v1.0.1","POL-001-v1.0.2"],
  "paid_services_required":false,
  "n8n_runtime_required":false
}
'@
$Policy=@'
{
  "policy_id":"SPT-019.2-POLICY-v1.0.0",
  "unique_workflow_id_required":true,
  "unique_workflow_name_required":true,
  "status_catalog":["draft","validated","released","retired"],
  "registry_hash_required":true,
  "external_actions_allowed":false
}
'@
$Architecture=@'
# SPT-019.2 — Workflow Registry Manager

Administra el registro institucional de workflows: descubrimiento, validación,
duplicados, consultas, retiro lógico, comparación y hash determinístico.

No instala ni inicia n8n.
'@
$Operations=@'
# SPT-019.2 — Manual operativo

Construcción:

```powershell
python -m sgoda.automation.workflow_registry build `
  --workflows-dir automation/n8n/workflows `
  --output artifacts/technology/SPT-019.2-v1.0.0/workflow-registry.json
```
'@

Write-Utf8 (Join-Path $SourceDir "__init__.py") $Module
Write-Utf8 (Join-Path $SourceDir "__main__.py") ("from . import main"+[Environment]::NewLine+"raise SystemExit(main())"+[Environment]::NewLine)
Write-Utf8 (Join-Path $TestsDir "test_SPT_019_2_workflow_registry_manager.py") $Tests
Write-Utf8 (Join-Path $ConfigDir "SPT-019.2-component.json") $Component
Write-Utf8 (Join-Path $ConfigDir "SPT-019.2-policy.json") $Policy
Write-Utf8 (Join-Path $DocsDir "SPT-019.2-Arquitectura.md") $Architecture
Write-Utf8 (Join-Path $DocsDir "SPT-019.2-Manual-Operativo.md") $Operations

Invoke-Checked "Validando sintaxis Python SPT-019.2" {
    python -m py_compile `
      "src/sgoda/automation/workflow_registry/__init__.py" `
      "src/sgoda/automation/workflow_registry/__main__.py" `
      "tests/automation/workflow_registry/test_SPT_019_2_workflow_registry_manager.py"
}

Invoke-Checked "Ejecutando pruebas SPT-019.2" {
    $JUnitPath=Join-Path $ArtifactDir "unit-tests.xml"
    python -m pytest `
      "tests/automation/workflow_registry/test_SPT_019_2_workflow_registry_manager.py" `
      -q `
      "--junitxml=$JUnitPath"
}

Invoke-Checked "Generando registro institucional de workflows" {
    $RegistryOutput=Join-Path $ArtifactDir "workflow-registry.json"
    python -m sgoda.automation.workflow_registry build `
      --workflows-dir "$WorkflowDir" `
      --output "$RegistryOutput"
}

$RegistryPath=Join-Path $ArtifactDir "workflow-registry.json"
Require-Path $RegistryPath
$Registry=Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8|ConvertFrom-Json
if(-not[bool]$Registry.approved){throw "El registro institucional no fue aprobado."}

$Evidence=[ordered]@{
    component="SPT-019.2"
    version="1.0.0"
    status="implemented_tested_and_candidate_for_integration"
    syntax="approved"
    unit_tests="approved"
    workflow_count=[int]$Registry.workflow_count
    registry_sha256=[string]$Registry.sha256
    external_actions_executed=$false
    n8n_installed_or_started=$false
    paid_services_required=$false
    generated_at_utc=[DateTime]::UtcNow.ToString("o")
}
Write-Utf8 (Join-Path $ArtifactDir "implementation-evidence.json") (($Evidence|ConvertTo-Json -Depth 50)+[Environment]::NewLine)

$Manifest=[ordered]@{
    component="SPT-019.2"
    name="Workflow Registry Manager"
    version="1.0.0"
    status="candidate_for_integration"
    workflow_count=[int]$Registry.workflow_count
    registry_approved=[bool]$Registry.approved
    registry_sha256=[string]$Registry.sha256
    paid_services_required=$false
    n8n_runtime_required=$false
}
Write-Utf8 (Join-Path $ReleaseDir "manifest.json") (($Manifest|ConvertTo-Json -Depth 50)+[Environment]::NewLine)

foreach($RelativePath in @(
 "src\sgoda\automation\workflow_registry",
 "tests\automation\workflow_registry",
 "config\automation\SPT-019.2-component.json",
 "config\automation\SPT-019.2-policy.json",
 "docs\08_Fase_Tecnologica_IV\SPT-019\SPT-019.2-Arquitectura.md",
 "docs\08_Fase_Tecnologica_IV\SPT-019\SPT-019.2-Manual-Operativo.md",
 "artifacts\technology\SPT-019.2-v1.0.0"
)){
    $Source=Join-Path $ProjectRoot $RelativePath
    Require-Path $Source
    Copy-Item -LiteralPath $Source -Destination $ReleaseDir -Recurse -Force
}

if($Publish){
    $Publisher=Join-Path $ProjectRoot "scripts\Invoke-SPB007-CanonicalPublish.ps1"
    Require-Path $Publisher
    Invoke-Checked "Publicando SPT-019.2" {
        & $Publisher -Publish `
          -CommitMessage "feat(automation): implement SPT-019.2 workflow registry manager" `
          -EvidenceCommitMessage "chore(automation): publish SPT-019.2 evidence"
    }
}

Step "Resultado final"
Write-Host "SPT-019.2 v1.0.0 implementado." -ForegroundColor Green
Write-Host "Pruebas: APROBADAS." -ForegroundColor Green
Write-Host ("Workflows registrados: "+[string]$Registry.workflow_count) -ForegroundColor Green
Write-Host "Registro institucional: APROBADO." -ForegroundColor Green
Write-Host "Acciones externas ejecutadas: NO." -ForegroundColor Green
Write-Host "n8n instalado o iniciado: NO." -ForegroundColor Green
Write-Host "Release: releases\SPT-019.2-v1.0.0" -ForegroundColor Cyan
