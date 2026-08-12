class RiskRegisterGovernanceGate:
    BLOCKING=("LAYER1_GATE","MASTER_REGISTER","PRIORITIZATION","TREATMENT_PLANS","RESIDUAL_RISK","EXCEPTION_GOVERNANCE","ACCEPTANCE_GOVERNANCE","TRACKING_GOVERNANCE","NO_AUTO_ACCEPTANCE","NO_TREATMENT_EXECUTION","NO_PRODUCTION_CHANGE","SECRET_SAFETY")

    @classmethod
    def evaluate(cls,layer1_status,audit):
        controls={
            "LAYER1_GATE":layer1_status=="SECURITY_RISK_GOVERNANCE_GATE_PASS",
            "MASTER_REGISTER":len(audit["records"])>0,
            "PRIORITIZATION":audit["records"][0]["priority"] in {"CRITICAL","HIGH"},
            "TREATMENT_PLANS":all(x["valid"] for x in audit["treatments"]),
            "RESIDUAL_RISK":all(x["valid"] for x in audit["residuals"]),
            "EXCEPTION_GOVERNANCE":all(x["valid"] for x in audit["exceptions"]),
            "ACCEPTANCE_GOVERNANCE":all(x["valid"] for x in audit["acceptances"]),
            "TRACKING_GOVERNANCE":all(bool(x["status"]) for x in audit["records"]),
            "NO_AUTO_ACCEPTANCE":all(not x["accepted_automatically"] for x in audit["acceptances"]),
            "NO_TREATMENT_EXECUTION":audit["treatment_executed"] is False,
            "NO_PRODUCTION_CHANGE":audit["production_changed"] is False,
            "SECRET_SAFETY":audit["secret_values_exposed"] is False,
        }
        failed=[k for k in cls.BLOCKING if not controls[k]]
        return {"passed":not failed,"failed":failed,"controls":controls}
