from __future__ import annotations

from pathlib import Path
from typing import Any

from .correlation import FindingCorrelator
from .crosscheck import CrossComponentConsistencyEngine
from .evidence import EvidenceConsolidator
from .risk import InstitutionalRiskEvaluator
from .service import Spt0237Layer1Service
from .verdict import InstitutionalVerdictEngine


class Spt0237Layer2Service:
    """Advanced institutional correlation and verdict layer."""

    def __init__(self, root: str | Path):
        self.root = Path(root)
        self.layer1 = Spt0237Layer1Service(self.root)

    def evaluate(self) -> dict[str, Any]:
        report = self.layer1.audit()
        correlations = FindingCorrelator.correlate(report.findings)
        risk = InstitutionalRiskEvaluator.evaluate(report.findings, correlations)
        evidence = EvidenceConsolidator.consolidate(report.findings)
        inconsistencies = CrossComponentConsistencyEngine.detect(report.findings)

        blocking_cross = sum(
            1
            for item in inconsistencies
            if item.severity.upper() in {"ERROR", "CRITICAL"}
        )

        verdict = InstitutionalVerdictEngine.issue(
            report_conformant=report.conformant,
            risk=risk,
            evidence=evidence,
            cross_inconsistency_count=len(inconsistencies),
            blocking_cross_inconsistency_count=blocking_cross,
        )

        return {
            "component": "SPT-023.7",
            "layer": "2",
            "scope": list(report.scope),
            "correlations": [item.to_dict() for item in correlations],
            "risk": risk.to_dict(),
            "evidence_bundle": evidence.to_dict(),
            "cross_component_inconsistencies": [
                item.to_dict() for item in inconsistencies
            ],
            "verdict": verdict.to_dict(),
            "layer1_reused": True,
            "closed_components_mutated": False,
            "paid_api_used": False,
            "next_component": "SPT-023.7-CAPA-3",
        }
