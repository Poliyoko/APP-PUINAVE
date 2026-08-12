class ApplicationApiSecurityGate:
    BLOCKING=frozenset({
        "APP-SURFACE-INVENTORY","APP-INPUT-VALIDATION","APP-SESSION-SECURITY","APP-API-AUTHZ",
        "APP-API-ABUSE","APP-CORS-HEADERS","APP-ERROR-SANITIZATION","APP-OWASP-COVERAGE",
        "APP-SOFTWARE-GOVERNANCE","APP-NO-ACTIVE-ATTACK","APP-NO-PRODUCTION-CHANGE",
        "APP-NO-EXTERNAL-CONNECTION","APP-SECRET-SAFETY",
    })
    @classmethod
    def evaluate(cls,controls):
        by_id={c["control_id"]:c for c in controls}
        missing=sorted(cls.BLOCKING-set(by_id))
        failed=["MISSING:"+x for x in missing]
        for cid in sorted(cls.BLOCKING):
            if cid in by_id and not by_id[cid]["passed"]:
                failed.append(cid)
        return not failed,failed
