class EventCorrelationGate:
    BLOCKING = frozenset({
        "IR-CORRELATION",
        "IR-INCIDENT",
        "IR-ALERTING",
        "IR-RESPONSE",
        "IR-INTEGRITY",
        "IR-SECRET-SAFETY",
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
            applicable = c["applicable"] if isinstance(c, dict) else c.applicable

            if blocking and applicable and not passed:
                failed.append(cid)

        return not failed, failed
