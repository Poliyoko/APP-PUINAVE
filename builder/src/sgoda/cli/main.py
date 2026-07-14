"""Interfaz de línea de comandos del SGODA Project Builder."""

import argparse
from collections.abc import Sequence
from pathlib import Path
from sgoda.core import APP_NAME
from .commands import command_doctor, command_init, command_validate, command_version


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="sgoda", description=APP_NAME)
    subparsers = parser.add_subparsers(dest="command")
    subparsers.add_parser("version", help="Muestra la versión del Builder.")
    doctor_parser = subparsers.add_parser("doctor", help="Verifica el entorno de desarrollo.")
    doctor_parser.add_argument("workspace", nargs="?", default=".")
    init_parser = subparsers.add_parser("init", help="Inicializa profesionalmente un proyecto SGODA.")
    init_parser.add_argument("workspace", nargs="?", default=".")
    init_parser.add_argument("--project-name")
    init_parser.add_argument("--force", action="store_true")
    init_parser.add_argument("--dry-run", action="store_true")
    init_parser.add_argument("--verbose", action="store_true")
    validate_parser = subparsers.add_parser("validate", help="Valida la estructura de un proyecto SGODA.")
    validate_parser.add_argument("workspace", nargs="?", default=".")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "version": return command_version()
    if args.command == "doctor": return command_doctor(Path(args.workspace).expanduser().resolve())
    if args.command == "init":
        return command_init(Path(args.workspace), project_name=args.project_name, force=args.force, dry_run=args.dry_run, verbose=args.verbose)
    if args.command == "validate": return command_validate(Path(args.workspace).expanduser().resolve())
    parser.print_help()
    return 0
