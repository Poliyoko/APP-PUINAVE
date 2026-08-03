"""Exportación de resultados de evaluación."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def export_result(
    path: str | Path,
    payload: dict[str, Any],
) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )