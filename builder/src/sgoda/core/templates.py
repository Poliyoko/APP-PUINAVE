"""Plantillas base generadas por el inicializador SGODA."""

import json
from datetime import UTC, datetime


def build_project_files(project_name: str) -> dict[str, str]:
    created_at = datetime.now(UTC).isoformat()
    manifest = {
        "schema_version": "1.0",
        "project": {"name": project_name, "type": "SGODA", "version": "0.1.0", "status": "initial", "created_at": created_at},
        "governance": {"frameworks": ["DAMA-DMBOK", "FAIR", "CARE"], "data_owner": "Comunidad Puinave"},
        "resources": {"lexicon": "data/json/palabras.json", "images": "assets/images", "audio_es": "assets/audio/es", "audio_en": "assets/audio/en", "audio_pu": "assets/audio/pu"},
    }
    readme = f"""# {project_name}

Proyecto inicializado con SGODA Project Builder.

## Propósito

Plataforma digital para la preservación y enseñanza de la lengua y cultura Puinave.

## Gobierno de datos

Este proyecto adopta DAMA-DMBOK, FAIR y CARE.

> Tecnología para preservar la memoria del pueblo Puinave.
"""
    gitignore = """__pycache__/
*.py[cod]
.env
.venv/
.pytest_cache/
.ruff_cache/
build/
dist/
.DS_Store
Thumbs.db
"""
    palabras = {"schema_version": "1.0", "language": "puinave", "records": []}
    return {
        "README.md": readme,
        ".gitignore": gitignore,
        "sgoda.project.json": json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        "data/json/palabras.json": json.dumps(palabras, ensure_ascii=False, indent=2) + "\n",
    }
