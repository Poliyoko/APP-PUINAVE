class InfrastructureSecurityGate:
    BLOCKING=frozenset({"INFRA-SURFACE-INVENTORY","INFRA-ASSET-GOVERNANCE","INFRA-OS-SECURITY","INFRA-SERVICE-SECURITY","INFRA-PORT-SECURITY","INFRA-NETWORK-SECURITY","INFRA-SECURE-COMMS","INFRA-HARDENING","INFRA-CONFIG-GOVERNANCE","INFRA-INTEGRITY","INFRA-NO-ACTIVE-SCAN","INFRA-NO-SERVICE-CHANGE","INFRA-NO-PORT-CHANGE","INFRA-NO-FIREWALL-CHANGE","INFRA-NO-NETWORK-CHANGE","INFRA-NO-TLS-CHANGE","INFRA-NO-OS-CHANGE","INFRA-NO-PRODUCTION-CHANGE","INFRA-NO-EXTERNAL-CONNECTION","INFRA-SECRET-SAFETY"})
    @classmethod
    def evaluate(cls,controls):
        by_id={c["control_id"]:c for c in controls}
        failed=["MISSING:"+x for x in sorted(cls.BLOCKING-set(by_id))]
        failed += [cid for cid in sorted(cls.BLOCKING) if cid in by_id and not by_id[cid]["passed"]]
        return not failed,failed
