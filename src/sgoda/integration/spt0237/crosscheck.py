from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from .models import AuditFinding


@dataclass(frozen=True)
class CrossComponentInconsistency:
    code: str
    severity: str
    components: tuple[str, ...]
    message: str

    def to_dict(self) -> dict:
        return {
            "code": self.code,
            "severity": self.severity,
            "components": list(self.components),
            "message": self.message,
        }


class CrossComponentConsistencyEngine:
    """Detects cross-component inconsistencies from audit findings."""

    COMPONENTS = tuple(f"SPT-023.{i}" for i in range(1, 7))

    @classmethod
    def detect(cls, findings: Iterable[AuditFinding]) -> list[CrossComponentInconsistency]:
        findings = list(findings)
        results: list[CrossComponentInconsistency] = []

        missing_scope = {
            f.subject
            for f in findings
            if f.code in {"SCOPE_GAP", "COMPONENT_RESOURCE_MISSING"}
            and f.subject in cls.COMPONENTS
        }
        if missing_scope:
            results.append(
                CrossComponentInconsistency(
                    code="PIPELINE_SCOPE_INCOMPLETE",
                    severity="ERROR",
                    components=tuple(sorted(missing_scope)),
                    message="The intelligent integration pipeline has missing auditable components.",
                )
            )

        blocking_components = sorted({
            f.subject
            for f in findings
            if f.blocking and f.subject in cls.COMPONENTS
        })
        if len(blocking_components) > 1:
            results.append(
                CrossComponentInconsistency(
                    code="MULTI_COMPONENT_BLOCKING_RISK",
                    severity="CRITICAL",
                    components=tuple(blocking_components),
                    message="Blocking findings affect multiple closed pipeline components.",
                )
            )

        evidence_gaps = sorted({
            f.subject
            for f in findings
            if f.code == "EVIDENCE_NOT_DISCOVERED"
            and f.subject in cls.COMPONENTS
        })
        if len(evidence_gaps) >= 2:
            results.append(
                CrossComponentInconsistency(
                    code="TRACEABILITY_CHAIN_WEAKNESS",
                    severity="WARNING",
                    components=tuple(evidence_gaps),
                    message="Evidence gaps span multiple pipeline components.",
                )
            )

        return results
