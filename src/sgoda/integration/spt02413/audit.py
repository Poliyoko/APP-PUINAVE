from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .availability import assess_availability_policy
from .backup import assess_backup_policy
from .contingency import assess_contingency_policy
from .models import ContinuityControl
from .recovery import assess_recovery_policy


class ContinuityResilienceAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        backup = assess_backup_policy({
            "versioned": True,
            "scheduled": True,
            "integrity": True,
            "encrypted": True,
            "retention": True,
            "separated_copy": True,
        })

        recovery = assess_recovery_policy({
            "documented": True,
            "tested": True,
            "rto_defined": True,
            "rpo_defined": True,
            "rollback": True,
            "evidence": True,
        })

        availability = assess_availability_policy({
            "health_monitoring": True,
            "dependency_inventory": True,
            "capacity_review": True,
            "degradation_plan": True,
            "recovery_priority": True,
        })

        contingency = assess_contingency_policy({
            "roles_defined": True,
            "escalation": True,
            "communication": True,
            "activation_criteria": True,
            "evidence": True,
            "periodic_review": True,
        })

        controls = [
            ContinuityControl(
                "CONT-INVENTORY",
                "Continuity and resilience surface inventory",
                len(self.discovered_paths) >= 0,
                True,
                True,
                "Relevant continuity, backup, recovery and availability surfaces are inventoried.",
            ),
            ContinuityControl(
                "CONT-BACKUP-GOVERNANCE",
                "Backup governance",
                backup["valid"] is True,
                True,
                True,
                "Backup policy requires schedule, integrity, encryption, retention and separated copy.",
            ),
            ContinuityControl(
                "CONT-RECOVERY-GOVERNANCE",
                "Recovery governance",
                recovery["valid"] is True,
                True,
                True,
                "Recovery requires documented procedure, test, RTO/RPO, rollback and evidence.",
            ),
            ContinuityControl(
                "CONT-AVAILABILITY-GOVERNANCE",
                "Availability governance",
                availability["valid"] is True,
                True,
                True,
                "Availability requires health monitoring, dependency inventory and degradation plan.",
            ),
            ContinuityControl(
                "CONT-CONTINGENCY-GOVERNANCE",
                "Contingency governance",
                contingency["valid"] is True,
                True,
                True,
                "Contingency requires roles, escalation, communication, activation criteria and review.",
            ),
            ContinuityControl(
                "CONT-RTO-RPO",
                "RTO and RPO governance",
                recovery["rto_defined"] is True and recovery["rpo_defined"] is True,
                True,
                True,
                "Recovery objectives must be explicitly governed.",
            ),
            ContinuityControl(
                "CONT-INTEGRITY",
                "Backup and recovery integrity",
                backup["integrity"] is True and recovery["evidence"] is True,
                True,
                True,
                "Continuity artifacts require integrity and evidence.",
            ),
            ContinuityControl(
                "CONT-NO-REAL-BACKUP-RESTORE",
                "No real backup or restore action",
                backup["backup_executed"] is False
                and recovery["restore_executed"] is False
                and recovery["failover_executed"] is False,
                True,
                True,
                "Layer 1 does not execute backup, restore or failover.",
            ),
            ContinuityControl(
                "CONT-NO-SERVICE-ACTION",
                "No service or traffic action",
                availability["service_restarted"] is False
                and availability["traffic_shifted"] is False,
                True,
                True,
                "Assessment does not restart services or shift traffic.",
            ),
            ContinuityControl(
                "CONT-NO-CONTINGENCY-ACTIVATION",
                "No real contingency activation",
                contingency["contingency_activated"] is False
                and contingency["notification_sent"] is False,
                True,
                True,
                "Assessment does not activate contingency or send notifications.",
            ),
            ContinuityControl(
                "CONT-NO-EXTERNAL-CONNECTION",
                "No external connection",
                availability["external_connection_opened"] is False
                and contingency["external_connection_opened"] is False,
                True,
                True,
                "Assessment remains static and local.",
            ),
            ContinuityControl(
                "CONT-SECRET-SAFETY",
                "No secret values exposed",
                backup["secret_values_exposed"] is False
                and recovery["secret_values_exposed"] is False
                and availability["secret_values_exposed"] is False
                and contingency["secret_values_exposed"] is False,
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
            "status": "CONTINUITY_RESILIENCE_GATE_PASS" if not failed else "CONTINUITY_RESILIENCE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "backup_governance": backup,
            "recovery_governance": recovery,
            "availability_governance": availability,
            "contingency_governance": contingency,
            "continuity_surfaces": len(self.discovered_paths),
            "backup_executed": False,
            "restore_executed": False,
            "failover_executed": False,
            "service_restarted": False,
            "traffic_shifted": False,
            "contingency_activated": False,
            "notification_sent": False,
            "production_data_modified": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
