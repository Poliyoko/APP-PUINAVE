"""Motor de generación de componentes SGODA."""
from dataclasses import dataclass
from pathlib import Path
from sgoda.templates import build_backend_files
from .files import FileGenerator

@dataclass(frozen=True, slots=True)
class ComponentGenerationResult:
    component: str
    workspace: Path
    written_files: tuple[Path, ...]
    preserved_files: tuple[Path, ...]

class ComponentGenerator:
    SUPPORTED_COMPONENTS = ("backend",)

    def __init__(self, workspace: Path) -> None:
        self.workspace = workspace
        self.file_generator = FileGenerator(workspace)

    def generate(self, component: str, *, force: bool=False, dry_run: bool=False) -> ComponentGenerationResult:
        normalized = component.strip().lower()
        if normalized not in self.SUPPORTED_COMPONENTS:
            supported = ", ".join(self.SUPPORTED_COMPONENTS)
            raise ValueError(f"Componente no soportado: {component}. Componentes disponibles: {supported}")
        files = build_backend_files()
        results = self.file_generator.create(files, force=force, dry_run=dry_run)
        return ComponentGenerationResult(
            component=normalized,
            workspace=self.workspace,
            written_files=tuple(p for p,w in results if w),
            preserved_files=tuple(p for p,w in results if not w),
        )
