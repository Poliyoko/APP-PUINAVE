"""Motor de generación de componentes SGODA."""

from dataclasses import dataclass
from pathlib import Path

from sgoda.templates import (
    build_api_files,
    build_backend_files,
    build_database_files,
    build_docs_files,
    build_frontend_files,
    build_module_files,
    build_workflow_files,
    normalize_module_name,
)

from .files import FileGenerator
from .registry import register_component


@dataclass(frozen=True, slots=True)
class ComponentGenerationResult:
    component: str
    name: str | None
    written_files: tuple[Path, ...]
    preserved_files: tuple[Path, ...]


class ComponentGenerator:
    """Genera componentes dentro de un proyecto SGODA."""

    SUPPORTED_COMPONENTS = (
        "backend",
        "frontend",
        "database",
        "module",
        "api",
        "workflow",
        "docs",
    )

    NAMED_COMPONENTS = ("module", "api", "workflow", "docs")

    def __init__(self, workspace: Path) -> None:
        self.workspace = workspace

    def generate(
        self,
        component: str,
        *,
        name: str | None = None,
        force: bool = False,
        dry_run: bool = False,
    ) -> ComponentGenerationResult:
        """Genera un componente soportado y lo registra."""
        component = component.strip().lower()

        if component not in self.SUPPORTED_COMPONENTS:
            raise ValueError(f"Componente no soportado: {component}")

        if component in self.NAMED_COMPONENTS and not name:
            raise ValueError(f"El componente {component} requiere --name")

        normalized_name = (
            normalize_module_name(name)
            if component in self.NAMED_COMPONENTS and name
            else None
        )
        files = self._build_files(component, normalized_name)

        results = FileGenerator(self.workspace).create(
            files,
            force=force,
            dry_run=dry_run,
        )

        register_component(
            self.workspace,
            component,
            name=normalized_name,
            dry_run=dry_run,
        )

        return ComponentGenerationResult(
            component=component,
            name=normalized_name,
            written_files=tuple(path for path, written in results if written),
            preserved_files=tuple(
                path for path, written in results if not written
            ),
        )

    @staticmethod
    def _build_files(
        component: str,
        name: str | None,
    ) -> dict[str, str]:
        if component == "backend":
            return build_backend_files()
        if component == "frontend":
            return build_frontend_files()
        if component == "database":
            return build_database_files()
        if component == "module" and name:
            return build_module_files(name)
        if component == "api" and name:
            return build_api_files(name)
        if component == "workflow" and name:
            return build_workflow_files(name)
        if component == "docs" and name:
            return build_docs_files(name)

        raise ValueError(f"No se pudo construir el componente: {component}")
