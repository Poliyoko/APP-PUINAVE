"""Carga segura de políticas de gobernanza desde archivos JSON."""

from __future__ import annotations

import os
from collections.abc import Iterable
from pathlib import Path
from typing import TypeAlias

from .exceptions import (
    PolicyLoadError,
    PolicySerializationError,
)
from .models import PolicyDefinition
from .serializers import deserialize_policy


PathInput: TypeAlias = str | os.PathLike[str]


def _normalize_path(path: PathInput) -> Path:
    """Convierte y valida una entrada de ruta."""
    if isinstance(path, str):
        if not path.strip():
            raise PolicyLoadError(
                "policy path must not be empty",
            )

        return Path(path)

    if isinstance(path, os.PathLike):
        try:
            return Path(path)
        except (TypeError, ValueError) as exc:
            raise PolicyLoadError(
                "policy path is invalid",
                context={
                    "cause": str(exc),
                    "type": type(path).__name__,
                },
            ) from exc

    raise PolicyLoadError(
        "policy path must be a string or path-like object",
        context={
            "type": type(path).__name__,
        },
    )


def load_policy(path: PathInput) -> PolicyDefinition:
    """Carga y valida una política desde un archivo JSON UTF-8.

    Args:
        path:
            Ruta de un archivo que contiene una política serializada
            mediante el formato JSON admitido por ``deserialize_policy``.

    Returns:
        La política de gobernanza validada.

    Raises:
        PolicyLoadError:
            Si la ruta no es válida, el archivo no puede leerse o su
            contenido no representa una política válida.
    """
    normalized_path = _normalize_path(path)

    if not normalized_path.exists():
        raise PolicyLoadError(
            "policy file does not exist",
            context={
                "path": str(normalized_path),
            },
        )

    if not normalized_path.is_file():
        raise PolicyLoadError(
            "policy path must reference a file",
            context={
                "path": str(normalized_path),
            },
        )

    try:
        payload = normalized_path.read_bytes()
    except OSError as exc:
        raise PolicyLoadError(
            "policy file could not be read",
            context={
                "path": str(normalized_path),
                "cause": str(exc),
            },
        ) from exc

    try:
        return deserialize_policy(payload)
    except PolicySerializationError as exc:
        raise PolicyLoadError(
            "policy file contains an invalid policy",
            context={
                "path": str(normalized_path),
                "cause": str(exc),
            },
        ) from exc


def load_policies(
    paths: Iterable[PathInput],
) -> tuple[PolicyDefinition, ...]:
    """Carga varias políticas conservando el orden de las rutas.

    La operación falla inmediatamente cuando una de las entradas no puede
    cargarse. No se devuelven resultados parciales.
    """
    if isinstance(paths, (str, bytes, bytearray, os.PathLike)):
        raise PolicyLoadError(
            "policy paths must be an iterable of paths",
            context={
                "type": type(paths).__name__,
            },
        )

    try:
        iterator = iter(paths)
    except TypeError as exc:
        raise PolicyLoadError(
            "policy paths must be iterable",
            context={
                "type": type(paths).__name__,
            },
        ) from exc

    loaded: list[PolicyDefinition] = []

    for index, path in enumerate(iterator):
        try:
            loaded.append(load_policy(path))
        except PolicyLoadError as exc:
            raise PolicyLoadError(
                "one or more policy files could not be loaded",
                context={
                    "index": index,
                    "path": str(path),
                    "cause": str(exc),
                },
            ) from exc

    return tuple(loaded)


__all__ = [
    "PathInput",
    "load_policies",
    "load_policy",
]
