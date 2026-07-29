"""Metadatos técnicos de la plataforma SGODA-PUINAVE."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Any


PROJECT_NAME = "SGODA-PUINAVE"
PLATFORM_VERSION = os.getenv("SGODA_VERSION", "0.5.2")
ENVIRONMENT = os.getenv(
    "SGODA_ENVIRONMENT",
    "development",
)


def _repository_root() -> Path:
    """Localiza la raíz del repositorio."""

    return Path(__file__).resolve().parents[3]


def _run_git_command(*arguments: str) -> str | None:
    """Ejecuta un comando Git de solo lectura."""

    try:
        result = subprocess.run(
            ["git", *arguments],
            cwd=_repository_root(),
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (
        FileNotFoundError,
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
    ):
        return None

    value = result.stdout.strip()
    return value or None


def get_platform_metadata() -> dict[str, Any]:
    """Obtiene los metadatos generales del runtime."""

    commit = _run_git_command(
        "rev-parse",
        "--short",
        "HEAD",
    )
    branch = _run_git_command(
        "branch",
        "--show-current",
    )
    tag = _run_git_command(
        "describe",
        "--tags",
        "--exact-match",
        "HEAD",
    )

    return {
        "project": PROJECT_NAME,
        "version": PLATFORM_VERSION,
        "environment": ENVIRONMENT,
        "git": {
            "branch": branch or "unknown",
            "commit": commit or "unknown",
            "tag": tag,
        },
    }
