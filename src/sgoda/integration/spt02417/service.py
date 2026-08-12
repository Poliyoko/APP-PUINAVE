from .audit import InfrastructureSecurityAuditor
from .gate import InfrastructureSecurityGate
class InfrastructureSecurityService:
    def assess(self,surface_count):
        r=InfrastructureSecurityAuditor(surface_count).assess()
        passed,failed=InfrastructureSecurityGate.evaluate(r["controls"])
        r["status"]="INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS" if passed else "INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_HOLD"
        r["failed_blocking_controls"]=failed
        return r
