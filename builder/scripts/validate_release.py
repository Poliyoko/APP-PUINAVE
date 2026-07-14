"""Validador de artefactos de publicación SGODA."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys
import zipfile


WHEEL_PATTERN = re.compile(
    r"^sgoda_builder-(?P<version>\d+\.\d+\.\d+)-py3-none-any\.whl$"
)
SDIST_PATTERN = re.compile(
    r"^sgoda_builder-(?P<version>\d+\.\d+\.\d+)\.tar\.gz$"
)


def validate_wheel(path: Path, expected_version: str) -> None:
    match = WHEEL_PATTERN.match(path.name)
    if not match:
        raise ValueError(f"Nombre de wheel inválido: {path.name}")
    if match.group("version") != expected_version:
        raise ValueError(
            f"Wheel {match.group('version')} != {expected_version}"
        )
    if path.stat().st_size < 1_000:
        raise ValueError(f"Wheel demasiado pequeño: {path}")

    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        expected_metadata = (
            f"sgoda_builder-{expected_version}.dist-info/METADATA"
        )
        if expected_metadata not in names:
            raise ValueError(
                f"No existe {expected_metadata} dentro del wheel"
            )
        if not any(name.startswith("sgoda/") for name in names):
            raise ValueError("El wheel no contiene el paquete sgoda")


def validate_sdist(path: Path, expected_version: str) -> None:
    match = SDIST_PATTERN.match(path.name)
    if not match:
        raise ValueError(f"Nombre de sdist inválido: {path.name}")
    if match.group("version") != expected_version:
        raise ValueError(
            f"Sdist {match.group('version')} != {expected_version}"
        )
    if path.stat().st_size < 1_000:
        raise ValueError(f"Sdist demasiado pequeño: {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dist", type=Path, required=True)
    parser.add_argument("--expected-version", required=True)
    args = parser.parse_args()

    dist = args.dist.expanduser().resolve()
    wheel = dist / (
        f"sgoda_builder-{args.expected_version}-py3-none-any.whl"
    )
    sdist = dist / f"sgoda_builder-{args.expected_version}.tar.gz"

    if not wheel.is_file():
        raise SystemExit(f"No existe: {wheel}")
    if not sdist.is_file():
        raise SystemExit(f"No existe: {sdist}")

    try:
        validate_wheel(wheel, args.expected_version)
        validate_sdist(sdist, args.expected_version)
    except ValueError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print(f"[OK] Wheel: {wheel.name}")
    print(f"[OK] Source distribution: {sdist.name}")
    print(f"[OK] Versión: {args.expected_version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
