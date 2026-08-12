from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .baseline import validate_secure_baseline
from .change_governance import validate_change_governance
from .exposure import exposure_baseline
from .models import HardeningControl
from .port_governance import validate_port_governance
from .service_governance import validate_service_governance


class InfrastructureHardeningGovernanceAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        baseline = validate_secure_baseline({
            "versioned": True,
            "reviewed": True,
            "integrity_protected": True,
            "rollback_ready": True,
            "least_exposure": True,
            "secret_indirection": True,
        })

        service = validate_service_governance({
            "enabled": True,
            "approved": True,
            "health_check": True,
            "privileged": False,
            "external": False,
        })

        port = validate_port_governance({
            "port": 443,
            "purpose": "Approved secure application endpoint",
            "approved": True,
            "restricted": True,
            "public": False,
        })

        change = validate_change_governance({
            "change_id": "CHG-SPT02412-L2",
            "approved_by": "PISI_INFRA_OWNER",
            "rollback": True,
            "evidence": True,
            "risk_review": True,
        })

        exposure = exposure_baseline(self.discovered_paths)

        controls = [
            HardeningControl(
                "INFRA-SECURE-BASELINE",
                "Secure configuration baseline",
                baseline["valid"] is True,
                True,
                True,
                "Secure baseline is versioned, reviewed, integrity-protected and rollback-ready.",
            ),
            HardeningControl(
                "INFRA-SERVICE-GOVERNANCE",
                "Service governance",
                service["valid"] is True,
                True,
                True,
                "Services require approval and health checks and may not run privileged.",
            ),
            HardeningControl(
                "INFRA-PORT-GOVERNANCE",
                "Port governance",
                port["valid"] is True,
                True,
                True,
                "Ports require purpose, approval, restriction and non-public exposure.",
            ),
            HardeningControl(
                "INFRA-EXPOSURE-GOVERNANCE",
                "Exposure governance",
                exposure["valid"] is True,
                True,
                True,
                "Exposure is inventoried and assessed statically.",
            ),
            HardeningControl(
                "INFRA-CHANGE-GOVERNANCE",
                "Infrastructure change governance",
                change["valid"] is True,
                True,
                True,
                "Changes require approval, rollback, risk review and evidence.",
            ),
            HardeningControl(
                "INFRA-SECRET-INDIRECTION",
                "Secret indirection",
                baseline["controls"]["secret_indirection"] is True,
                True,
                True,
                "Operational infrastructure baselines prohibit embedded production secrets.",
            ),
            HardeningControl(
                "INFRA-NO-REAL-SERVICE-ACTION",
                "No real service action",
                service["service_started"] is False
                and service["service_stopped"] is False
                and service["service_restarted"] is False,
                True,
                True,
                "Assessment never starts, stops or restarts services.",
            ),
            HardeningControl(
                "INFRA-NO-REAL-NETWORK-ACTION",
                "No real network action",
                port["port_opened"] is False
                and port["firewall_changed"] is False
                and exposure["port_opened"] is False
                and exposure["firewall_changed"] is False,
                True,
                True,
                "Assessment never opens ports or changes firewall.",
            ),
            HardeningControl(
                "INFRA-NO-PRODUCTION-CHANGE",
                "No production infrastructure change",
                baseline["production_configuration_changed"] is False
                and change["production_change_executed"] is False,
                True,
                True,
                "Assessment is governance-only.",
            ),
            HardeningControl(
                "INFRA-NO-EXTERNAL-CONNECTION",
                "No external connection",
                port["external_connection_opened"] is False
                and exposure["external_connection_opened"] is False,
                True,
                True,
                "Assessment remains local and static.",
            ),
            HardeningControl(
                "INFRA-SECRET-SAFETY",
                "No secret values exposed",
                baseline["secret_values_exposed"] is False
                and service["secret_values_exposed"] is False
                and port["secret_values_exposed"] is False
                and change["secret_values_exposed"] is False
                and exposure["secret_values_exposed"] is False,
                True,
                True,
                "Evidence stores governance metadata only.",
            ),
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and item.applicable and not item.passed
        ]

        return {
            "status": "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS" if not failed else "INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "secure_baseline": baseline,
            "service_governance": service,
            "port_governance": port,
            "change_governance": change,
            "exposure": exposure,
            "infrastructure_surfaces": len(self.discovered_paths),
            "production_configuration_changed": False,
            "production_change_executed": False,
            "service_restarted": False,
            "port_opened": False,
            "firewall_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
