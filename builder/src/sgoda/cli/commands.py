"""Comandos de la CLI."""

from pathlib import Path

from sgoda import __version__
from sgoda.audit import AuditEngine, AuditExportError, render_report, save_report
from sgoda.core import APP_NAME, BuilderConfig, ProjectBuilder
from sgoda.generators import ComponentGenerator
from sgoda.extensions import (
    BundleService,
    BundleServiceError,
    ConsolidatedReportService,
    ExportService,
    ExportServiceError,
    ImportService,
    ImportServiceError,
    CatalogService,
    CatalogServiceError,
    ExtensionManager,
    ExtensionManagerError,
    ExtensionValidationError,
    PluginDoctor,
    PluginStateService,
    PluginIntegrityService,
    PluginUpdateError,
    PluginUpdater,
    TemplateDoctor,
    TemplateStateService,
    TemplateValidationError,
    TemplateValidator,
    TemplateIntegrityService,
    TemplateUpdateError,
    TemplateUpdater,
    TemplateVersionService,
)
from sgoda.operations import (
    HistoryService,
    HistoryStoreError,
    OperationCollectionError,
    history_to_json,
    history_to_text,
    record_event_safely,
    render_executive_report,
    render_status,
    save_executive_report,
    ExecutiveReportExportError,
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
        if not dry_run:
            record_event_safely(
                workspace,
                "project_repaired",
                details={
                    "status": report.status,
                    "backup_path": (
                        str(report.backup_path)
                        if report.backup_path
                        else None
                    ),
                    "actions": len(report.actions),
                },
            )
        return 0
    results = run_doctor(workspace)
    for result in results:
        marker = "OK" if result.success else "ERROR"
        print(f"[{marker}] {result.name}: {result.detail}")
    return 0 if all(result.success for result in results) else 1


def command_init(workspace: Path, project_name: str | None = None) -> int:
    config = BuilderConfig.from_path(workspace)
    resolved_name = project_name or config.workspace.name
    ProjectBuilder(config).initialize(project_name=resolved_name)
    record_event_safely(
        config.workspace,
        "project_initialized",
        details={"project_name": resolved_name},
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
    if not dry_run:
        record_event_safely(
            workspace,
            "component_generated",
            details={
                "component": result.component,
                "name": result.name,
                "written_files": len(result.written_files),
                "preserved_files": len(result.preserved_files),
                "force": force,
            },
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

    exit_code = report.exit_code(strict=strict)
    record_event_safely(
        workspace,
        "audit_executed",
        details={
            "status": report.status,
            "score": report.score,
            "errors": report.errors,
            "warnings": report.warnings,
            "strict": strict,
            "exit_code": exit_code,
            "output_format": output_format,
        },
    )
    return exit_code


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

    exit_code = report.exit_code(strict=strict)
    record_event_safely(
        workspace,
        "quality_executed",
        details={
            "status": report.status,
            "score": report.score,
            "errors": report.errors,
            "warnings": report.warnings,
            "strict": strict,
            "exit_code": exit_code,
        },
    )
    return exit_code



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

    if not dry_run:
        record_event_safely(
            workspace,
            "project_migrated",
            details={
                "source_version": report.source_version,
                "target_version": report.target_version,
                "status": report.status,
                "changed": report.changed,
                "steps": len(report.steps),
                "backup_path": (
                    str(report.backup_path)
                    if report.backup_path
                    else None
                ),
            },
        )
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

    if result.status in {"INSTALLED", "UPDATED"}:
        event_type = (
            "plugin_installed"
            if extension_type == "plugin"
            else "template_installed"
        )
        record_event_safely(
            workspace,
            event_type,
            details={
                "name": result.manifest.name,
                "version": result.manifest.version,
                "status": result.status,
                "installed_path": str(result.installed_path),
                "force": force,
            },
        )
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
    record_event_safely(
        workspace,
        (
            "plugin_removed"
            if extension_type == "plugin"
            else "template_removed"
        ),
        details={"name": name},
    )
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
    record_event_safely(
        workspace,
        "template_rendered",
        details={
            "name": name,
            "destination": str(destination.expanduser().resolve()),
            "written_files": len(result.written_files),
            "preserved_files": len(result.preserved_files),
            "force": force,
            "variables": sorted(values),
        },
    )
    return 0


def command_status(
    workspace: Path,
    *,
    output_format: str = "text",
    detailed: bool = False,
) -> int:
    """Muestra la instantánea operacional consolidada."""
    try:
        rendered = render_status(
            workspace,
            output_format=output_format,
            detailed=detailed,
        )
    except (OperationCollectionError, ValueError) as exc:
        print(f"[ERROR] {exc}")
        return 1
    print(rendered)
    record_event_safely(
        workspace,
        "status_collected",
        details={
            "output_format": output_format,
            "detailed": detailed,
        },
    )
    return 0


def command_history(
    workspace: Path,
    *,
    event_type: str | None = None,
    since: str | None = None,
    limit: int | None = None,
    output_format: str = "text",
    record_status: bool = False,
) -> int:
    """Consulta el historial persistente del proyecto."""
    service = HistoryService(workspace)
    try:
        if record_status:
            service.record("status_collected")
        events = service.list(
            event_type=event_type,
            since=since,
            limit=limit,
        )
    except (
        HistoryStoreError,
        OperationCollectionError,
        ValueError,
    ) as exc:
        print(f"[ERROR] {exc}")
        return 1

    if output_format == "json":
        print(history_to_json(events))
    else:
        print(history_to_text(workspace, events))
    return 0



def command_report(
    workspace: Path,
    *,
    output_format: str = "markdown",
    output: Path | None = None,
    include_history: bool = True,
    history_limit: int = 20,
    profile: str = "executive",
    sections: tuple[str, ...] | None = None,
) -> int:
    """Genera el reporte ejecutivo consolidado."""
    try:
        rendered = render_executive_report(
            workspace,
            output_format=output_format,
            include_history=include_history,
            history_limit=history_limit,
            profile=profile,
            sections=sections,
        )
        saved_path = None
        if output is not None:
            saved_path = save_executive_report(
                rendered,
                output,
                output_format=output_format,
            )
    except (
        OperationCollectionError,
        HistoryStoreError,
        ExecutiveReportExportError,
        ValueError,
    ) as exc:
        print(f"[ERROR] {exc}")
        return 1

    print(rendered)
    if saved_path is not None:
        print(f"Reporte guardado: {saved_path}")

    record_event_safely(
        workspace,
        "executive_report_generated",
        details={
            "format": output_format,
            "include_history": include_history,
            "history_limit": history_limit,
            "profile": profile,
            "sections": list(sections or ()),
            "output": str(saved_path) if saved_path else None,
        },
    )
    return 0



def command_plugin_state(
    workspace: Path,
    name: str,
    *,
    enabled: bool,
    output_format: str = "text",
) -> int:
    try:
        result = PluginStateService(workspace).set_enabled(name, enabled)
    except ExtensionManagerError as exc:
        print(f"[ERROR] {exc}")
        return 1

    if output_format == "json":
        import json
        print(json.dumps({
            "name": result.name,
            "enabled": result.enabled,
            "status": result.status,
            "changed": result.changed,
        }, ensure_ascii=False, indent=2))
    else:
        action = "habilitado" if result.enabled else "deshabilitado"
        suffix = "" if result.changed else " (sin cambios)"
        print(f"Plugin {result.name} {action}{suffix}.")

    if result.changed:
        record_event_safely(
            workspace,
            "plugin_enabled" if enabled else "plugin_disabled",
            details={
                "name": result.name,
                "status": result.status,
            },
        )
    return 0


def command_plugin_doctor(
    workspace: Path,
    *,
    output_format: str = "text",
) -> int:
    report = PluginDoctor(workspace).run()
    print(report.to_json() if output_format == "json" else report.to_text())
    record_event_safely(
        workspace,
        "plugin_ecosystem_diagnosed",
        details={
            "status": report.status,
            "installed": report.installed,
            "dependency_issues": len(report.dependency_issues),
            "cycles": len(report.cycles),
            "integrity_failures": report.integrity_failures,
            "untracked_integrity": report.untracked_integrity,
        },
    )
    return 0 if report.status == "HEALTHY" else 1



def command_plugin_update(
    workspace: Path,
    name: str,
    source: Path,
    *,
    backup: bool = True,
    allow_downgrade: bool = False,
    output_format: str = "text",
) -> int:
    try:
        result = PluginUpdater(workspace).update(
            name,
            source,
            backup=backup,
            allow_downgrade=allow_downgrade,
        )
    except PluginUpdateError as exc:
        print(f"[ERROR] {exc}")
        record_event_safely(
            workspace,
            "plugin_update_failed",
            details={
                "name": name,
                "source": str(source),
                "reason": str(exc),
            },
        )
        return 1

    if output_format == "json":
        import json
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(
            f"Plugin actualizado: {result.name} "
            f"{result.previous_version} -> {result.version}"
        )
        print(f"Ruta: {result.installed_path}")
        if result.backup_path is not None:
            print(f"Respaldo: {result.backup_path}")

    record_event_safely(
        workspace,
        "plugin_updated",
        details=result.to_dict(),
    )
    return 0



def command_plugin_integrity(
    workspace: Path,
    name: str,
    *,
    refresh: bool = False,
    output_format: str = "text",
) -> int:
    try:
        service = PluginIntegrityService(workspace)
        result = (
            service.refresh(name)
            if refresh
            else service.verify(name)
        )
    except ExtensionManagerError as exc:
        print(f"[ERROR] {exc}")
        return 1

    if output_format == "json":
        import json
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        print("Integridad de Plugin")
        print("-" * 60)
        print(f"Plugin: {result.name}")
        print(f"Estado: {result.status}")
        print(f"Seguimiento: {'sí' if result.tracked else 'no'}")
        print(f"Modificados: {len(result.modified_files)}")
        print(f"Faltantes: {len(result.missing_files)}")
        print(f"Agregados: {len(result.added_files)}")

    event_type = (
        "plugin_integrity_checked"
        if result.status == "HEALTHY"
        else "plugin_integrity_failed"
    )
    record_event_safely(
        workspace,
        event_type,
        details=result.to_dict(),
    )
    return 0 if result.status == "HEALTHY" else 1



def command_template_state(
    workspace: Path,
    name: str,
    *,
    enabled: bool,
    output_format: str = "text",
) -> int:
    try:
        result = TemplateStateService(workspace).set_enabled(name, enabled)
    except ExtensionManagerError as exc:
        print(f"[ERROR] {exc}")
        return 1

    if output_format == "json":
        import json
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        action = "habilitada" if result.enabled else "deshabilitada"
        suffix = "" if result.changed else " (sin cambios)"
        print(f"Plantilla {result.name} {action}{suffix}.")

    if result.changed:
        record_event_safely(
            workspace,
            "template_enabled" if enabled else "template_disabled",
            details={
                "name": result.name,
                "status": result.status,
            },
        )
    return 0


def command_template_doctor(
    workspace: Path,
    *,
    output_format: str = "text",
) -> int:
    report = TemplateDoctor(workspace).run()
    print(report.to_json() if output_format == "json" else report.to_text())
    record_event_safely(
        workspace,
        "template_ecosystem_diagnosed",
        details={
            "status": report.status,
            "installed": report.installed,
            "invalid": report.invalid,
            "incompatible": report.incompatible,
            "integrity_failures": report.integrity_failures,
        },
    )
    return 0 if report.status == "HEALTHY" else 1


def command_template_validate_advanced(
    source: Path,
    *,
    output_format: str = "text",
) -> int:
    try:
        metadata = TemplateValidator().validate(source)
    except TemplateValidationError as exc:
        print(f"[ERROR] {exc}")
        return 1

    if output_format == "json":
        import json
        print(json.dumps(metadata.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(f"[OK] template:{metadata.name} {metadata.version}")
        print(f"Render root: {metadata.render_root}")
        print(f"Variables: {len(metadata.variables)}")
    return 0


def command_template_update(workspace: Path,name: str,source: Path,*,backup: bool=True,allow_downgrade: bool=False,output_format: str='text')->int:
    try:
        result=TemplateUpdater(workspace).update(name,source,backup=backup,allow_downgrade=allow_downgrade)
    except TemplateUpdateError as exc:
        print(f'[ERROR] {exc}')
        record_event_safely(workspace,'template_update_failed',details={'name':name,'source':str(source),'reason':str(exc)})
        return 1
    if output_format=='json':
        import json; print(json.dumps(result.to_dict(),ensure_ascii=False,indent=2))
    else:
        print(f'Plantilla actualizada: {result.name} {result.previous_version} -> {result.version}')
        print(f'Ruta: {result.installed_path}')
        if result.backup_path: print(f'Respaldo: {result.backup_path}')
    record_event_safely(workspace,'template_updated',details=result.to_dict())
    return 0

def command_template_versions(workspace: Path,name: str,*,output_format: str='text')->int:
    backups=TemplateVersionService(workspace).list_backups(name)
    if output_format=='json':
        import json; print(json.dumps({'name':name,'count':len(backups),'backups':[x.to_dict() for x in backups]},ensure_ascii=False,indent=2))
    else:
        print('Versiones de Plantilla'); print('-'*60); print(f'Plantilla: {name}')
        for item in backups: print(f'- {item.version}: {item.path}')
        print('-'*60); print(f'Respaldos: {len(backups)}')
    return 0



def command_template_integrity(
    workspace: Path,
    name: str,
    *,
    refresh: bool = False,
    output_format: str = "text",
) -> int:
    try:
        service = TemplateIntegrityService(workspace)
        result = service.refresh(name) if refresh else service.verify(name)
    except ExtensionManagerError as exc:
        print(f"[ERROR] {exc}")
        return 1

    if output_format == "json":
        import json
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        print("Integridad de Plantilla")
        print("-" * 60)
        print(f"Plantilla: {result.name}")
        print(f"Estado: {result.status}")
        print(f"Seguimiento: {'sí' if result.tracked else 'no'}")
        print(f"Modificados: {len(result.modified_files)}")
        print(f"Faltantes: {len(result.missing_files)}")
        print(f"Agregados: {len(result.added_files)}")

    event_type = (
        "template_integrity_checked"
        if result.status == "HEALTHY"
        else "template_integrity_failed"
    )
    record_event_safely(
        workspace,
        event_type,
        details=result.to_dict(),
    )
    return 0 if result.status == "HEALTHY" else 1



def command_catalog_rebuild(
    workspace: Path,
    *,
    output_format: str = "text",
) -> int:
    from sgoda.extensions.catalog_serializers import snapshot_to_json

    snapshot = CatalogService(workspace).rebuild()
    if output_format == "json":
        print(snapshot_to_json(snapshot))
    else:
        stats = snapshot.statistics()
        print("Catálogo SGODA reconstruido")
        print(f"Elementos: {stats['total']}")
        print(f"Plugins: {stats['plugins']}")
        print(f"Plantillas: {stats['templates']}")
        print(f"Errores: {stats['errors']}")
    record_event_safely(
        workspace,
        "catalog_rebuilt",
        details=snapshot.statistics(),
    )
    return 0 if not snapshot.errors else 1


def command_catalog_list(
    workspace: Path,
    *,
    extension_type: str | None = None,
    output_format: str = "text",
) -> int:
    from sgoda.extensions.catalog_serializers import entries_to_json, entries_to_text

    entries = CatalogService(workspace).list(extension_type)
    print(entries_to_json(entries) if output_format == "json" else entries_to_text(entries))
    return 0


def command_catalog_search(
    workspace: Path,
    query: str,
    *,
    extension_type: str | None = None,
    output_format: str = "text",
) -> int:
    from sgoda.extensions.catalog_serializers import entries_to_json, entries_to_text

    entries = CatalogService(workspace).search(query, extension_type=extension_type)
    print(entries_to_json(entries) if output_format == "json" else entries_to_text(entries))
    record_event_safely(
        workspace,
        "catalog_searched",
        details={
            "query": query,
            "type": extension_type,
            "results": len(entries),
        },
    )
    return 0


def command_catalog_info(
    workspace: Path,
    name: str,
    *,
    extension_type: str | None = None,
    output_format: str = "text",
) -> int:
    try:
        entry = CatalogService(workspace).info(
            name,
            extension_type=extension_type,
        )
    except CatalogServiceError as exc:
        print(f"[ERROR] {exc}")
        return 1

    if output_format == "json":
        import json
        print(json.dumps(entry.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(f"{entry.type}:{entry.name}")
        print(f"Versión: {entry.version}")
        print(f"Estado: {entry.status}")
        print(f"Habilitado: {entry.enabled}")
        print(f"Ruta: {entry.location}")
    record_event_safely(
        workspace,
        "catalog_info",
        details={"name": name, "type": extension_type},
    )
    return 0



def command_bundle_create(
    workspace: Path,
    name: str,
    selectors: list[str],
    *,
    include_all: bool = False,
    description: str = "",
    force: bool = False,
    output_format: str = "text",
) -> int:
    import json
    try:
        bundle = BundleService(workspace).create(
            name,
            selectors,
            include_all=include_all,
            description=description,
            force=force,
        )
    except BundleServiceError as exc:
        print(f"[ERROR] {exc}")
        return 1
    if output_format == "json":
        print(json.dumps(bundle.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(f"Bundle creado: {bundle.name}")
        print(f"Extensiones: {len(bundle.items)}")
    record_event_safely(
        workspace,
        "bundle_created",
        details={"bundle": bundle.name, "items": len(bundle.items)},
    )
    return 0


def command_bundle_list(
    workspace: Path,
    *,
    output_format: str = "text",
) -> int:
    from sgoda.extensions.bundle_serializers import bundles_to_json, bundles_to_text
    bundles = BundleService(workspace).list()
    print(bundles_to_json(bundles) if output_format == "json" else bundles_to_text(bundles))
    return 0


def command_bundle_info(
    workspace: Path,
    name: str,
    *,
    output_format: str = "text",
) -> int:
    import json
    try:
        bundle = BundleService(workspace).info(name)
    except BundleServiceError as exc:
        print(f"[ERROR] {exc}")
        return 1
    if output_format == "json":
        print(json.dumps(bundle.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(f"Bundle: {bundle.name}")
        print(f"Descripción: {bundle.description}")
        print(f"Extensiones: {len(bundle.items)}")
        for item in bundle.items:
            print(f"- {item.key} {item.version}")
    return 0


def command_bundle_execute(
    workspace: Path,
    name: str,
    action: str,
    *,
    dry_run: bool = False,
    output_format: str = "text",
) -> int:
    from sgoda.extensions.bundle_serializers import result_to_json, result_to_text
    try:
        result = BundleService(workspace).execute(
            name,
            action,
            dry_run=dry_run,
        )
    except BundleServiceError as exc:
        print(f"[ERROR] {exc}")
        return 1
    print(result_to_json(result) if output_format == "json" else result_to_text(result))
    event = "bundle_planned" if dry_run else f"bundle_{action}d"
    if action == "enable":
        event = "bundle_enabled"
    elif action == "disable":
        event = "bundle_disabled"
    elif action == "install":
        event = "bundle_installed"
    elif action == "update":
        event = "bundle_updated"
    elif action == "uninstall":
        event = "bundle_uninstalled"
    record_event_safely(
        workspace,
        event,
        details={
            "bundle": name,
            "status": result.status,
            "rolled_back": result.rolled_back,
            "operations": len(result.operations),
        },
    )
    return 0 if result.status in {"COMPLETED", "PLANNED"} else 1



def command_export_create(workspace: Path, output: Path) -> int:
    try:
        result = ExportService(workspace).create(output)
    except ExportServiceError as exc:
        print(f"[ERROR] {exc}")
        return 1
    print(f"Paquete SGODA creado: {result}")
    record_event_safely(
        workspace, "export_created", details={"package": str(result)}
    )
    return 0


def command_export_verify(workspace: Path, package: Path, output_format: str = "text") -> int:
    import json
    result = ExportService(workspace).verify(package)
    print(
        json.dumps(result, ensure_ascii=False, indent=2)
        if output_format == "json"
        else (
            f"Paquete: {result['package']}\n"
            f"Válido: {'sí' if result['valid'] else 'no'}\n"
            f"Archivos: {result['files']}\n"
            + ("\n".join(result["errors"]) if result["errors"] else "")
        )
    )
    record_event_safely(
        workspace, "export_verified",
        details={"package": str(package), "valid": result["valid"]}
    )
    return 0 if result["valid"] else 1


def command_import_package(
    workspace: Path,
    package: Path,
    *,
    replace: bool = False,
    dry_run: bool = False,
    output_format: str = "text",
) -> int:
    import json
    try:
        result = ImportService(workspace).import_package(
            package, replace=replace, dry_run=dry_run
        )
    except ImportServiceError as exc:
        print(f"[ERROR] {exc}")
        return 1
    print(
        json.dumps(result, ensure_ascii=False, indent=2)
        if output_format == "json"
        else (
            f"Estado: {result['status']}\n"
            f"Paquete: {result['package']}\n"
            f"Archivos: {result['files']}"
        )
    )
    record_event_safely(
        workspace,
        "import_planned" if dry_run else "import_completed",
        details=result,
    )
    return 0


def command_import_verify(workspace: Path, package: Path, output_format: str = "text") -> int:
    import json
    result = ImportService(workspace).verify(package)
    print(
        json.dumps(result, ensure_ascii=False, indent=2)
        if output_format == "json"
        else f"Válido: {'sí' if result['valid'] else 'no'} | Archivos: {result['files']}"
    )
    record_event_safely(
        workspace, "import_verified",
        details={"package": str(package), "valid": result["valid"]}
    )
    return 0 if result["valid"] else 1


def command_report_consolidated(
    workspace: Path,
    *,
    output_format: str = "markdown",
    output: Path | None = None,
    history_limit: int = 20,
) -> int:
    service = ConsolidatedReportService(workspace)
    payload = service.collect(history_limit=history_limit)
    if output is None:
        print(service.render(payload, output_format))
        saved = None
    else:
        saved = service.save(
            output, output_format=output_format, history_limit=history_limit
        )
        print(f"Reporte consolidado guardado: {saved}")
    record_event_safely(
        workspace, "report_consolidated_generated",
        details={"format": output_format, "output": str(saved) if saved else None}
    )
    return 0
