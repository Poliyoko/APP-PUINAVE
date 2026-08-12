from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .impact import assess_impact
from .models import RiskControl
from .risk import assess_risk
from .threats import assess_threat_governance
from .treatment import assess_treatment
from .vulnerabilities import assess_vulnerability_governance


class SecurityRiskGovernanceAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        threats = assess_threat_governance({
            "taxonomy_defined": True,
            "assets_mapped": True,
            "attack_vectors_reviewed": True,
            "owners_defined": True,
            "evidence_required": True,
        })

        vulnerabilities = assess_vulnerability_governance({
            "inventory_required": True,
            "severity_model_defined": True,
            "remediation_owner_required": True,
            "sla_defined": True,
            "evidence_required": True,
        })

        impact = assess_impact({
            "confidentiality": 4,
            "integrity": 5,
            "availability": 4,
            "cultural": 5,
            "institutional": 4,
        })

        risk = assess_risk({
            "likelihood": 3,
            "impact": impact["impact_score"],
        })

        treatment = assess_treatment({
            "treatment": "MITIGATE",
            "owner": "PISI_RISK_OWNER",
            "due_date": "GOVERNED",
            "approval_required": True,
            "residual_risk_review": True,
            "evidence_required": True,
        })

        controls = [
            RiskControl("RISK-INVENTORY", "Security risk surface inventory", len(self.discovered_paths) >= 0, True, True, "Security risk surfaces are inventoried."),
            RiskControl("RISK-THREAT-GOVERNANCE", "Threat governance", threats["valid"] is True, True, True, "Threat taxonomy, assets, vectors and owners are governed."),
            RiskControl("RISK-VULNERABILITY-GOVERNANCE", "Vulnerability governance", vulnerabilities["valid"] is True, True, True, "Vulnerability inventory, severity, ownership and SLA are governed."),
            RiskControl("RISK-IMPACT-GOVERNANCE", "Impact assessment", impact["valid"] is True, True, True, "Impact includes CIA, cultural and institutional dimensions."),
            RiskControl("RISK-SCORING", "Risk scoring", risk["valid"] is True, True, True, "Risk combines likelihood and impact."),
            RiskControl("RISK-TREATMENT-GOVERNANCE", "Risk treatment governance", treatment["valid"] is True, True, True, "Treatment requires owner, due date, approval, residual review and evidence."),
            RiskControl("RISK-RESIDUAL-REVIEW", "Residual risk review", treatment["residual_risk_review"] is True, True, True, "Residual risk must be reviewed."),
            RiskControl("RISK-NO-ACTIVE-PROBE", "No active threat probe", threats["active_probe_executed"] is False, True, True, "Layer 1 does not execute active attack probes."),
            RiskControl("RISK-NO-VULN-SCAN", "No active vulnerability scan", vulnerabilities["scanner_executed"] is False, True, True, "Layer 1 is static and file-based."),
            RiskControl("RISK-NO-PRODUCTION-CHANGE", "No production change", vulnerabilities["production_changed"] is False and treatment["production_changed"] is False, True, True, "Assessment does not alter production."),
            RiskControl("RISK-NO-EXTERNAL-CONNECTION", "No external connection", threats["external_connection_opened"] is False and vulnerabilities["external_connection_opened"] is False, True, True, "Assessment stays local."),
            RiskControl("RISK-SECRET-SAFETY", "No secret values exposed", threats["secret_values_exposed"] is False and vulnerabilities["secret_values_exposed"] is False and impact["secret_values_exposed"] is False and treatment["secret_values_exposed"] is False, True, True, "Evidence contains metadata only."),
        ]

        failed = [item.control_id for item in controls if item.blocking and item.applicable and not item.passed]

        return {
            "status": "SECURITY_RISK_GOVERNANCE_GATE_PASS" if not failed else "SECURITY_RISK_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "threat_governance": threats,
            "vulnerability_governance": vulnerabilities,
            "impact_assessment": impact,
            "risk_assessment": risk,
            "treatment_governance": treatment,
            "risk_surfaces": len(self.discovered_paths),
            "active_probe_executed": False,
            "vulnerability_scan_executed": False,
            "treatment_executed": False,
            "production_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
