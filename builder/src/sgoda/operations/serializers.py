"""Serializadores desacoplados del estado operativo."""

from __future__ import annotations

import json

from .models import OperationStatus


def serialize_json(status: OperationStatus, *, detailed: bool = False) -> str:
    return json.dumps(
        status.to_dict(detailed=detailed),
        ensure_ascii=False,
        indent=2,
    )


def serialize_text(status: OperationStatus, *, detailed: bool = False) -> str:
    components_total = sum(status.components.values())
    lines = [
        "Estado Operativo SGODA",
        f"Proyecto: {status.project.name}",
        f"Ruta: {status.workspace}",
        "-" * 60,
        f"Versión del proyecto: {status.project.version}",
        f"Versión del esquema: {status.project.schema_version}",
        f"Versión del Builder: {status.builder_version}",
        f"Auditoría: {status.audit.status}",
        f"Puntuación: {status.audit.score}/100",
        f"Errores: {status.audit.errors}",
        f"Advertencias: {status.audit.warnings}",
        f"Componentes: {components_total}",
        f"Plugins: {status.extensions.plugins}",
        f"Plantillas: {status.extensions.templates}",
        f"Migraciones: {status.lifecycle.migrations}",
        f"Recursos: {status.resources.available}/{status.resources.total}",
        "-" * 60,
        f"Estado general: {status.health}",
    ]
    if detailed:
        lines.extend([
            "",
            "Detalle de componentes:",
        ])
        if status.components:
            lines.extend(
                f"- {kind}: {count}"
                for kind, count in status.components.items()
            )
        else:
            lines.append("- Sin componentes registrados.")
        lines.extend([
            "",
            "Ciclo de vida:",
            f"- Última migración: {status.lifecycle.last_migrated_at or 'No registrada'}",
            f"- Última reparación: {status.lifecycle.last_repaired_at or 'No registrada'}",
            "",
            "Recursos:",
            f"- Léxico: {'OK' if status.resources.lexicon else 'FALTA'}",
            f"- Catálogo FAIR: {'OK' if status.resources.metadata_catalog else 'FALTA'}",
            f"- Gobierno: {'OK' if status.resources.governance_documentation else 'FALTA'}",
        ])
    return "\n".join(lines)
