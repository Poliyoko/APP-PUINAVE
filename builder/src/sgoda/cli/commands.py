"""Implementación de los comandos de la CLI."""
from pathlib import Path
from sgoda import __version__
from sgoda.core import APP_NAME, BuilderConfig, ProjectBuilder
from sgoda.generators import ComponentGenerator
from sgoda.validators import run_doctor, validate_manifest, validate_project

def command_version() -> int:
    print(f"{APP_NAME} {__version__}")
    return 0

def command_doctor(workspace: Path) -> int:
    results = run_doctor(workspace)
    for result in results:
        marker = "OK" if result.success else "ERROR"
        print(f"[{marker}] {result.name}: {result.detail}")
    return 0 if all(r.success for r in results) else 1

def command_init(workspace: Path, *, project_name: str|None=None, force: bool=False, dry_run: bool=False, verbose: bool=False) -> int:
    config = BuilderConfig.from_path(workspace, dry_run=dry_run, verbose=verbose)
    result = ProjectBuilder(config).initialize(project_name=project_name or config.workspace.name, force=force)
    for path in result.written_files:
        print(f"[ARCHIVO GENERADO] {path}")
    print("Proyecto SGODA inicializado correctamente.")
    return 0

def command_validate(workspace: Path) -> int:
    valid, missing = validate_project(workspace)
    if valid:
        print(f"Proyecto SGODA válido: {workspace}")
        return 0
    print(f"Proyecto SGODA incompleto: {workspace}")
    for path in missing: print(f"[FALTA] {path}")
    return 1

def command_generate(component: str, workspace: Path, *, force: bool=False, dry_run: bool=False, verbose: bool=False) -> int:
    valid, detail = validate_manifest(workspace)
    if not valid:
        print(f"[ERROR] Proyecto SGODA inválido: {detail}")
        return 1
    try:
        result = ComponentGenerator(workspace).generate(component, force=force, dry_run=dry_run)
    except ValueError as exc:
        print(f"[ERROR] {exc}")
        return 2
    for path in result.written_files:
        print(f"[ARCHIVO GENERADO] {path}")
    if verbose:
        for path in result.preserved_files:
            print(f"[ARCHIVO CONSERVADO] {path}")
    print("Componente generado correctamente.")
    return 0
