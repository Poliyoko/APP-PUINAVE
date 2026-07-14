"""Interfaz de línea de comandos del SGODA Project Builder."""
import argparse
from collections.abc import Sequence
from pathlib import Path
from sgoda.core import APP_NAME
from .commands import command_doctor, command_generate, command_init, command_validate, command_version

class ComponentGeneratorChoices:
    ALL = ("backend",)

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="sgoda", description=APP_NAME)
    sub = parser.add_subparsers(dest="command")
    sub.add_parser("version")
    doctor = sub.add_parser("doctor"); doctor.add_argument("workspace", nargs="?", default=".")
    init = sub.add_parser("init"); init.add_argument("workspace", nargs="?", default="."); init.add_argument("--project-name"); init.add_argument("--force",action="store_true"); init.add_argument("--dry-run",action="store_true"); init.add_argument("--verbose",action="store_true")
    validate = sub.add_parser("validate"); validate.add_argument("workspace", nargs="?", default=".")
    generate = sub.add_parser("generate"); generate.add_argument("component", choices=ComponentGeneratorChoices.ALL); generate.add_argument("workspace", nargs="?", default="."); generate.add_argument("--force",action="store_true"); generate.add_argument("--dry-run",action="store_true"); generate.add_argument("--verbose",action="store_true")
    return parser

def main(argv: Sequence[str]|None=None) -> int:
    parser = build_parser(); args = parser.parse_args(argv)
    if args.command == "version": return command_version()
    if args.command == "doctor": return command_doctor(Path(args.workspace).expanduser().resolve())
    if args.command == "init": return command_init(Path(args.workspace), project_name=args.project_name, force=args.force, dry_run=args.dry_run, verbose=args.verbose)
    if args.command == "validate": return command_validate(Path(args.workspace).expanduser().resolve())
    if args.command == "generate": return command_generate(args.component, Path(args.workspace).expanduser().resolve(), force=args.force, dry_run=args.dry_run, verbose=args.verbose)
    parser.print_help(); return 0
