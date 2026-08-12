class DatabaseSecurityGate:
    BLOCKING=frozenset({
        "DB-SURFACE-INVENTORY","DB-ACCESS-GOVERNANCE","DB-QUERY-SECURITY","DB-DATA-INTEGRITY",
        "DB-AUDITING","DB-POSTGRESQL-HARDENING","DB-PERSISTENCE-GOVERNANCE","DB-NO-ROLE-CHANGE",
        "DB-NO-QUERY-EXECUTION","DB-NO-DATA-CHANGE","DB-NO-AUDIT-CONFIG-CHANGE",
        "DB-NO-POSTGRES-CONFIG-CHANGE","DB-NO-EXTERNAL-CONNECTION","DB-SECRET-SAFETY"
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
