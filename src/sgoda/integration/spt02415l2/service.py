from .audit import AdvancedApiHardeningAuditor
from .gate import AdvancedApiHardeningGate
class AdvancedApiHardeningService:
    def assess(self,surface_count):
        result=AdvancedApiHardeningAuditor(surface_count).assess()
        passed,failed=AdvancedApiHardeningGate.evaluate(result["controls"])
        result["status"]="ADVANCED_API_HARDENING_GATE_PASS" if passed else "ADVANCED_API_HARDENING_GATE_HOLD"
        result["failed_blocking_controls"]=failed
        return result
