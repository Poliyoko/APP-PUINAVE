"""Control de presupuesto y registro de consumo."""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from .models import RegistroConsumo


class LibroConsumo:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def append(self, record: RegistroConsumo) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8") as stream:
            stream.write(
                json.dumps(
                    asdict(record),
                    ensure_ascii=False,
                )
                + "\n"
            )

    def total_cost(self) -> float:
        if not self.path.is_file():
            return 0.0

        total = 0.0
        for line in self.path.read_text(
            encoding="utf-8"
        ).splitlines():
            if not line.strip():
                continue
            payload: dict[str, Any] = json.loads(line)
            total += float(payload["estimated_cost_usd"])

        return round(total, 8)


def estimate_cost(
    *,
    provider: str,
    job_type: str,
    units: int,
    pricing: dict[str, Any],
) -> float:
    provider_pricing = pricing.get(provider, {})
    rate = float(provider_pricing.get(job_type, 0.0))
    return round(rate * units, 8)