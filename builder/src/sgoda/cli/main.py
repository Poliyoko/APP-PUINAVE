"""CLI del SGODA Project Builder."""

import argparse
from collections.abc import Sequence
from pathlib import Path

from sgoda.generators import ComponentGenerator

from .commands import (
    command_audit,
    command_doctor,
    command_generate,
    command_init,
    command_quality,
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

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "version":
        return command_version()
    if args.command == "doctor":
        return command_doctor(Path(args.workspace).resolve())
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

    parser.print_help()
    return 0
