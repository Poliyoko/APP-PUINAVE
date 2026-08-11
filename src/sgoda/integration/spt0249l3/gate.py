class IdentityPrivilegeClosureGate:
    BLOCKING = frozenset({
        "IAMG-CAPA1-PASS",
        "IAMG-CAPA2-PASS",
        "IAMG-EVIDENCE-INTEGRITY",
        "IAMG-RECERTIFICATION",
        "IAMG-SEPARATION-DUTIES",
        "IAMG-LIFECYCLE",
        "IAMG-PAM",
        "IAMG-NO-SIDE-EFFECTS",
        "IAMG-SECRET-SAFETY",
        "IAMG-CLOSED-COMPONENT-PRESERVATION",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {
            item["control_id"] if isinstance(item, dict) else item.control_id: item
            for item in controls
        }

        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:" + item for item in missing]

        failed = []
        for control_id in sorted(cls.BLOCKING):
            item = by_id[control_id]
            passed = item["passed"] if isinstance(item, dict) else item.passed
            blocking = item["blocking"] if isinstance(item, dict) else item.blocking
            if blocking and not passed:
                failed.append(control_id)

        return not failed, failed
