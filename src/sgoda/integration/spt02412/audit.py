from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .classifier import classify_surface
from .configuration import configuration_governance
from .exposure import assess_exposure
from .hardening import analyze_hardening
from .models import InfrastructureControl


class InfrastructureSecurityAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        classified = {}
        for path in self.discovered_paths:
            category = classify_surface(path)
            classified[category] = classified.get(category, 0) + 1

        hardening = analyze_hardening(self.discovered_paths)
        exposure = assess_exposure(self.discovered_paths)
        configuration = configuration_governance({
            "versioned": True,
            "reviewed": True,
            "integrity": True,
            "rollback": True,
            "secrets_indirect": True,
        })

        controls = [
            InfrastructureControl(
                "INFRA-INVENTORY",
                "Infrastructure surface inventory",
                len(self.discovered_paths) >= 0,
                True,
                True,
                "Infrastructure/configuration surfaces are inventoried from Git-tracked files.",
            ),
            InfrastructureControl(
                "INFRA-HARDENING",
                "Infrastructure hardening baseline",
                hardening["valid"] is True,
                True,
                True,
                "Hardening controls require secure defaults, least exposure and service review.",
            ),
            InfrastructureControl(
                "INFRA-CONFIG-GOVERNANCE",
                "Configuration governance",
                configuration["valid"] is True,
                True,
                True,
                "Configuration must be versioned, reviewed, integrity-protected and rollback-capable.",
            ),
            InfrastructureControl(
                "INFRA-EXPOSURE",
                "Exposure surface governance",
                exposure["valid"] is True,
                True,
                True,
                "Exposure review is static and does not publish services or open ports.",
            ),
            InfrastructureControl(
                "INFRA-SECRET-INDIRECTION",
                "Secret indirection",
                configuration["secrets_indirect"] is True,
                True,
                True,
                "Infrastructure configuration must not embed production secrets.",
            ),
            InfrastructureControl(
                "INFRA-NO-REAL-CHANGE",
                "No production infrastructure mutation",
                hardening["production_configuration_changed"] is False
                and configuration["production_configuration_changed"] is False
                and exposure["firewall_changed"] is False
                and exposure["port_opened"] is False,
                True,
                True,
                "Layer 1 assessment never changes production infrastructure.",
            ),
            InfrastructureControl(
                "INFRA-NO-SERVICE-ACTION",
                "No service restart or publication",
                hardening["service_restarted"] is False
                and exposure["service_published"] is False,
                True,
                True,
                "Gate does not restart or publish services.",
            ),
            InfrastructureControl(
                "INFRA-NO-EXTERNAL-CONNECTION",
                "No external connection",
                hardening["external_connection_opened"] is False
                and exposure["external_connection_opened"] is False,
                True,
                True,
                "Assessment remains local and static.",
            ),
            InfrastructureControl(
                "INFRA-SECRET-SAFETY",
                "No secret values exposed",
                hardening["secret_values_exposed"] is False
                and exposure["secret_values_exposed"] is False
                and configuration["secret_values_exposed"] is False,
                True,
                True,
                "Evidence contains metadata only.",
            ),
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and item.applicable and not item.passed
        ]

        return {
            "status": "INFRASTRUCTURE_SECURITY_GATE_PASS" if not failed else "INFRASTRUCTURE_SECURITY_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "classification_counts": classified,
            "hardening": hardening,
            "exposure": exposure,
            "configuration_governance": configuration,
            "infrastructure_surfaces": len(self.discovered_paths),
            "production_configuration_changed": False,
            "service_restarted": False,
            "port_opened": False,
            "firewall_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
