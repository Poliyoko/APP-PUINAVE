from .models import RecoveryControl
from .recovery_strategy import assess_recovery_strategy
from .restore_testing import assess_restore_test
from .objectives import assess_rto_rpo
from .redundancy import assess_redundancy
from .failover import assess_failover
from .gate import ContinuityRecoveryGovernanceGate

class ContinuityRecoveryGovernanceService:
    def assess(self, policy):
        strategy = assess_recovery_strategy(policy["recovery_strategy"])
        restore = assess_restore_test(policy["restore_testing"])
        objectives = assess_rto_rpo(policy["rto_rpo"])
        redundancy = assess_redundancy(policy["redundancy"])
        failover = assess_failover(policy["failover"])
        pairs = [
            ("CRG-01", "Capa 1 continuity gate", policy.get("layer1_gate") == "CONTINUITY_RESILIENCE_GATE_PASS"),
            ("CRG-02", "Recovery strategy", strategy["valid"]),
            ("CRG-03", "Restore testing governance", restore["valid"]),
            ("CRG-04", "Advanced RTO/RPO", objectives["valid"]),
            ("CRG-05", "Redundancy governance", redundancy["valid"]),
            ("CRG-06", "Controlled failover", failover["valid"]),
            ("CRG-07", "Approval before failover", failover["approval_required"]),
            ("CRG-08", "Rollback before failover", failover["rollback_required"]),
            ("CRG-09", "Integrity before restore", restore["integrity_verified"]),
            ("CRG-10", "Failure-domain separation", redundancy["failure_domain_separation"]),
            ("CRG-11", "No automatic destructive action", not bool(policy.get("automatic_destructive_action"))),
            ("CRG-12", "Secret indirection", bool(policy.get("secret_indirection"))),
        ]
        controls = [RecoveryControl(i, n, bool(p), True, n) for i,n,p in pairs]
        gate = ContinuityRecoveryGovernanceGate().evaluate(controls)
        return {"gate": gate, "controls": controls, "strategy": strategy, "restore": restore, "objectives": objectives, "redundancy": redundancy, "failover": failover}
