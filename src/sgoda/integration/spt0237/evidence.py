from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any, Iterable

from .models import AuditFinding


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


@dataclass(frozen=True)
class EvidenceBundle:
    finding_count: int
    subjects: tuple[str, ...]
    dimensions: tuple[str, ...]
    sha256: str
    payload: tuple[dict[str, Any], ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "finding_count": self.finding_count,
            "subjects": list(self.subjects),
            "dimensions": list(self.dimensions),
            "sha256": self.sha256,
            "payload": list(self.payload),
        }


class EvidenceConsolidator:
    @staticmethod
    def consolidate(findings: Iterable[AuditFinding]) -> EvidenceBundle:
        payload = tuple(
            sorted(
                (
                    {
                        "dimension": f.dimension,
                        "code": f.code,
                        "severity": f.severity.upper(),
                        "message": f.message,
                        "subject": f.subject,
                        "evidence": dict(f.evidence),
                    }
                    for f in findings
                ),
                key=lambda item: (
                    item["subject"],
                    item["dimension"],
                    item["code"],
                    item["severity"],
                ),
            )
        )
        sha = hashlib.sha256(_canonical(payload)).hexdigest().upper()
        return EvidenceBundle(
            finding_count=len(payload),
            subjects=tuple(sorted({item["subject"] for item in payload if item["subject"]})),
            dimensions=tuple(sorted({item["dimension"] for item in payload})),
            sha256=sha,
            payload=payload,
        )
