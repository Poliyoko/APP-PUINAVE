"""Circuit breaker persistente para el piloto controlado."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path


class CircuitBreaker:
    def __init__(
        self,
        *,
        path: str | Path,
        failure_threshold: int = 3,
        cooldown_seconds: int = 300,
    ) -> None:
        self.path = Path(path)
        self.failure_threshold = failure_threshold
        self.cooldown_seconds = cooldown_seconds

    def _default(self) -> dict:
        return {
            "state": "closed",
            "failure_count": 0,
            "opened_at_utc": None,
        }

    def load(self) -> dict:
        if not self.path.is_file():
            return self._default()
        return json.loads(self.path.read_text(encoding="utf-8"))

    def save(self, payload: dict) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    def allow_request(self) -> bool:
        state = self.load()

        if state["state"] == "closed":
            return True

        if state["state"] == "open":
            opened = datetime.fromisoformat(
                state["opened_at_utc"].replace("Z", "+00:00")
            )
            now = datetime.now(timezone.utc)
            if now >= opened + timedelta(
                seconds=self.cooldown_seconds
            ):
                state["state"] = "half-open"
                self.save(state)
                return True
            return False

        return state["state"] == "half-open"

    def record_success(self) -> None:
        self.save(self._default())

    def record_failure(self) -> None:
        state = self.load()
        state["failure_count"] += 1

        if state["failure_count"] >= self.failure_threshold:
            state["state"] = "open"
            state["opened_at_utc"] = datetime.now(
                timezone.utc
            ).isoformat()

        self.save(state)