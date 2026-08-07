
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
