class CryptographicClosureGate:
    BLOCKING = frozenset({
        "CRYPTOG-CAPA1-PASS",
        "CRYPTOG-CAPA2-PASS",
        "CRYPTOG-POLICY",
        "CRYPTOG-KEY-GOVERNANCE",
        "CRYPTOG-RECERTIFICATION",
        "CRYPTOG-LIFECYCLE",
        "CRYPTOG-ROTATION-VERSIONING",
        "CRYPTOG-CUSTODY",
        "CRYPTOG-EVIDENCE-INTEGRITY",
        "CRYPTOG-NO-SIDE-EFFECTS",
        "CRYPTOG-SECRET-SAFETY",
        "CRYPTOG-CLOSED-COMPONENT-PRESERVATION",
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
