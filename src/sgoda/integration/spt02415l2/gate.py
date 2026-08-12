class AdvancedApiHardeningGate:
    BLOCKING=frozenset({"API2-LAYER1-GATE","API2-SURFACE-INVENTORY","API2-SESSION-HARDENING","API2-RATE-LIMIT","API2-CORS-CSRF","API2-ENDPOINT-SECURITY","API2-ADVANCED-VALIDATION","API2-EXPOSURE-GOVERNANCE","API2-NO-ACTIVE-ATTACK","API2-NO-SESSION-CHANGE","API2-NO-RATELIMIT-CHANGE","API2-NO-ENDPOINT-CHANGE","API2-NO-EXPOSURE-CHANGE","API2-NO-EXTERNAL-CONNECTION","API2-SECRET-SAFETY"})
    @classmethod
    def evaluate(cls,controls):
        by_id={c["control_id"]:c for c in controls}
        missing=sorted(cls.BLOCKING-set(by_id))
        failed=["MISSING:"+x for x in missing]
        for cid in sorted(cls.BLOCKING):
            if cid in by_id and not by_id[cid]["passed"]: failed.append(cid)
        return not failed,failed
