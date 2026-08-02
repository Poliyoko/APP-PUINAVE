"""Sistema Maestro de Documentación SGODA-PUINAVE.

La API pública se carga de forma diferida para permitir la ejecución
segura de ``python -m sgoda.documentation.master_docs``.
"""

from __future__ import annotations

from typing import Any

__all__ = [
    "ComponentRecord",
    "ValidationResult",
    "discover_components",
    "publish_artifacts",
    "validate_master_documents",
    "write_master_documents",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(
            f"El módulo {__name__!r} no contiene {name!r}"
        )

    from . import master_docs

    return getattr(master_docs, name)