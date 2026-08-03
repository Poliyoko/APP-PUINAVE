
from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class ReleaseIdentity:
    increment_code: str
    version: str
    release_name: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class ReleaseOperationResult:
    approved: bool
    action: str
    canonical_release: str
    source_release: str | None
    backup_path: str | None
    references_updated: int
    findings: tuple[dict[str, Any], ...]

    @property
    def exit_code(self) -> int:
        return 0 if self.approved else 2

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["findings"] = list(self.findings)
        payload["exit_code"] = self.exit_code
        return payload
