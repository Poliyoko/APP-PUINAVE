from pathlib import Path
from sgoda import __version__
from sgoda.core import APP_NAME, BuilderConfig, ProjectBuilder
from sgoda.validators import run_doctor, validate_project

def command_version() -> int:
    print(f"{APP_NAME} {__version__}")
    return 0

def command_doctor(workspace: Path) -> int:
    failed=False
    for r in run_doctor(workspace):
        print(f"[{'OK' if r.success else 'ERROR'}] {r.name}: {r.detail}")
        failed = failed or not r.success
    return 1 if failed else 0

def command_init(workspace: Path, *, dry_run: bool=False, verbose: bool=False) -> int:
    builder=ProjectBuilder(BuilderConfig.from_path(workspace, dry_run=dry_run, verbose=verbose))
    for path, created in builder.initialize():
        if verbose or created:
            print(f"[{'CREADO' if created else 'EXISTE'}] {path}")
    return 0

def command_validate(workspace: Path) -> int:
    valid, missing=validate_project(workspace)
    if valid:
        print(f"Proyecto SGODA válido: {workspace}")
        return 0
    for path in missing:
        print(f"[FALTA] {path}")
    return 1
