"""Rutas REST del SGODA Platform Kernel."""

from fastapi import APIRouter

from sgoda.kernel.audit import audit_repository
from sgoda.kernel.metadata import get_platform_metadata
from sgoda.kernel.registry import module_registry


router = APIRouter(prefix="/kernel", tags=["Kernel"])


@router.get("/status")
def kernel_status() -> dict:
    """Devuelve el estado general del Kernel."""

    modules = module_registry.list_modules()

    return {
        "status": "operational",
        "kernel": "SGODA Platform Kernel",
        "registered_modules": len(modules),
        "enabled_modules": sum(module.enabled for module in modules),
        "metadata": get_platform_metadata(),
    }


@router.get("/modules")
def kernel_modules() -> dict:
    """Devuelve el catálogo de módulos registrados."""

    modules = [
        module.to_dict()
        for module in module_registry.list_modules()
    ]

    return {
        "count": len(modules),
        "modules": modules,
    }


@router.get("/metadata")
def kernel_metadata() -> dict:
    """Devuelve los metadatos técnicos de la plataforma."""

    return get_platform_metadata()


@router.get("/audit/repository")
def kernel_repository_audit() -> dict:
    """Ejecuta una auditoría Git de solo lectura."""

    return audit_repository()
