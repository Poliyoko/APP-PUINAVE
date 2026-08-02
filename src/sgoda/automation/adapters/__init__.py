"""Adaptadores multimedia SPT-003B.

La API pública se carga de forma diferida para permitir la ejecución segura
de ``python -m sgoda.automation.adapters.processor``.
"""

from __future__ import annotations

from typing import Any

__all__ = [
    "AlmacenamientoLocalRMR",
    "ProcesadorTrabajosMultimedia",
    "ProveedorExternoDeshabilitado",
    "ProveedorSimulado",
    "PublicadorEventosArchivo",
    "ResultadoPersistencia",
    "ResultadoProveedor",
    "SolicitudProveedor",
    "construir_proveedor",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(
            f"El módulo {__name__!r} no contiene {name!r}"
        )

    if name in {
        "ResultadoPersistencia",
        "ResultadoProveedor",
        "SolicitudProveedor",
    }:
        from . import contracts
        return getattr(contracts, name)

    if name == "PublicadorEventosArchivo":
        from . import n8n
        return getattr(n8n, name)

    if name == "ProcesadorTrabajosMultimedia":
        from . import processor
        return getattr(processor, name)

    if name in {
        "ProveedorExternoDeshabilitado",
        "ProveedorSimulado",
        "construir_proveedor",
    }:
        from . import providers
        return getattr(providers, name)

    if name == "AlmacenamientoLocalRMR":
        from . import storage
        return getattr(storage, name)

    raise AttributeError(name)