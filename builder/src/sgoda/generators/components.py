"""Generador inteligente de componentes."""

from dataclasses import dataclass
from pathlib import Path

from sgoda.templates import (
    build_backend_files,
    build_database_files,
    build_frontend_files,
    build_module_files,
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
    SUPPORTED_COMPONENTS = ("backend", "frontend", "database", "module")

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
        component = component.lower()

        if component not in self.SUPPORTED_COMPONENTS:
            raise ValueError(f"Componente no soportado: {component}")

        if component == "module" and not name:
            raise ValueError("El componente module requiere --name")

        normalized_name = (
            normalize_module_name(name)
            if component == "module" and name
            else name
        )

        builders = {
            "backend": build_backend_files,
            "frontend": build_frontend_files,
            "database": build_database_files,
        }
        files = (
            build_module_files(normalized_name)
            if component == "module" and normalized_name
            else builders[component]()
        )

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
            component,
            normalized_name,
            tuple(path for path, written in results if written),
            tuple(path for path, written in results if not written),
        )
