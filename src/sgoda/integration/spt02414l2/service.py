from .audit import RiskRegisterAuditor
from .gate import RiskRegisterGovernanceGate

class RiskRegisterGovernanceService:
    def assess(self,layer1_status):
        audit=RiskRegisterAuditor().assess()
        gate=RiskRegisterGovernanceGate.evaluate(layer1_status,audit)
        return {"status":"RISK_REGISTER_GOVERNANCE_GATE_PASS" if gate["passed"] else "RISK_REGISTER_GOVERNANCE_GATE_HOLD","gate":gate,**audit}
