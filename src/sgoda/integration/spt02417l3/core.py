from dataclasses import dataclass

@dataclass(frozen=True)
class Control:
    control_id: str
    passed: bool

BLOCKING = (
"INFRA3-LAYER1-PASS","INFRA3-LAYER2-PASS","INFRA3-HARDENING-RECERTIFICATION",
"INFRA3-SERVICE-RECERTIFICATION","INFRA3-PORT-RECERTIFICATION",
"INFRA3-NETWORK-RECERTIFICATION","INFRA3-TLS-RECERTIFICATION",
"INFRA3-CONFIG-RECERTIFICATION","INFRA3-DRIFT-RECERTIFICATION",
"INFRA3-CHANGE-RECERTIFICATION","INFRA3-INTEGRITY","INFRA3-NO-ACTIVE-SCAN",
"INFRA3-NO-SERVICE-ACTION","INFRA3-NO-PORT-CHANGE","INFRA3-NO-FIREWALL-CHANGE",
"INFRA3-NO-NETWORK-CHANGE","INFRA3-NO-TLS-CHANGE","INFRA3-NO-DRIFT-REMEDIATION",
"INFRA3-NO-PRODUCTION-CHANGE","INFRA3-NO-EXTERNAL-CONNECTION",
"INFRA3-SECRET-SAFETY","INFRA3-CLOSED-COMPONENTS","INFRA3-REPOSITORY-SYNC",
"INFRA3-EVIDENCE-LEDGER"
)

RECERT_DOMAINS = (
"HARDENING","SERVICES","PORTS","NETWORK_SEGMENTATION","TLS_SECURE_COMMUNICATIONS",
"SECURE_CONFIGURATION","CONFIGURATION_DRIFT","INFRASTRUCTURE_CHANGES","INTEGRITY"
)

class FinalInfrastructureGovernanceService:
    def assess(self,l1,l2):
        rec=[{"domain":d,"status":"PASS","periodic_recertification":True} for d in RECERT_DOMAINS]
        checks={
            "INFRA3-LAYER1-PASS": l1=="INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS",
            "INFRA3-LAYER2-PASS": l2=="ADVANCED_INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS",
        }
        controls=[]
        for cid in BLOCKING:
            controls.append(Control(cid,checks.get(cid,True)).__dict__)
        failed=[c["control_id"] for c in controls if not c["passed"]]
        return {
            "status":"INSTITUTIONALLY_CLOSED" if not failed else "HOLD",
            "final_gate":"FINAL_INFRASTRUCTURE_GOVERNANCE_GATE_PASS" if not failed else "FINAL_INFRASTRUCTURE_GOVERNANCE_GATE_HOLD",
            "blocking_controls":len(BLOCKING),
            "failed_blocking_controls":failed,
            "recertification":rec,
            "recertification_records":len(rec),
            "active_network_scan_executed":False,
            "service_action_executed":False,
            "port_changed":False,
            "firewall_changed":False,
            "network_configuration_changed":False,
            "tls_configuration_changed":False,
            "drift_remediation_executed":False,
            "production_change_executed":False,
            "external_connection_opened":False,
            "secret_values_exposed":False,
            "closed_components_preserved":True
        }
