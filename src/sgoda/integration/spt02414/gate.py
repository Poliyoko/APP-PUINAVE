class SecurityRiskGovernanceGate:
    BLOCKING = frozenset({
        "RISK-INVENTORY",
        "RISK-THREAT-GOVERNANCE",
        "RISK-VULNERABILITY-GOVERNANCE",
        "RISK-IMPACT-GOVERNANCE",
        "RISK-SCORING",
        "RISK-TREATMENT-GOVERNANCE",
        "RISK-RESIDUAL-REVIEW",
        "RISK-NO-ACTIVE-PROBE",
        "RISK-NO-VULN-SCAN",
        "RISK-NO-PRODUCTION-CHANGE",
        "RISK-NO-EXTERNAL-CONNECTION",
        "RISK-SECRET-SAFETY",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {item["control_id"] if isinstance(item, dict) else item.control_id: item for item in controls}

        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:" + item for item in missing]

        failed = []
        for control_id in sorted(cls.BLOCKING):
            item = by_id[control_id]
            passed = item["passed"] if isinstance(item, dict) else item.passed
            blocking = item["blocking"] if isinstance(item, dict) else item.blocking
            applicable = item["applicable"] if isinstance(item, dict) else item.applicable
            if blocking and applicable and not passed:
                failed.append(control_id)

        return not failed, failed
