"""Publicación institucional automatizada SGODA-PUINAVE.

La API se carga de manera diferida para permitir la ejecución segura de
``python -m sgoda.publisher.institutional_publisher``.
"""

from __future__ import annotations

from typing import Any

__all__ = [
    "ErrorPublicacionRepositorio",
    "ResultadoPublicacion",
    "auditar_sin_publicar",
    "preparar_staging",
    "publicar",
    "validar_repositorio",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(
            f"El módulo {__name__!r} no contiene {name!r}"
        )

    from . import institutional_publisher

    return getattr(institutional_publisher, name)