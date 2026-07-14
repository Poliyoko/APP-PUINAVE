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
        help="Audita la calidad base de un proyecto SGODA.",
    )
    audit.add_argument("workspace", nargs="?", default=".")
    audit.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        dest="output_format",
    )

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

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
        )

    parser.print_help()
    return 0
