"""Validador común de manifiestos de extensiones."""

from __future__ import annotations

import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
from typing import Any

from sgoda import __version__

from .compatibility import (
    CompatibilityError,
    parse_version,
    requirement_satisfied as compatibility_satisfied,
)
from .models import ExtensionManifest

NAME_PATTERN = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_-]{1,63}$")


class ExtensionValidationError(ValueError):
    """Manifiesto de extensión inválido."""


def validate_relative_path(value: str) -> str:
    if not value or "\x00" in value:
        raise ExtensionValidationError("Ruta de archivo inválida.")
    posix = PurePosixPath(value.replace("\\", "/"))
    windows = PureWindowsPath(value)
    if posix.is_absolute() or windows.is_absolute() or windows.drive:
        raise ExtensionValidationError(f"Ruta absoluta no permitida: {value}")
    if ".." in posix.parts:
        raise ExtensionValidationError(f"Path traversal no permitido: {value}")
    normalized = str(posix)
    if normalized in {".", ""}:
        raise ExtensionValidationError(f"Ruta vacía no permitida: {value}")
    return normalized


def load_manifest(path: str | Path) -> ExtensionManifest:
    source = Path(path).expanduser().resolve()
    if source.is_dir():
        candidates = (
            source / "sgoda.plugin.json",
            source / "sgoda.template.json",
        )
        manifest_path = next(
            (candidate for candidate in candidates if candidate.is_file()),
            None,
        )
        if manifest_path is None:
            raise ExtensionValidationError(
                f"No existe manifiesto de extensión en {source}"
            )
    else:
        manifest_path = source

    try:
        payload = json.loads(
            manifest_path.read_text(encoding="utf-8-sig")
        )
    except (OSError, json.JSONDecodeError) as exc:
        raise ExtensionValidationError(
            f"No fue posible leer el manifiesto: {exc}"
        ) from exc

    if not isinstance(payload, dict):
        raise ExtensionValidationError(
            "La raíz del manifiesto debe ser un objeto JSON."
        )
    return validate_manifest(payload, base_dir=manifest_path.parent)


def validate_manifest(
    payload: dict[str, Any],
    *,
    base_dir: Path | None = None,
) -> ExtensionManifest:
    required = (
        "schema_version",
        "type",
        "name",
        "version",
        "builder_requires",
    )
    missing = [field for field in required if field not in payload]
    if missing:
        raise ExtensionValidationError(
            "Faltan campos obligatorios: " + ", ".join(missing)
        )

    extension_type = str(payload["type"])
    if extension_type not in {"plugin", "template"}:
        raise ExtensionValidationError(
            f"Tipo de extensión no soportado: {extension_type}"
        )

    name = str(payload["name"])
    if not NAME_PATTERN.fullmatch(name):
        raise ExtensionValidationError(f"Nombre inválido: {name}")

    version = str(payload["version"])
    try:
        parse_version(version)
    except CompatibilityError as exc:
        raise ExtensionValidationError(str(exc)) from exc

    builder_requires = str(payload["builder_requires"])
    try:
        compatible = compatibility_satisfied(builder_requires, __version__)
    except CompatibilityError as exc:
        raise ExtensionValidationError(str(exc)) from exc
    if not compatible:
        raise ExtensionValidationError(
            f"Extensión incompatible con Builder {__version__}: "
            f"{builder_requires}"
        )

    entry_point = payload.get("entry_point")
    files_raw = payload.get("files", [])
    if extension_type == "plugin":
        if not isinstance(entry_point, str) or ":" not in entry_point:
            raise ExtensionValidationError(
                "Un plugin debe declarar entry_point como módulo:objeto."
            )
    elif not isinstance(files_raw, list) or not files_raw:
        raise ExtensionValidationError(
            "Una plantilla debe declarar una lista no vacía de files."
        )

    files: list[str] = []
    if not isinstance(files_raw, list):
        raise ExtensionValidationError("files debe ser una lista.")
    for item in files_raw:
        if not isinstance(item, str):
            raise ExtensionValidationError(
                "Todos los elementos de files deben ser cadenas."
            )
        relative = validate_relative_path(item)
        if base_dir is not None and not (base_dir / relative).is_file():
            raise ExtensionValidationError(
                f"Archivo declarado inexistente: {relative}"
            )
        files.append(relative)

    dependencies_raw = payload.get("dependencies", {})
    if not isinstance(dependencies_raw, dict):
        raise ExtensionValidationError(
            "dependencies debe ser un objeto nombre:requisito."
        )
    dependencies: dict[str, str] = {}
    for dependency_name, requirement in dependencies_raw.items():
        if not isinstance(dependency_name, str) or not NAME_PATTERN.fullmatch(
            dependency_name
        ):
            raise ExtensionValidationError(
                f"Nombre de dependencia inválido: {dependency_name}"
            )
        if not isinstance(requirement, str):
            raise ExtensionValidationError(
                f"Requisito inválido para {dependency_name}."
            )
        try:
            compatibility_satisfied(requirement, "0.0.0")
        except CompatibilityError:
            # El resultado puede ser falso; aquí solo interesa la sintaxis.
            try:
                compatibility_satisfied(requirement, "999999.0.0")
            except CompatibilityError as exc:
                raise ExtensionValidationError(str(exc)) from exc
        dependencies[dependency_name] = requirement

    return ExtensionManifest(
        schema_version=str(payload["schema_version"]),
        type=extension_type,  # type: ignore[arg-type]
        name=name,
        version=version,
        builder_requires=builder_requires,
        description=str(payload.get("description", "")),
        entry_point=str(entry_point) if entry_point else None,
        files=tuple(files),
        dependencies=dependencies,
    )
