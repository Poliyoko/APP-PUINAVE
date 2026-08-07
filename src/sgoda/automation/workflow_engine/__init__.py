
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



def load_event_file(path_value: str | Path) -> dict[str, Any]:
    path = Path(path_value)
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict):
        raise ValueError("El evento de simulación debe ser un objeto JSON.")
    return payload

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
    event_group = simulate_parser.add_mutually_exclusive_group(required=True)
    event_group.add_argument("--event-json")
    event_group.add_argument("--event-file")

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

    if args.event_file:
        event = load_event_file(args.event_file)
    else:
        event = json.loads(args.event_json)
        if not isinstance(event, dict):
            raise ValueError("El evento de simulación debe ser un objeto JSON.")

    result = simulate_workflow(args.workflow, event)
    print(json.dumps(result, ensure_ascii=False))
    return 0