"""Smoke test del Builder para integración continua."""

from __future__ import annotations

import argparse
from pathlib import Path
import glob
import subprocess
import sys
import tempfile
import venv


def run(command: list[str], *, cwd: Path | None = None) -> None:
    """Ejecuta un comando y falla inmediatamente ante un error."""
    print("$", " ".join(command))
    subprocess.run(command, cwd=cwd, check=True)


def resolve_wheel(pattern: str) -> Path:
    """Resuelve exactamente un wheel desde un patrón glob."""
    matches = [Path(item).resolve() for item in glob.glob(pattern)]

    if not matches:
        raise SystemExit(f"No se encontró ningún wheel con: {pattern}")

    if len(matches) > 1:
        names = ", ".join(str(item) for item in matches)
        raise SystemExit(f"Se encontró más de un wheel: {names}")

    return matches[0]


def installed_executables(environment: Path) -> tuple[Path, Path]:
    """Devuelve las rutas de Python y del ejecutable sgoda."""
    if sys.platform == "win32":
        return (
            environment / "Scripts" / "python.exe",
            environment / "Scripts" / "sgoda.exe",
        )

    return (
        environment / "bin" / "python",
        environment / "bin" / "sgoda",
    )


def test_installed_wheel(wheel: Path) -> None:
    """Instala y prueba el wheel en un entorno virtual temporal."""
    with tempfile.TemporaryDirectory(prefix="sgoda-ci-") as temp:
        root = Path(temp)
        environment = root / "venv"
        project = root / "project"

        venv.EnvBuilder(with_pip=True).create(environment)
        python, sgoda = installed_executables(environment)

        run([str(python), "-m", "pip", "install", str(wheel)])
        run([str(sgoda), "version"])
        run([str(sgoda), "doctor", str(wheel.parent.parent)])
        run(
            [
                str(sgoda),
                "init",
                str(project),
                "--project-name",
                "SGODA CI Smoke",
            ]
        )
        run([str(sgoda), "validate", str(project)])
        run([str(sgoda), "audit", str(project), "--strict"])
        run([str(sgoda), "quality", str(project), "--strict"])


def test_source(source: Path) -> None:
    """Prueba el módulo directamente desde el código fuente."""
    run([sys.executable, "-m", "sgoda", "version"], cwd=source)

    with tempfile.TemporaryDirectory(prefix="sgoda-source-") as temp:
        project = Path(temp) / "project"
        run(
            [
                sys.executable,
                "-m",
                "sgoda",
                "init",
                str(project),
                "--project-name",
                "SGODA Source Smoke",
            ],
            cwd=source,
        )
        run(
            [sys.executable, "-m", "sgoda", "audit", str(project), "--strict"],
            cwd=source,
        )
        run(
            [sys.executable, "-m", "sgoda", "quality", str(project), "--strict"],
            cwd=source,
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--wheel-glob")
    group.add_argument("--source", type=Path)
    args = parser.parse_args()

    if args.wheel_glob:
        test_installed_wheel(resolve_wheel(args.wheel_glob))
    else:
        test_source(args.source.expanduser().resolve())

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
