"""Prueba automatizada de un wheel instalado en un entorno limpio."""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import venv


def run(command: list[str], *, cwd: Path | None = None) -> None:
    subprocess.run(command, cwd=cwd, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("wheel", type=Path)
    args = parser.parse_args()

    wheel = args.wheel.resolve()
    if not wheel.is_file():
        raise SystemExit(f"No existe el wheel: {wheel}")

    with tempfile.TemporaryDirectory(prefix="sgoda-package-") as temp:
        root = Path(temp)
        environment = root / "venv"
        project = root / "project"

        venv.EnvBuilder(with_pip=True).create(environment)

        if sys.platform == "win32":
            python = environment / "Scripts" / "python.exe"
            sgoda = environment / "Scripts" / "sgoda.exe"
        else:
            python = environment / "bin" / "python"
            sgoda = environment / "bin" / "sgoda"

        run([str(python), "-m", "pip", "install", str(wheel)])
        run([str(sgoda), "version"])
        run(
            [
                str(sgoda),
                "init",
                str(project),
                "--project-name",
                "SGODA Package Smoke",
            ]
        )
        run([str(sgoda), "audit", str(project)])
        run([str(sgoda), "quality", str(project)])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
