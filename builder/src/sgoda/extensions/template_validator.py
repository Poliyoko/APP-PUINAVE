"""Validación especializada de manifiestos y contenido de plantillas."""

from __future__ import annotations

import json
from pathlib import Path
import re
from typing import Any

from .compatibility import CompatibilityError, requirement_satisfied
from .manager import ExtensionManagerError
from .template_models import TemplateMetadata, TemplateVariable
from .validator import ExtensionValidationError, load_manifest

VARIABLE_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
PLACEHOLDER = re.compile(r"\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}")


class TemplateValidationError(ExtensionValidationError):
    """Plantilla avanzada inválida."""


class TemplateValidator:
    """Valida estructura, variables, compatibilidad y contenido renderizable."""

    MANIFEST_NAME = "sgoda.template.json"

    def validate(
        self,
        source: str | Path,
        *,
        strict_variables: bool = True,
    ) -> TemplateMetadata:
        source_path = Path(source).expanduser().resolve()
        manifest = load_manifest(source_path)
        if manifest.type != "template":
            raise TemplateValidationError(
                f"Se esperaba template, se recibió {manifest.type}."
            )

        root = source_path if source_path.is_dir() else source_path.parent
        manifest_path = root / self.MANIFEST_NAME
        try:
            raw = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as exc:
            raise TemplateValidationError(
                f"Manifiesto de plantilla inválido: {exc}"
            ) from exc

        render_root = raw.get("render_root", ".")
        if not isinstance(render_root, str) or not render_root.strip():
            raise TemplateValidationError(
                "render_root debe ser una ruta relativa no vacía."
            )
        render_path = (root / render_root).resolve()
        try:
            render_path.relative_to(root)
        except ValueError as exc:
            raise TemplateValidationError(
                "render_root no puede salir de la plantilla."
            ) from exc
        if not render_path.is_dir():
            raise TemplateValidationError(
                f"No existe render_root: {render_root}"
            )

        variables = self._parse_variables(raw.get("variables", {}))
        declared = {variable.name for variable in variables}
        used = self._discover_placeholders(render_path)
        undeclared = sorted(used - declared)
        if strict_variables and undeclared:
            raise TemplateValidationError(
                "Variables usadas pero no declaradas: "
                + ", ".join(undeclared)
            )

        try:
            compatible = requirement_satisfied(
                manifest.builder_requires,
                self._builder_version(),
            )
        except CompatibilityError as exc:
            raise TemplateValidationError(str(exc)) from exc
        if not compatible:
            raise TemplateValidationError(
                "La plantilla no es compatible con esta versión del Builder."
            )

        return TemplateMetadata(
            name=manifest.name,
            version=manifest.version,
            builder_requires=manifest.builder_requires,
            description=manifest.description,
            render_root=render_root,
            variables=variables,
            dependencies=dict(manifest.dependencies),
        )

    @staticmethod
    def _builder_version() -> str:
        from sgoda import __version__
        return __version__

    @staticmethod
    def _parse_variables(raw: Any) -> tuple[TemplateVariable, ...]:
        if raw is None:
            return ()
        if not isinstance(raw, dict):
            raise TemplateValidationError(
                "variables debe ser un objeto JSON."
            )
        parsed: list[TemplateVariable] = []
        for name, spec in raw.items():
            if not isinstance(name, str) or not VARIABLE_NAME.fullmatch(name):
                raise TemplateValidationError(
                    f"Nombre de variable inválido: {name}"
                )
            if spec is None:
                spec = {}
            if not isinstance(spec, dict):
                raise TemplateValidationError(
                    f"La variable {name} debe ser un objeto."
                )
            required = spec.get("required", False)
            default = spec.get("default")
            description = spec.get("description", "")
            if not isinstance(required, bool):
                raise TemplateValidationError(
                    f"required debe ser booleano para {name}."
                )
            if default is not None and not isinstance(default, str):
                raise TemplateValidationError(
                    f"default debe ser texto para {name}."
                )
            if not isinstance(description, str):
                raise TemplateValidationError(
                    f"description debe ser texto para {name}."
                )
            if required and default is not None:
                raise TemplateValidationError(
                    f"{name} no puede ser requerida y tener default."
                )
            parsed.append(
                TemplateVariable(
                    name=name,
                    required=required,
                    default=default,
                    description=description,
                )
            )
        return tuple(parsed)

    @staticmethod
    def _discover_placeholders(render_root: Path) -> set[str]:
        variables: set[str] = set()
        for path in sorted(render_root.rglob("*")):
            if not path.is_file():
                continue
            try:
                content = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            variables.update(PLACEHOLDER.findall(content))
            variables.update(PLACEHOLDER.findall(path.name))
        return variables
