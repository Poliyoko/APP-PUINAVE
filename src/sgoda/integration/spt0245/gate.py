from __future__ import annotations

from .models import (
    AutomationSecurityControl,
    AutomationSecurityReport,
    WorkflowSurface,
)


class AutomationSecurityGate:
    REQUIRED_BLOCKING_CONTROLS = (
        "AUT-PRODUCTION-SCOPE",
        "AUT-SECRET-INDIRECTION",
        "AUT-WEBHOOK-AUTH",
        "AUT-COMMAND-EXECUTION",
        "AUT-INTEGRITY",
        "AUT-AUDIT",
        "AUT-TRUST-DEFAULT",
        "AUT-RUNTIME",
    )

    @classmethod
    def certify(
        cls,
        controls: list[AutomationSecurityControl],
        surfaces: list[WorkflowSurface],
    ) -> AutomationSecurityReport:
        by_id = {item.control_id: item for item in controls}
        completed = list(controls)

        for control_id in cls.REQUIRED_BLOCKING_CONTROLS:
            if control_id not in by_id:
                completed.append(
                    AutomationSecurityControl(
                        control_id=control_id,
                        name="Missing required automation security control",
                        passed=False,
                        blocking=True,
                        detail="Required automation security control is missing.",
                    )
                )

        return AutomationSecurityReport(
            controls=completed,
            surfaces=list(surfaces),
        )
