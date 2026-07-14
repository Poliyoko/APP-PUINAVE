"""Plantilla de documentación técnica SGODA."""

from datetime import UTC, datetime

from sgoda.templates.module import normalize_module_name


def build_docs_files(name: str) -> dict[str, str]:
    """Construye un documento técnico inicial."""
    document_name = normalize_module_name(name)
    created_at = datetime.now(UTC).isoformat()

    return {
        f"docs/08_Desarrollo/{document_name}.md": (
            f"# {document_name}\n\n"
            "## Identificación\n\n"
            f"- Estado: borrador\n"
            f"- Creado: {created_at}\n"
            "- Generador: SGODA Project Builder\n\n"
            "## Propósito\n\n"
            "Documentar el componente y sus decisiones de implementación.\n\n"
            "## Gobierno de datos\n\n"
            "Aplican DAMA-DMBOK, FAIR y CARE.\n"
        )
    }
