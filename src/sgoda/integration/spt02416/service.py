from .audit import DatabaseSecurityAuditor
from .gate import DatabaseSecurityGate

class DatabaseSecurityService:
    def assess(self,surface_count):
        result=DatabaseSecurityAuditor(surface_count).assess()
        passed,failed=DatabaseSecurityGate.evaluate(result["controls"])
        result["status"]="DATABASE_SECURITY_GOVERNANCE_GATE_PASS" if passed else "DATABASE_SECURITY_GOVERNANCE_GATE_HOLD"
        result["failed_blocking_controls"]=failed
        return result
