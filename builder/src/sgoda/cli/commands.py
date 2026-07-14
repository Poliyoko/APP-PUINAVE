"""Comandos de la CLI."""

from pathlib import Path

from sgoda import __version__
from sgoda.audit import AuditEngine, AuditExportError, render_report, save_report
from sgoda.core import APP_NAME, BuilderConfig, ProjectBuilder
from sgoda.generators import ComponentGenerator
from sgoda.extensions import (
    ExtensionManager,
    ExtensionManagerError,
    ExtensionValidationError,
)
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



def _extension_output(records, output_format: str) -> None:
    if output_format == "json":
        import json
        print(json.dumps(
            [record.to_dict() for record in records],
            ensure_ascii=False,
            indent=2,
        ))
        return
    if not records:
        print("No hay extensiones registradas.")
        return
    for record in records:
        print(
            f"{record.type}:{record.name} "
            f"{record.version} [{record.installed_path}]"
        )


def command_extension_list(
    workspace: Path,
    *,
    extension_type: str,
    output_format: str = "text",
) -> int:
    records = ExtensionManager(workspace).list(extension_type)
    _extension_output(records, output_format)
    return 0


def command_extension_validate(
    workspace: Path,
    source: Path,
    *,
    extension_type: str,
    output_format: str = "text",
) -> int:
    try:
        manifest = ExtensionManager(workspace).validate(
            source,
            expected_type=extension_type,
        )
    except (ExtensionValidationError, ExtensionManagerError) as exc:
        print(f"[ERROR] {exc}")
        return 1
    if output_format == "json":
        import json
        print(json.dumps(manifest.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(f"[OK] {manifest.type}:{manifest.name} {manifest.version}")
    return 0


def command_extension_install(
    workspace: Path,
    source: Path,
    *,
    extension_type: str,
    force: bool = False,
    output_format: str = "text",
) -> int:
    try:
        result = ExtensionManager(workspace).install(
            source,
            expected_type=extension_type,
            force=force,
        )
    except (
        ExtensionValidationError,
        ExtensionManagerError,
    ) as exc:
        print(f"[ERROR] {exc}")
        return 1
    if output_format == "json":
        import json
        print(json.dumps({
            "status": result.status,
            "extension": result.manifest.to_dict(),
            "installed_path": str(result.installed_path),
        }, ensure_ascii=False, indent=2))
    else:
        print(f"Estado: {result.status}")
        print(
            f"Extensión: {result.manifest.type}:"
            f"{result.manifest.name}"
        )
        print(f"Ruta: {result.installed_path}")
    return 0


def command_extension_info(
    workspace: Path,
    name: str,
    *,
    extension_type: str,
    output_format: str = "text",
) -> int:
    try:
        record = ExtensionManager(workspace).info(extension_type, name)
    except ExtensionManagerError as exc:
        print(f"[ERROR] {exc}")
        return 1
    if output_format == "json":
        import json
        print(json.dumps(record.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(f"{record.type}:{record.name}")
        print(f"Versión: {record.version}")
        print(f"Ruta: {record.installed_path}")
        print(f"Habilitado: {record.enabled}")
    return 0


def command_extension_remove(
    workspace: Path,
    name: str,
    *,
    extension_type: str,
) -> int:
    removed = ExtensionManager(workspace).remove(extension_type, name)
    if not removed:
        print(f"[ERROR] No existe {extension_type}:{name}.")
        return 1
    print(f"Extensión eliminada: {extension_type}:{name}")
    return 0


def command_template_render(
    workspace: Path,
    name: str,
    destination: Path,
    *,
    variables: list[str] | None = None,
    force: bool = False,
) -> int:
    values: dict[str, str] = {}
    for item in variables or []:
        if "=" not in item:
            print(f"[ERROR] Variable inválida: {item}")
            return 2
        key, value = item.split("=", 1)
        values[key] = value
    try:
        result = ExtensionManager(workspace).render_template(
            name,
            destination,
            variables=values,
            force=force,
        )
    except (ExtensionManagerError, ExtensionValidationError) as exc:
        print(f"[ERROR] {exc}")
        return 1
    for path in result.written_files:
        print(f"[ARCHIVO GENERADO] {path}")
    for path in result.preserved_files:
        print(f"[ARCHIVO CONSERVADO] {path}")
    print("Plantilla renderizada correctamente.")
    return 0
