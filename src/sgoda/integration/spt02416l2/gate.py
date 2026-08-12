class AdvancedDatabaseGovernanceGate:
    BLOCKING=frozenset({
        "DB2-LAYER1-GATE","DB2-SURFACE-INVENTORY","DB2-ROLES-PRIVILEGES","DB2-SCHEMA-SECURITY",
        "DB2-MIGRATION-GOVERNANCE","DB2-ADVANCED-AUDIT","DB2-TRANSACTION-INTEGRITY",
        "DB2-PERSISTENCE-PROTECTION","DB2-POSTGRESQL-GOVERNANCE","DB2-NO-ROLE-CHANGE",
        "DB2-NO-SCHEMA-CHANGE","DB2-NO-MIGRATION-EXECUTION","DB2-NO-AUDIT-CONFIG-CHANGE",
        "DB2-NO-TRANSACTION-EXECUTION","DB2-NO-PERSISTENCE-CHANGE","DB2-NO-POSTGRES-CONFIG-CHANGE",
        "DB2-NO-EXTERNAL-CONNECTION","DB2-SECRET-SAFETY"
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
