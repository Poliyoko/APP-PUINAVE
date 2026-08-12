from .audit import AdvancedDatabaseGovernanceAuditor
from .gate import AdvancedDatabaseGovernanceGate

class AdvancedDatabaseGovernanceService:
    def assess(self,surface_count):
        result=AdvancedDatabaseGovernanceAuditor(surface_count).assess()
        passed,failed=AdvancedDatabaseGovernanceGate.evaluate(result["controls"])
        result["status"]="ADVANCED_DATABASE_GOVERNANCE_GATE_PASS" if passed else "ADVANCED_DATABASE_GOVERNANCE_GATE_HOLD"
        result["failed_blocking_controls"]=failed
        return result
