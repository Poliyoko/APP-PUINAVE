"""CLI del SGODA Project Builder."""

import argparse
from collections.abc import Sequence
from pathlib import Path

from sgoda.generators import ComponentGenerator

from .commands import (
    command_audit,
    command_doctor,
    command_generate,
    command_history,
    command_extension_info,
    command_extension_install,
    command_extension_list,
    command_extension_remove,
    command_extension_validate,
    command_template_render,
    command_template_doctor,
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
