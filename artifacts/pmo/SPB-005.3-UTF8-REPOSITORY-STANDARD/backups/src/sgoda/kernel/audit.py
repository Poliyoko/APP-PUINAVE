"""Auditoría técnica básica del repositorio."""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any


def _repository_root() -> Path:
    """Localiza la raíz del repositorio."""

    return Path(__file__).resolve().parents[3]


def _git(*arguments: str) -> tuple[bool, str]:
    """Ejecuta un comando Git de solo lectura."""

    try:
        result = subprocess.run(
            ["git", *arguments],
            cwd=_repository_root(),
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (
        FileNotFoundError,
        subprocess.TimeoutExpired,
    ) as exc:
        return False, str(exc)

    output = (
        result.stdout.strip()
        or result.stderr.strip()
    )

    return result.returncode == 0, output


def audit_repository() -> dict[str, Any]:
    """Realiza una auditoría de solo lectura."""

    status_ok, status_output = _git(
        "status",
        "--short",
    )
    branch_ok, branch_output = _git(
        "branch",
        "--show-current",
    )
    commit_ok, commit_output = _git(
        "rev-parse",
        "--short",
        "HEAD",
    )

    repository_available = (
        status_ok
        and branch_ok
        and commit_ok
    )

    return {
        "repository_available": repository_available,
        "branch": (
            branch_output
            if branch_ok
            else "unknown"
        ),
        "commit": (
            commit_output
            if commit_ok
            else "unknown"
        ),
        "working_tree_clean": (
            status_ok
            and not status_output
        ),
        "pending_changes": (
            status_output.splitlines()
            if status_ok and status_output
            else []
        ),
        "audit_mode": "read-only",
    }
