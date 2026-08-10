from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from typing import Iterable

from .models import AuditFinding


@dataclass(frozen=True)
class CorrelatedFinding:
    correlation_id: str
    dimensions: tuple[str, ...]
    subjects: tuple[str, ...]
    codes: tuple[str, ...]
    severities: tuple[str, ...]
    finding_count: int

    def to_dict(self) -> dict:
        return {
            "correlation_id": self.correlation_id,
            "dimensions": list(self.dimensions),
            "subjects": list(self.subjects),
            "codes": list(self.codes),
            "severities": list(self.severities),
            "finding_count": self.finding_count,
        }


class FindingCorrelator:
    """Correlates audit findings by institutional subject."""

    @staticmethod
    def correlate(findings: Iterable[AuditFinding]) -> list[CorrelatedFinding]:
        grouped: dict[str, list[AuditFinding]] = defaultdict(list)
        for finding in findings:
            key = finding.subject.strip() or "__GLOBAL__"
            grouped[key].append(finding)

        results: list[CorrelatedFinding] = []
        for subject, items in sorted(grouped.items()):
            dimensions = tuple(sorted({item.dimension for item in items}))
            codes = tuple(sorted({item.code for item in items}))
            severities = tuple(sorted({item.severity.upper() for item in items}))
            correlation_id = "CORR-" + subject.replace("\\", "/").replace(" ", "_").upper()
            results.append(
                CorrelatedFinding(
                    correlation_id=correlation_id,
                    dimensions=dimensions,
                    subjects=(subject,),
                    codes=codes,
                    severities=severities,
                    finding_count=len(items),
                )
            )
        return results
