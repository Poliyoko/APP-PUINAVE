"""Plantillas base del inicializador SGODA."""

import json
from datetime import UTC, datetime


def build_project_files(project_name: str) -> dict[str, str]:
    """Construye los archivos iniciales del proyecto."""
    created_at = datetime.now(UTC).isoformat()

    manifest = {
        "schema_version": "1.3",
        "project": {
            "name": project_name,
            "type": "SGODA",
            "version": "0.1.0",
            "status": "initial",
            "created_at": created_at,
        },
        "governance": {
            "frameworks": ["DAMA-DMBOK", "FAIR", "CARE"],
            "data_owner": "Comunidad Puinave",
            "data_steward": "Equipo SGODA-PUINAVE",
            "classification": "cultural-community-data",
            "care": {
                "collective_benefit": True,
                "authority_to_control": True,
                "responsibility": True,
                "ethics": True,
            },
        },
        "components": {},
        "lifecycle": {
            "managed_by": "SGODA Project Builder",
            "migration_history": [],
        },
        "resources": {
            "lexicon": "data/json/palabras.json",
            "metadata_catalog": "data/metadata/catalog.json",
        },
    }

    catalog = {
        "schema_version": "1.0",
        "title": f"Catálogo de datos de {project_name}",
        "description": "Catálogo inicial de activos de datos SGODA-PUINAVE.",
        "owner": "Comunidad Puinave",
        "license": "Por definir con la comunidad",
        "language": ["puinave", "es", "en"],
        "datasets": [
            {
                "id": "lexicon",
                "path": "data/json/palabras.json",
                "title": "Léxico base Puinave",
                "format": "application/json",
            }
        ],
    }

    palabras = {
        "schema_version": "1.0",
        "language": "puinave",
        "records": [],
    }

    governance_readme = f"""# Gobierno de datos de {project_name}

## Propiedad

La Comunidad Puinave es la propietaria colectiva de los datos culturales.

## Marcos aplicados

- DAMA-DMBOK
- FAIR
- CARE

## Custodia

La custodia técnica corresponde al equipo SGODA-PUINAVE bajo autoridad comunitaria.
"""

    return {
        "README.md": (
            f"# {project_name}\n\n"
            "Proyecto inicializado con SGODA Project Builder.\n"
        ),
        ".gitignore": "__pycache__/\n.venv/\n.pytest_cache/\n",
        "sgoda.project.json": json.dumps(
            manifest, ensure_ascii=False, indent=2
        ) + "\n",
        "data/json/palabras.json": json.dumps(
            palabras, ensure_ascii=False, indent=2
        ) + "\n",
        "data/metadata/catalog.json": json.dumps(
            catalog, ensure_ascii=False, indent=2
        ) + "\n",
        "docs/00_Gobierno/README.md": governance_readme,
    }
