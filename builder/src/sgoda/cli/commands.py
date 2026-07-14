"""Implementación de los comandos de la CLI."""

from pathlib import Path
from sgoda import __version__
from sgoda.core import APP_NAME, BuilderConfig, ProjectBuilder
from sgoda.validators import run_doctor, validate_project


def command_version() -> int:
    print(f"{APP_NAME} {__version__}")
    return 0


def command_doctor(workspace: Path) -> int:
    results = run_doctor(workspace)
    for result in results:
        marker = "OK" if result.success else "ERROR"
        print(f"[{marker}] {result.name}: {result.detail}")
    return 0 if all(result.success for result in results) else 1


def command_init(workspace: Path, *, project_name: str | None = None, force: bool = False, dry_run: bool = False, verbose: bool = False) -> int:
    config = BuilderConfig.from_path(workspace, dry_run=dry_run, verbose=verbose)
    resolved_name = project_name or config.workspace.name
    result = ProjectBuilder(config).initialize(project_name=resolved_name, force=force)
    print(f"Proyecto: {resolved_name}")
    print(f"Destino: {result.workspace}")
    if verbose:
        for path in result.created_directories:
            print(f"[DIRECTORIO CREADO] {path}")
        for path in result.existing_directories:
            print(f"[DIRECTORIO EXISTENTE] {path}")
    for path in result.written_files:
        marker = "GENERAR" if dry_run else "ARCHIVO GENERADO"
        print(f"[{marker}] {path}")
    for path in result.preserved_files:
        print(f"[ARCHIVO CONSERVADO] {path}")
    print("Inicialización simulada." if dry_run else "Proyecto SGODA inicializado correctamente.")
    return 0


def command_validate(workspace: Path) -> int:
    valid, missing = validate_project(workspace)
    if valid:
        print(f"Proyecto SGODA válido: {workspace}")
        return 0
    print(f"Proyecto SGODA incompleto: {workspace}")
    for path in missing:
        print(f"[FALTA] {path}")
    return 1
