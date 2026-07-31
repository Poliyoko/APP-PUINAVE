"""Registro de módulos oficiales de SGODA-PUINAVE."""

from __future__ import annotations

from importlib.util import find_spec

from sgoda.kernel.models import ModuleDescriptor
from sgoda.kernel.registry import ModuleRegistry


def _module_exists(module_path: str) -> bool:
    """Comprueba si un paquete Python está disponible."""

    try:
        return find_spec(module_path) is not None
    except (
        ImportError,
        ModuleNotFoundError,
        ValueError,
    ):
        return False


def register_platform_modules(
    registry: ModuleRegistry,
) -> None:
    """Registra los módulos actuales y planificados."""

    pmo_available = _module_exists("sgoda.pmo")

    modules = (
        ModuleDescriptor(
            name="SGODA Platform Kernel",
            code="kernel",
            version="0.5.2",
            status="operational",
            description=(
                "Núcleo transversal de "
                "SGODA-PUINAVE."
            ),
            enabled=True,
            capabilities=(
                "module-registry",
                "metadata",
                "repository-audit",
                "application-factory",
            ),
        ),
        ModuleDescriptor(
            name="PMO Digital",
            code="pmo",
            version="0.1.0",
            status=(
                "available"
                if pmo_available
                else "pending-integration"
            ),
            description=(
                "Gobierno, trazabilidad y "
                "auditoría del proyecto."
            ),
            enabled=pmo_available,
            capabilities=(
                "project-governance",
                "deliverable-traceability",
                "repository-audit",
            ),
        ),
        ModuleDescriptor(
            name="Diccionario Puinave",
            code="dictionary",
            version="0.0.0",
            status="planned",
            description=(
                "Gestión de fichas léxicas "
                "digitales."
            ),
            enabled=False,
            capabilities=(
                "lexical-entries",
                "translations",
                "categories",
            ),
        ),
        ModuleDescriptor(
            name="Recursos Multimedia",
            code="media",
            version="0.0.0",
            status="planned",
            description=(
                "Gestión de imágenes, "
                "audios y videos."
            ),
            enabled=False,
            capabilities=(
                "images",
                "audio",
                "video",
                "resource-validation",
            ),
        ),
        ModuleDescriptor(
            name="Objetos Digitales de Aprendizaje",
            code="oda",
            version="0.0.0",
            status="planned",
            description=(
                "Gestión de actividades "
                "y recursos pedagógicos."
            ),
            enabled=False,
            capabilities=(
                "flashcards",
                "lessons",
                "exercises",
                "quizzes",
            ),
        ),
        ModuleDescriptor(
            name="Automatización n8n",
            code="automation",
            version="0.0.0",
            status="planned",
            description=(
                "Adaptador para flujos "
                "automatizados con n8n."
            ),
            enabled=False,
            capabilities=(
                "webhooks",
                "workflow-execution",
                "integration-events",
            ),
        ),
    )

    for module in modules:
        registry.register(
            module,
            replace=True,
        )
