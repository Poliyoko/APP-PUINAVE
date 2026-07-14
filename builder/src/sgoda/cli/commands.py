"""Comandos de la CLI."""

from pathlib import Path

from sgoda import __version__
from sgoda.audit import AuditEngine, AuditExportError, render_report, save_report
from sgoda.core import APP_NAME, BuilderConfig, ProjectBuilder
from sgoda.generators import ComponentGenerator
from sgoda.lifecycle import (
    CURRENT_SCHEMA_VERSION,
    MigrationError,
    ProjectMigrator,
    ProjectRepairer,
)
from sgoda.validators import run_doctor, validate_manifest, validate_project


def command_version() -> int:
    print(f"{APP_NAME} {__version__}")
    return 0


def command_doctor(
    workspace: Path,
    *,
    fix: bool = False,
    dry_run: bool = False,
    backup: bool = True,
    output_format: str = "text",
) -> int:
    if fix:
        report = ProjectRepairer(workspace).repair(dry_run=dry_run, backup=backup)
        if output_format == "json":
            import json
            print(json.dumps(report.to_dict(), ensure_ascii=False, indent=2))
        else:
            print(report.to_text())
        return 0
    results = run_doctor(workspace)
    for result in results:
        marker = "OK" if result.success else "ERROR"
        print(f"[{marker}] {result.name}: {result.detail}")
    return 0 if all(result.success for result in results) else 1


def command_init(workspace: Path, project_name: str | None = None) -> int:
    config = BuilderConfig.from_path(workspace)
    ProjectBuilder(config).initialize(
        project_name=project_name or config.workspace.name
    )
    print("Proyecto SGODA inicializado correctamente.")
    return 0


def command_validate(workspace: Path) -> int:
    valid, missing = validate_project(workspace)
    if valid:
        print(f"Proyecto SGODA válido: {workspace}")
        return 0
    for path in missing:
        print(f"[FALTA] {path}")
    return 1


def command_generate(
    component: str,
    workspace: Path,
    *,
    name: str | None = None,
    force: bool = False,
    dry_run: bool = False,
    verbose: bool = False,
) -> int:
    valid, detail = validate_manifest(workspace)
    if not valid:
        print(f"[ERROR] Proyecto SGODA inválido: {detail}")
        return 1

    try:
        result = ComponentGenerator(workspace).generate(
            component,
            name=name,
            force=force,
            dry_run=dry_run,
        )
    except ValueError as exc:
        print(f"[ERROR] {exc}")
        return 2

    print(f"Componente: {result.component}")
    if result.name:
        print(f"Nombre: {result.name}")

    for path in result.written_files:
        marker = "GENERAR" if dry_run else "ARCHIVO GENERADO"
        print(f"[{marker}] {path}")

    if verbose:
        for path in result.preserved_files:
            print(f"[ARCHIVO CONSERVADO] {path}")

    print(
        "Generación simulada."
        if dry_run
        else "Componente generado correctamente."
    )
    return 0


def command_audit(
    workspace: Path,
    *,
    output_format: str = "text",
    output: Path | None = None,
    strict: bool = False,
) -> int:
    """Audita, muestra y opcionalmente guarda el informe."""
    report = AuditEngine().audit(workspace)
    rendered = render_report(report, output_format)

    if output is None:
        print(rendered)
    else:
        try:
            saved_path = save_report(
                report,
                output,
                output_format=output_format,
            )
        except AuditExportError as exc:
            print(f"[ERROR] {exc}")
            return 3
        print(f"Informe guardado: {saved_path}")

    return report.exit_code(strict=strict)


def command_quality(
    workspace: Path,
    *,
    strict: bool = False,
) -> int:
    """Muestra un resumen compacto de calidad."""
    report = AuditEngine().audit(workspace)

    print("Calidad SGODA")
    print(f"Proyecto: {report.workspace}")
    print(f"Puntuación: {report.score}/100")
    print(f"Errores: {report.errors}")
    print(f"Advertencias: {report.warnings}")
    print(f"Estado: {report.status}")

    return report.exit_code(strict=strict)



def command_migrate(
    workspace: Path,
    *,
    target_version: str,
    dry_run: bool = False,
    backup: bool = True,
    output_format: str = "text",
) -> int:
    """Migra un proyecto a una versión específica."""
    try:
        report = ProjectMigrator(workspace).migrate(
            target_version=target_version,
            dry_run=dry_run,
            backup=backup,
        )
    except MigrationError as exc:
        print(f"[ERROR] {exc}")
        return 1

    if output_format == "json":
        import json

        print(
            json.dumps(
                report.to_dict(),
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        print(report.to_text())

    return 0


def command_upgrade(
    workspace: Path,
    *,
    dry_run: bool = False,
    backup: bool = True,
    output_format: str = "text",
) -> int:
    """Actualiza un proyecto al esquema vigente."""
    return command_migrate(
        workspace,
        target_version=CURRENT_SCHEMA_VERSION,
        dry_run=dry_run,
        backup=backup,
        output_format=output_format,
    )
