class IncidentGovernanceClosureGate:
    BLOCKING = frozenset({
        "IRG-CAPA1-PASS",
        "IRG-CAPA2-PASS",
        "IRG-EVIDENCE-INTEGRITY",
        "IRG-ESCALATION",
        "IRG-NO-SIDE-EFFECTS",
        "IRG-SECRET-SAFETY",
        "IRG-CLOSED-COMPONENT-PRESERVATION",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {
            c["control_id"] if isinstance(c, dict) else c.control_id: c
            for c in controls
        }

        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:" + x for x in missing]

        failed = []

        for cid in sorted(cls.BLOCKING):
            c = by_id[cid]
            passed = c["passed"] if isinstance(c, dict) else c.passed
            blocking = c["blocking"] if isinstance(c, dict) else c.blocking

            if blocking and not passed:
                failed.append(cid)

        return not failed, failed
