class SupplyChainClosureGate:
    BLOCKING = frozenset({
        "SC3-CAPA2-PASS",
        "SC3-SBOM-INTEGRITY",
        "SC3-EVIDENCE-INTEGRITY",
        "SC3-SECRET-SAFETY",
        "SC3-PUBLICATION-SAFETY",
        "SC3-CLOSED-COMPONENT-PRESERVATION",
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
