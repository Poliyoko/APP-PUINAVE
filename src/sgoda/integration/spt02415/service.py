from .audit import ApplicationApiSecurityAuditor
from .gate import ApplicationApiSecurityGate

class ApplicationApiSecurityService:
    def assess(self,surface_count):
        result=ApplicationApiSecurityAuditor(surface_count).assess()
        passed,failed=ApplicationApiSecurityGate.evaluate(result["controls"])
        result["status"]="APPLICATION_API_SECURITY_GATE_PASS" if passed else "APPLICATION_API_SECURITY_GATE_HOLD"
        result["failed_blocking_controls"]=failed
        return result
