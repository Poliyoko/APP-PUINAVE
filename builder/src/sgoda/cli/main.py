"""CLI del SGODA Project Builder."""

import argparse
from collections.abc import Sequence
from pathlib import Path

from sgoda.generators import ComponentGenerator

from .commands import (
    command_audit,
    command_bundle_create,
    command_bundle_execute,
    command_bundle_info,
    command_bundle_list,
    command_catalog_info,
    command_catalog_list,
    command_catalog_rebuild,
    command_catalog_search,
    command_doctor,
    command_generate,
    command_history,
    command_export_create,
    command_export_verify,
    command_import_package,
    command_import_verify,
    command_report_consolidated,
    command_repo_add,
    command_repo_info,
    command_repo_list,
    command_repo_remove,
    command_repo_set_enabled,
    command_extension_info,
    command_extension_install,
    command_extension_list,
    command_extension_remove,
    command_extension_validate,
    command_template_render,
    command_template_doctor,
    command_template_integrity,
    command_template_state,
    command_template_validate_advanced,
    command_template_update,
    command_template_versions,
    command_init,
    command_quality,
    command_plugin_doctor,
    command_plugin_integrity,
    command_plugin_state,
    command_plugin_update,
    command_report,
    command_status,
    command_migrate,
    command_upgrade,
    command_validate,
    command_version,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="sgoda")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("version")

    doctor = subparsers.add_parser("doctor")
    doctor.add_argument("workspace", nargs="?", default=".")
    doctor.add_argument("--fix", action="store_true")
    doctor.add_argument("--dry-run", action="store_true")
    doctor.add_argument("--no-backup", action="store_true")
    doctor.add_argument("--format", choices=("text", "json"), default="text", dest="output_format")

    init = subparsers.add_parser("init")
    init.add_argument("workspace", nargs="?", default=".")
    init.add_argument("--project-name")

    validate = subparsers.add_parser("validate")
    validate.add_argument("workspace", nargs="?", default=".")

    generate = subparsers.add_parser("generate")
    generate.add_argument(
        "component",
        choices=ComponentGenerator.SUPPORTED_COMPONENTS,
    )
    generate.add_argument("workspace", nargs="?", default=".")
    generate.add_argument("--name")
    generate.add_argument("--force", action="store_true")
    generate.add_argument("--dry-run", action="store_true")
    generate.add_argument("--verbose", action="store_true")

    audit = subparsers.add_parser(
        "audit",
        help="Audita un proyecto SGODA.",
    )
    audit.add_argument("workspace", nargs="?", default=".")
    audit.add_argument(
        "--format",
        choices=("text", "json", "markdown"),
        default="text",
        dest="output_format",
    )
    audit.add_argument("--output", type=Path)
    audit.add_argument("--strict", action="store_true")

    quality = subparsers.add_parser(
        "quality",
        help="Muestra el resumen de calidad del proyecto.",
    )
    quality.add_argument("workspace", nargs="?", default=".")
    quality.add_argument("--strict", action="store_true")

    upgrade = subparsers.add_parser(
        "upgrade",
        help="Actualiza un proyecto al esquema SGODA vigente.",
    )
    upgrade.add_argument("workspace", nargs="?", default=".")
    upgrade.add_argument("--dry-run", action="store_true")
    upgrade.add_argument("--no-backup", action="store_true")
    upgrade.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        dest="output_format",
    )

    migrate = subparsers.add_parser(
        "migrate",
        help="Migra un proyecto a una versión de esquema.",
    )
    migrate.add_argument("workspace", nargs="?", default=".")
    migrate.add_argument("--to", required=True, dest="target_version")
    migrate.add_argument("--dry-run", action="store_true")
    migrate.add_argument("--no-backup", action="store_true")
    migrate.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        dest="output_format",
    )

    status = subparsers.add_parser(
        "status",
        help="Muestra el estado operativo consolidado del proyecto.",
    )
    status.add_argument("workspace", nargs="?", default=".")
    status.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        dest="output_format",
    )
    status.add_argument("--detailed", action="store_true")

    history = subparsers.add_parser(
        "history",
        help="Consulta el historial persistente de eventos del proyecto.",
    )
    history.add_argument("workspace", nargs="?", default=".")
    history.add_argument("--type", dest="event_type")
    history.add_argument("--since")
    history.add_argument("--limit", type=int)
    history.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        dest="output_format",
    )
    history.add_argument("--record-status", action="store_true")

    repo = subparsers.add_parser("repo", help="Administra repositorios remotos.")
    repo_actions = repo.add_subparsers(dest="repo_action")

    repo_add = repo_actions.add_parser("add")
    repo_add.add_argument("name")
    repo_add.add_argument("url")
    repo_add.add_argument("--workspace", default=".")
    repo_add.add_argument("--priority", type=int, default=100)
    repo_add.add_argument("--trusted", action="store_true")
    repo_add.add_argument("--disabled", action="store_true")
    repo_add.add_argument("--force", action="store_true")
    repo_add.add_argument("--format", choices=("text", "json"), default="text", dest="output_format")

    repo_remove = repo_actions.add_parser("remove")
    repo_remove.add_argument("name")
    repo_remove.add_argument("--workspace", default=".")

    repo_list = repo_actions.add_parser("list")
    repo_list.add_argument("--workspace", default=".")
    repo_list.add_argument("--enabled-only", action="store_true")
    repo_list.add_argument("--format", choices=("text", "json"), default="text", dest="output_format")

    repo_info = repo_actions.add_parser("info")
    repo_info.add_argument("name")
    repo_info.add_argument("--workspace", default=".")
    repo_info.add_argument("--format", choices=("text", "json"), default="text", dest="output_format")

    for repo_action in ("enable", "disable"):
        repo_state = repo_actions.add_parser(repo_action)
        repo_state.add_argument("name")
        repo_state.add_argument("--workspace", default=".")

    export = subparsers.add_parser("export", help="Exporta el ecosistema SGODA.")
    export_actions = export.add_subparsers(dest="export_action")
    export_create = export_actions.add_parser("create")
    export_create.add_argument("output", type=Path)
    export_create.add_argument("--workspace", default=".")
    export_verify = export_actions.add_parser("verify")
    export_verify.add_argument("package", type=Path)
    export_verify.add_argument("--workspace", default=".")
    export_verify.add_argument("--format", choices=("text", "json"), default="text", dest="output_format")

    import_cmd = subparsers.add_parser("import", help="Importa un paquete SGODA.")
    import_actions = import_cmd.add_subparsers(dest="import_action")
    import_package = import_actions.add_parser("package")
    import_package.add_argument("package", type=Path)
    import_package.add_argument("--workspace", default=".")
    import_package.add_argument("--replace", action="store_true")
    import_package.add_argument("--dry-run", action="store_true")
    import_package.add_argument("--format", choices=("text", "json"), default="text", dest="output_format")
    import_verify = import_actions.add_parser("verify")
    import_verify.add_argument("package", type=Path)
    import_verify.add_argument("--workspace", default=".")
    import_verify.add_argument("--format", choices=("text", "json"), default="text", dest="output_format")

    consolidated = subparsers.add_parser("ecosystem-report", help="Genera reporte consolidado del ecosistema.")
    consolidated.add_argument("workspace", nargs="?", default=".")
    consolidated.add_argument("--format", choices=("text", "json", "markdown", "html"), default="markdown", dest="output_format")
    consolidated.add_argument("--output", type=Path)
    consolidated.add_argument("--history-limit", type=int, default=20)

    bundle = subparsers.add_parser(
        "bundle",
        help="Administra bundles de extensiones.",
    )
    bundle_actions = bundle.add_subparsers(dest="bundle_action")

    bundle_create = bundle_actions.add_parser("create")
    bundle_create.add_argument("name")
    bundle_create.add_argument("selectors", nargs="*")
    bundle_create.add_argument("--all", action="store_true", dest="include_all")
    bundle_create.add_argument("--description", default="")
    bundle_create.add_argument("--force", action="store_true")
    bundle_create.add_argument("--workspace", default=".")
    bundle_create.add_argument(
        "--format", choices=("text", "json"), default="text", dest="output_format"
    )

    for bundle_action in ("list",):
        bundle_command = bundle_actions.add_parser(bundle_action)
        bundle_command.add_argument("--workspace", default=".")
        bundle_command.add_argument(
            "--format", choices=("text", "json"), default="text", dest="output_format"
        )

    bundle_info = bundle_actions.add_parser("info")
    bundle_info.add_argument("name")
    bundle_info.add_argument("--workspace", default=".")
    bundle_info.add_argument(
        "--format", choices=("text", "json"), default="text", dest="output_format"
    )

    for operation in ("install", "update", "uninstall", "enable", "disable"):
        bundle_operation = bundle_actions.add_parser(operation)
        bundle_operation.add_argument("name")
        bundle_operation.add_argument("--workspace", default=".")
        bundle_operation.add_argument("--dry-run", action="store_true")
        bundle_operation.add_argument(
            "--format", choices=("text", "json"), default="text", dest="output_format"
        )

    catalog = subparsers.add_parser(
        "catalog",
        help="Administra el catálogo local unificado.",
    )
    catalog_actions = catalog.add_subparsers(dest="catalog_action")

    for action_name in ("rebuild", "list"):
        action = catalog_actions.add_parser(action_name)
        action.add_argument("--workspace", default=".")
        action.add_argument(
            "--type",
            choices=("plugin", "template"),
            dest="extension_type",
        )
        action.add_argument(
            "--format",
            choices=("text", "json"),
            default="text",
            dest="output_format",
        )

    search = catalog_actions.add_parser("search")
    search.add_argument("query")
    search.add_argument("--workspace", default=".")
    search.add_argument(
        "--type",
        choices=("plugin", "template"),
        dest="extension_type",
    )
    search.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        dest="output_format",
    )

    info = catalog_actions.add_parser("info")
    info.add_argument("name")
    info.add_argument("--workspace", default=".")
    info.add_argument(
        "--type",
        choices=("plugin", "template"),
        dest="extension_type",
    )
    info.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        dest="output_format",
    )

    report = subparsers.add_parser(
        "report",
        help="Genera un reporte ejecutivo consolidado.",
    )
    report.add_argument("workspace", nargs="?", default=".")
    report.add_argument(
        "--format",
        choices=("markdown", "json", "html"),
        default="markdown",
        dest="output_format",
    )
    report.add_argument("--output", type=Path)
    report.add_argument("--no-history", action="store_true")
    report.add_argument("--history-limit", type=int, default=20)
    report.add_argument(
        "--profile",
        choices=("executive", "technical", "audit"),
        default="executive",
    )
    report.add_argument(
        "--sections",
        help="Lista separada por comas de secciones del reporte.",
    )


    for extension_type in ("plugin", "template"):
        extension = subparsers.add_parser(extension_type)
        actions = extension.add_subparsers(dest="extension_action")

        list_command = actions.add_parser("list")
        list_command.add_argument("workspace", nargs="?", default=".")
        list_command.add_argument(
            "--format",
            choices=("text", "json"),
            default="text",
            dest="output_format",
        )

        validate_command = actions.add_parser("validate")
        validate_command.add_argument("source")
        validate_command.add_argument("--workspace", default=".")
        validate_command.add_argument(
            "--format",
            choices=("text", "json"),
            default="text",
            dest="output_format",
        )

        install_command = actions.add_parser("install")
        install_command.add_argument("source")
        install_command.add_argument("--workspace", default=".")
        install_command.add_argument("--force", action="store_true")
        install_command.add_argument(
            "--format",
            choices=("text", "json"),
            default="text",
            dest="output_format",
        )

        info_command = actions.add_parser("info")
        info_command.add_argument("name")
        info_command.add_argument("--workspace", default=".")
        info_command.add_argument(
            "--format",
            choices=("text", "json"),
            default="text",
            dest="output_format",
        )

        remove_command = actions.add_parser("remove")
        remove_command.add_argument("name")
        remove_command.add_argument("--workspace", default=".")

        if extension_type == "plugin":
            for state_action in ("enable", "disable"):
                state_command = actions.add_parser(state_action)
                state_command.add_argument("name")
                state_command.add_argument("--workspace", default=".")
                state_command.add_argument(
                    "--format",
                    choices=("text", "json"),
                    default="text",
                    dest="output_format",
                )

            doctor_command = actions.add_parser("doctor")
            doctor_command.add_argument("workspace", nargs="?", default=".")
            doctor_command.add_argument(
                "--format",
                choices=("text", "json"),
                default="text",
                dest="output_format",
            )

            verify_command = actions.add_parser("verify")
            verify_command.add_argument("name")
            verify_command.add_argument("--workspace", default=".")
            verify_command.add_argument(
                "--refresh",
                action="store_true",
                help="Recalcula y acepta la línea base actual.",
            )
            verify_command.add_argument(
                "--format",
                choices=("text", "json"),
                default="text",
                dest="output_format",
            )

            update_command = actions.add_parser("update")
            update_command.add_argument("name")
            update_command.add_argument("source")
            update_command.add_argument("--workspace", default=".")
            update_command.add_argument(
                "--no-backup",
                action="store_true",
            )
            update_command.add_argument(
                "--allow-downgrade",
                action="store_true",
            )
            update_command.add_argument(
                "--format",
                choices=("text", "json"),
                default="text",
                dest="output_format",
            )

        if extension_type == "template":
            for state_action in ("enable", "disable"):
                state_command = actions.add_parser(state_action)
                state_command.add_argument("name")
                state_command.add_argument("--workspace", default=".")
                state_command.add_argument(
                    "--format",
                    choices=("text", "json"),
                    default="text",
                    dest="output_format",
                )

            doctor_command = actions.add_parser("doctor")
            doctor_command.add_argument("workspace", nargs="?", default=".")
            doctor_command.add_argument(
                "--format",
                choices=("text", "json"),
                default="text",
                dest="output_format",
            )

            verify_command = actions.add_parser("verify")
            verify_command.add_argument("name")
            verify_command.add_argument("--workspace", default=".")
            verify_command.add_argument(
                "--refresh",
                action="store_true",
                help="Recalcula y acepta la línea base actual.",
            )
            verify_command.add_argument(
                "--format",
                choices=("text", "json"),
                default="text",
                dest="output_format",
            )

            advanced_validate = actions.add_parser("inspect")
            advanced_validate.add_argument("source")
            advanced_validate.add_argument(
                "--format",
                choices=("text", "json"),
                default="text",
                dest="output_format",
            )

            update_command = actions.add_parser("update")
            update_command.add_argument("name")
            update_command.add_argument("source")
            update_command.add_argument("--workspace", default=".")
            update_command.add_argument("--no-backup", action="store_true")
            update_command.add_argument("--allow-downgrade", action="store_true")
            update_command.add_argument("--format", choices=("text", "json"), default="text", dest="output_format")

            versions_command = actions.add_parser("versions")
            versions_command.add_argument("name")
            versions_command.add_argument("--workspace", default=".")
            versions_command.add_argument("--format", choices=("text", "json"), default="text", dest="output_format")

            render_command = actions.add_parser("render")
            render_command.add_argument("name")
            render_command.add_argument("destination")
            render_command.add_argument("--workspace", default=".")
            render_command.add_argument(
                "--var",
                action="append",
                default=[],
                dest="variables",
            )
            render_command.add_argument("--force", action="store_true")

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "repo":
        workspace = Path(getattr(args, "workspace", ".")).resolve()
        if args.repo_action == "add":
            return command_repo_add(
                workspace,
                args.name,
                args.url,
                priority=args.priority,
                trusted=args.trusted,
                disabled=args.disabled,
                force=args.force,
                output_format=args.output_format,
            )
        if args.repo_action == "remove":
            return command_repo_remove(workspace, args.name)
        if args.repo_action == "list":
            return command_repo_list(
                workspace,
                enabled_only=args.enabled_only,
                output_format=args.output_format,
            )
        if args.repo_action == "info":
            return command_repo_info(
                workspace, args.name, output_format=args.output_format
            )
        if args.repo_action in {"enable", "disable"}:
            return command_repo_set_enabled(
                workspace, args.name, enabled=args.repo_action == "enable"
            )
        parser.print_help()
        return 2

    if args.command == "export":
        if args.export_action == "create":
            return command_export_create(Path(args.workspace).resolve(), args.output)
        if args.export_action == "verify":
            return command_export_verify(
                Path(args.workspace).resolve(), args.package,
                output_format=args.output_format,
            )
        parser.print_help()
        return 2
    if args.command == "import":
        if args.import_action == "package":
            return command_import_package(
                Path(args.workspace).resolve(), args.package,
                replace=args.replace, dry_run=args.dry_run,
                output_format=args.output_format,
            )
        if args.import_action == "verify":
            return command_import_verify(
                Path(args.workspace).resolve(), args.package,
                output_format=args.output_format,
            )
        parser.print_help()
        return 2
    if args.command == "ecosystem-report":
        return command_report_consolidated(
            Path(args.workspace).resolve(),
            output_format=args.output_format,
            output=args.output,
            history_limit=args.history_limit,
        )
    if args.command == "bundle":
        action = args.bundle_action
        if action == "create":
            return command_bundle_create(
                Path(args.workspace).resolve(),
                args.name,
                args.selectors,
                include_all=args.include_all,
                description=args.description,
                force=args.force,
                output_format=args.output_format,
            )
        if action == "list":
            return command_bundle_list(
                Path(args.workspace).resolve(),
                output_format=args.output_format,
            )
        if action == "info":
            return command_bundle_info(
                Path(args.workspace).resolve(),
                args.name,
                output_format=args.output_format,
            )
        if action in {"install", "update", "uninstall", "enable", "disable"}:
            return command_bundle_execute(
                Path(args.workspace).resolve(),
                args.name,
                action,
                dry_run=args.dry_run,
                output_format=args.output_format,
            )
        parser.print_help()
        return 2
    if args.command == "catalog":
        action = args.catalog_action
        if action == "rebuild":
            return command_catalog_rebuild(
                Path(args.workspace).resolve(),
                output_format=args.output_format,
            )
        if action == "list":
            return command_catalog_list(
                Path(args.workspace).resolve(),
                extension_type=args.extension_type,
                output_format=args.output_format,
            )
        if action == "search":
            return command_catalog_search(
                Path(args.workspace).resolve(),
                args.query,
                extension_type=args.extension_type,
                output_format=args.output_format,
            )
        if action == "info":
            return command_catalog_info(
                Path(args.workspace).resolve(),
                args.name,
                extension_type=args.extension_type,
                output_format=args.output_format,
            )
        parser.print_help()
        return 2
    if args.command == "version":
        return command_version()
    if args.command == "doctor":
        return command_doctor(Path(args.workspace).resolve(), fix=args.fix, dry_run=args.dry_run, backup=not args.no_backup, output_format=args.output_format)
    if args.command == "init":
        return command_init(Path(args.workspace), args.project_name)
    if args.command == "validate":
        return command_validate(Path(args.workspace).resolve())
    if args.command == "generate":
        return command_generate(
            args.component,
            Path(args.workspace).resolve(),
            name=args.name,
            force=args.force,
            dry_run=args.dry_run,
            verbose=args.verbose,
        )
    if args.command == "audit":
        return command_audit(
            Path(args.workspace).resolve(),
            output_format=args.output_format,
            output=args.output,
            strict=args.strict,
        )
    if args.command == "quality":
        return command_quality(
            Path(args.workspace).resolve(),
            strict=args.strict,
        )
    if args.command == "upgrade":
        return command_upgrade(
            Path(args.workspace).resolve(),
            dry_run=args.dry_run,
            backup=not args.no_backup,
            output_format=args.output_format,
        )
    if args.command == "migrate":
        return command_migrate(
            Path(args.workspace).resolve(),
            target_version=args.target_version,
            dry_run=args.dry_run,
            backup=not args.no_backup,
            output_format=args.output_format,
        )

    if args.command == "status":
        return command_status(
            Path(args.workspace).resolve(),
            output_format=args.output_format,
            detailed=args.detailed,
        )

    if args.command == "history":
        return command_history(
            Path(args.workspace).resolve(),
            event_type=args.event_type,
            since=args.since,
            limit=args.limit,
            output_format=args.output_format,
            record_status=args.record_status,
        )

    if args.command == "report":
        return command_report(
            Path(args.workspace).resolve(),
            output_format=args.output_format,
            output=args.output,
            include_history=not args.no_history,
            history_limit=args.history_limit,
            profile=args.profile,
            sections=(
                tuple(args.sections.split(","))
                if args.sections
                else None
            ),
        )

    if args.command in {"plugin", "template"}:
        extension_type = args.command
        action = args.extension_action
        if action == "list":
            return command_extension_list(
                Path(args.workspace).resolve(),
                extension_type=extension_type,
                output_format=args.output_format,
            )
        if action == "validate":
            return command_extension_validate(
                Path(args.workspace).resolve(),
                Path(args.source),
                extension_type=extension_type,
                output_format=args.output_format,
            )
        if action == "install":
            return command_extension_install(
                Path(args.workspace).resolve(),
                Path(args.source),
                extension_type=extension_type,
                force=args.force,
                output_format=args.output_format,
            )
        if action == "info":
            return command_extension_info(
                Path(args.workspace).resolve(),
                args.name,
                extension_type=extension_type,
                output_format=args.output_format,
            )
        if action == "remove":
            return command_extension_remove(
                Path(args.workspace).resolve(),
                args.name,
                extension_type=extension_type,
            )
        if extension_type == "plugin" and action in {"enable", "disable"}:
            return command_plugin_state(
                Path(args.workspace).resolve(),
                args.name,
                enabled=action == "enable",
                output_format=args.output_format,
            )
        if extension_type == "plugin" and action == "doctor":
            return command_plugin_doctor(
                Path(args.workspace).resolve(),
                output_format=args.output_format,
            )
        if extension_type == "plugin" and action == "verify":
            return command_plugin_integrity(
                Path(args.workspace).resolve(),
                args.name,
                refresh=args.refresh,
                output_format=args.output_format,
            )
        if extension_type == "plugin" and action == "update":
            return command_plugin_update(
                Path(args.workspace).resolve(),
                args.name,
                Path(args.source),
                backup=not args.no_backup,
                allow_downgrade=args.allow_downgrade,
                output_format=args.output_format,
            )
        if extension_type == "template" and action in {"enable", "disable"}:
            return command_template_state(
                Path(args.workspace).resolve(),
                args.name,
                enabled=action == "enable",
                output_format=args.output_format,
            )
        if extension_type == "template" and action == "doctor":
            return command_template_doctor(
                Path(args.workspace).resolve(),
                output_format=args.output_format,
            )
        if extension_type == "template" and action == "verify":
            return command_template_integrity(
                Path(args.workspace).resolve(),
                args.name,
                refresh=args.refresh,
                output_format=args.output_format,
            )
        if extension_type == "template" and action == "inspect":
            return command_template_validate_advanced(
                Path(args.source),
                output_format=args.output_format,
            )
        if extension_type == "template" and action == "update":
            return command_template_update(Path(args.workspace).resolve(), args.name, Path(args.source), backup=not args.no_backup, allow_downgrade=args.allow_downgrade, output_format=args.output_format)
        if extension_type == "template" and action == "versions":
            return command_template_versions(Path(args.workspace).resolve(), args.name, output_format=args.output_format)
        if extension_type == "template" and action == "render":
            return command_template_render(
                Path(args.workspace).resolve(),
                args.name,
                Path(args.destination),
                variables=args.variables,
                force=args.force,
            )

    parser.print_help()
    return 0
