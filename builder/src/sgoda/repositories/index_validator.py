"""Validación semántica de índices remotos."""

from __future__ import annotations

import re
from datetime import datetime
from urllib.parse import urlparse

from .index_models import RepositoryIndex


class IndexValidationError(ValueError):
    """El índice remoto no cumple el contrato SGODA."""


_SHA256 = re.compile(r"^[a-fA-F0-9]{64}$")
_SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:[-+][0-9A-Za-z.-]+)?$")
_PACKAGE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_SUPPORTED_TYPES = {"plugin", "template", "extension", "bundle"}


def _validate_http_url(value: str, field: str) -> None:
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise IndexValidationError(f"{field} debe ser una URL HTTP/HTTPS absoluta.")
    if parsed.username or parsed.password:
        raise IndexValidationError(f"{field} no debe incluir credenciales.")


def validate_index(index: RepositoryIndex, *, expected_repository: str | None = None) -> None:
    if index.schema_version != "1.0":
        raise IndexValidationError(
            f"Versión de esquema no soportada: {index.schema_version}"
        )
    if expected_repository and index.repository != expected_repository:
        raise IndexValidationError(
            f"El índice pertenece a '{index.repository}', se esperaba '{expected_repository}'."
        )
    try:
        datetime.fromisoformat(index.generated_at.replace("Z", "+00:00"))
    except ValueError as exc:
        raise IndexValidationError("'generated_at' debe ser una fecha ISO-8601.") from exc

    identities: set[tuple[str, str, str]] = set()
    for package in index.packages:
        if not _PACKAGE_NAME.fullmatch(package.name):
            raise IndexValidationError(f"Nombre de paquete inválido: {package.name!r}")
        if package.type not in _SUPPORTED_TYPES:
            raise IndexValidationError(
                f"Tipo de paquete no soportado para '{package.name}': {package.type}"
            )
        if not _SEMVER.fullmatch(package.version):
            raise IndexValidationError(
                f"Versión inválida para '{package.name}': {package.version}"
            )
        _validate_http_url(package.download_url, f"download_url de '{package.name}'")
        if not _SHA256.fullmatch(package.sha256):
            raise IndexValidationError(
                f"SHA-256 inválido para '{package.name}'."
            )
        identity = (package.type, package.name, package.version)
        if identity in identities:
            raise IndexValidationError(
                f"Paquete duplicado: {package.type}/{package.name}@{package.version}"
            )
        identities.add(identity)
