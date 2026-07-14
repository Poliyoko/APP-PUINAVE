"""Plantillas del inicializador."""

import json
from datetime import UTC, datetime


def build_project_files(project_name: str) -> dict[str, str]:
    manifest = {
        "schema_version": "1.1",
        "project": {
            "name": project_name,
            "type": "SGODA",
            "version": "0.1.0",
            "created_at": datetime.now(UTC).isoformat(),
        },
        "governance": {
            "frameworks": ["DAMA-DMBOK", "FAIR", "CARE"],
            "data_owner": "Comunidad Puinave",
        },
        "components": {},
    }

    return {
        "README.md": f"# {project_name}\n",
        ".gitignore": "__pycache__/\n.venv/\n",
        "sgoda.project.json": json.dumps(
            manifest, ensure_ascii=False, indent=2
        ) + "\n",
        "data/json/palabras.json": json.dumps(
            {"schema_version": "1.0", "records": []},
            ensure_ascii=False,
            indent=2,
        ) + "\n",
    }
