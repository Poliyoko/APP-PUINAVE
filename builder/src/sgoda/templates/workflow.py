"""Plantilla de workflows SGODA para n8n."""

import json

from sgoda.templates.module import normalize_module_name


def build_workflow_files(name: str) -> dict[str, str]:
    """Construye un workflow n8n mínimo y documentado."""
    workflow_name = normalize_module_name(name)
    workflow = {
        "name": workflow_name,
        "active": False,
        "nodes": [
            {
                "parameters": {},
                "id": "manual-trigger",
                "name": "Inicio manual",
                "type": "n8n-nodes-base.manualTrigger",
                "typeVersion": 1,
                "position": [260, 300],
            }
        ],
        "connections": {},
        "settings": {},
        "meta": {
            "generated_by": "SGODA Project Builder",
            "component": f"workflow:{workflow_name}",
        },
    }

    return {
        f"automation/n8n/{workflow_name}.json": (
            json.dumps(workflow, ensure_ascii=False, indent=2) + "\n"
        ),
        f"automation/n8n/{workflow_name}.md": (
            f"# Workflow {workflow_name}\n\n"
            "Workflow n8n generado por SGODA Project Builder.\n"
        ),
    }
