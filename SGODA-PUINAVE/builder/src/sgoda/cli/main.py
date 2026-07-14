import argparse
from collections.abc import Sequence
from pathlib import Path
from .commands import command_version, command_doctor, command_init, command_validate

def build_parser() -> argparse.ArgumentParser:
    p=argparse.ArgumentParser(prog="sgoda", description="SGODA Project Builder")
    s=p.add_subparsers(dest="command")
    s.add_parser("version")
    d=s.add_parser("doctor"); d.add_argument("workspace", nargs="?", default=".")
    i=s.add_parser("init"); i.add_argument("workspace", nargs="?", default="."); i.add_argument("--dry-run", action="store_true"); i.add_argument("--verbose", action="store_true")
    v=s.add_parser("validate"); v.add_argument("workspace", nargs="?", default=".")
    return p

def main(argv: Sequence[str] | None=None) -> int:
    p=build_parser(); a=p.parse_args(argv)
    if a.command=="version": return command_version()
    if a.command=="doctor": return command_doctor(Path(a.workspace).resolve())
    if a.command=="init": return command_init(Path(a.workspace), dry_run=a.dry_run, verbose=a.verbose)
    if a.command=="validate": return command_validate(Path(a.workspace).resolve())
    p.print_help(); return 0
