"""Timeline derivado de releases, configuración y Git."""

from __future__ import annotations

import subprocess
from pathlib import Path

from .models import ComponentRecord


def _git_date(root: Path, path: str | None) -> str | None:
    if not path:
        return None

    completed = subprocess.run(
        [
            "git",
            "log",
            "-1",
            "--format=%cI",
            "--",
            path,
        ],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )

    value = completed.stdout.strip()
    return value or None


def build_timeline(
    root: str | Path,
    components: list[ComponentRecord],
) -> list[dict]:
    repository = Path(root)
    timeline: list[dict] = []

    for item in components:
        reference = item.release_path or item.config_path
        timeline.append(
            {
                "code": item.code,
                "name": item.name,
                "phase": item.phase,
                "status": item.status,
                "version": item.version,
                "release": item.release_path,
                "last_git_date": _git_date(
                    repository,
                    reference,
                ),
            }
        )

    return sorted(
        timeline,
        key=lambda item: (
            item["last_git_date"] or "9999",
            item["code"],
        ),
    )